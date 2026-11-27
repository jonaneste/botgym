#!/usr/bin/env node
/**
 * Servidor MCP de la cartera de valor.
 *
 * Da a Claude herramientas para leer tu cartera, analizar empresas con sus
 * cuentas oficiales, cribar cuáles están más infravaloradas y proponer dónde
 * poner la siguiente aportación. Sin dependencias: solo `node` 18 o posterior.
 *
 * No se conecta a ningún broker. La cartera es un JSON que escribes tú (o que
 * Claude actualiza con `registrar_operacion`); ninguna herramienta pide ni
 * guarda credenciales.
 *
 * Uso:
 *   CARTERA_JSON=/ruta/a/cartera.json node servidor-inversiones.mjs
 */

import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

import { anotarFoto, proponerAportacion, registrarOperacion, simboloCotizacion, valorarCartera } from './cartera.mjs'
import { cambiosPara, cotizacion, cuentasSEC, esFinanciera, fichaSEC } from './fuentes.mjs'
import { analizar, filaResumen, SUPUESTOS_POR_DEFECTO } from './valoracion.mjs'
import { extraerDatosSEC } from './xbrl.mjs'

const VERSION = '1.0.0'
const AQUI = dirname(fileURLToPath(import.meta.url))
const RAIZ = resolve(AQUI, '..')

// ─── Archivos ────────────────────────────────────────────────────────────────

function rutasCartera() {
  const explicita = process.env.CARTERA_JSON || process.argv[2]
  if (explicita) return [explicita]
  const icloud = join(homedir(), 'Library', 'Mobile Documents', 'com~apple~CloudDocs')
  return [join(icloud, 'Inversiones', 'cartera.json'), join(homedir(), 'Inversiones', 'cartera.json'), join(RAIZ, 'cartera.json')]
}

function localizarCartera() {
  const ruta = rutasCartera().find((r) => existsSync(r))
  if (!ruta) {
    throw new Error(
      'No encuentro cartera.json. Copia inversiones/cartera.ejemplo.json, pon tus posiciones ' +
        'y pásame la ruta con CARTERA_JSON. Busqué en: ' + rutasCartera().join(', ')
    )
  }
  return ruta
}

function leerJSON(ruta) {
  return JSON.parse(readFileSync(ruta, 'utf8'))
}

/** Escritura atómica: un corte a mitad no deja la cartera a medias. */
function escribirJSON(ruta, datos) {
  mkdirSync(dirname(ruta), { recursive: true })
  const temporal = `${ruta}.${process.pid}.tmp`
  writeFileSync(temporal, JSON.stringify(datos, null, 2) + '\n')
  renameSync(temporal, ruta)
}

function universo() {
  try {
    return leerJSON(join(RAIZ, 'universo.json')).tickers || []
  } catch {
    return []
  }
}

function fundamentalesManuales(ticker) {
  const ruta = join(RAIZ, 'datos', 'fundamentales', `${ticker}.json`)
  return existsSync(ruta) ? { ...leerJSON(ruta), ticker } : null
}

const hoyISO = () => new Date().toISOString().slice(0, 10)

// ─── Análisis ────────────────────────────────────────────────────────────────

function supuestosDe(args) {
  const s = {}
  if (args.tasaDescuentoPct !== undefined) s.tasaDescuento = args.tasaDescuentoPct / 100
  if (args.crecimientoTerminalPct !== undefined) s.crecimientoTerminal = args.crecimientoTerminalPct / 100
  if (args.crecimientoBasePct !== undefined) s.crecimientoBase = args.crecimientoBasePct / 100
  return s
}

async function analizarTicker(ticker, { supuestos = {}, simbolo } = {}) {
  const t = ticker.toUpperCase()
  let datos = fundamentalesManuales(t)
  let sector = datos?.sector ?? null
  let financiera = datos?.financiera ?? false
  if (!datos) {
    const [cuentas, ficha] = await Promise.all([cuentasSEC(t), fichaSEC(t).catch(() => null)])
    datos = extraerDatosSEC(cuentas, { ticker: t })
    if (cuentas._caducada) datos.fuente += ` — ${cuentas._caducada}`
    sector = ficha?.sector ?? null
    financiera = esFinanciera(ficha?.sic ?? null)
  }
  const precio = await cotizacion(simbolo || datos.simboloCotizacion || t)
  for (const s of precio.splits || []) {
    if (datos.acciones && datos.accionesFecha && s.fecha > datos.accionesFecha) {
      datos.acciones *= s.factor
      datos.accionesFuente += `, ajustadas por el split ${s.factor}:1 del ${s.fecha}`
    }
  }
  let conversion = 1
  if (precio.moneda && datos.moneda && precio.moneda !== datos.moneda) {
    const { cambios } = await cambiosPara([precio.moneda, datos.moneda])
    const pm = precio.moneda === 'GBp' ? cambios.GBP * 100 : cambios[precio.moneda]
    const dm = cambios[datos.moneda]
    conversion = dm / pm
  }
  // Los supuestos del archivo manual son el punto de partida; los que pase
  // Claude en la llamada mandan.
  const analisis = analizar(datos, precio, { supuestos: { ...(datos.supuestos || {}), ...supuestos }, financiera, conversion })
  analisis.sector = sector
  analisis.cotizacion = { maximo52: precio.maximo52, minimo52: precio.minimo52, semanal: precio.semanal }
  return analisis
}

/** Analiza varias empresas con un presupuesto de tiempo: los clientes MCP cortan las llamadas largas. */
async function analizarVarias(tickers, { simbolos = {}, presupuestoMs = 50000, supuestos = {} } = {}) {
  const inicio = Date.now()
  const resultados = {}
  const pendientes = []
  const cola = [...new Set(tickers.map((t) => t.toUpperCase()))]
  async function trabajador() {
    while (cola.length) {
      const t = cola.shift()
      if (Date.now() - inicio > presupuestoMs) {
        pendientes.push(t)
        continue
      }
      try {
        resultados[t] = await analizarTicker(t, { simbolo: simbolos[t], supuestos })
      } catch (error) {
        resultados[t] = { error: error.message }
      }
    }
  }
  await Promise.all([trabajador(), trabajador(), trabajador()])
  return { resultados, pendientes }
}

async function cotizacionesDeCartera(cartera) {
  const cotizaciones = {}
  const errores = []
  for (const p of cartera.posiciones || []) {
    const s = simboloCotizacion(p)
    try {
      const c = await cotizacion(s)
      cotizaciones[s] = { valor: c.valor, moneda: c.moneda, fecha: c.fecha }
    } catch (error) {
      errores.push(`${p.ticker}: ${error.message}`)
    }
  }
  const { cambios, fechas } = await cambiosPara(Object.values(cotizaciones).map((c) => c.moneda))
  return { cotizaciones, cambios, fechas, errores }
}

async function carteraValorada() {
  const ruta = localizarCartera()
  const cartera = leerJSON(ruta)
  // El sector sale de la SEC o del archivo manual si la cartera no lo dice.
  for (const p of cartera.posiciones || []) {
    if (p.sector) continue
    p.sector = fundamentalesManuales(p.ticker.toUpperCase())?.sector ?? (await fichaSEC(p.ticker).catch(() => null))?.sector ?? null
  }
  const { cotizaciones, cambios, fechas, errores } = await cotizacionesDeCartera(cartera)
  const valorada = valorarCartera(cartera, cotizaciones, cambios)
  valorada.archivo = ruta
  valorada.fechasCambio = fechas
  valorada.alertas.push(...errores)
  return { ruta, cartera, valorada }
}

// ─── Herramientas ────────────────────────────────────────────────────────────

const SUPUESTOS_ESQUEMA = {
  tasaDescuentoPct: { type: 'number', description: `Tasa de descuento anual en %. Por defecto ${SUPUESTOS_POR_DEFECTO.tasaDescuento * 100}.` },
  crecimientoTerminalPct: { type: 'number', description: `Crecimiento a perpetuidad en %. Por defecto ${SUPUESTOS_POR_DEFECTO.crecimientoTerminal * 100}.` },
  crecimientoBasePct: { type: 'number', description: 'Crecimiento anual del flujo en el escenario base, en %. Por defecto, el menor de los crecimientos de ingresos a 3 y 5 años, recortado a [-5, 12].' },
}

const HERRAMIENTAS = [
  {
    name: 'ver_cartera',
    description:
      'Tu cartera valorada en euros a precio de mercado: valor, coste, plusvalía y peso de cada posición, ' +
      'concentración (peso máximo, posiciones efectivas), exposición por moneda y alertas. Úsala al empezar ' +
      'cualquier conversación sobre la cartera.',
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
  },
  {
    name: 'analizar_empresa',
    description:
      'Análisis de inversión en valor de una empresa con sus cuentas oficiales (SEC EDGAR, últimos doce meses): ' +
      'múltiplos (PER, EV/EBIT, rentabilidad por flujo libre), calidad (ROIC, márgenes, Piotroski), solidez, ' +
      'crecimiento implícito en el precio (DCF inverso), valor intrínseco en tres escenarios, margen de seguridad, ' +
      'puntuación 0-100 y alertas de trampa de valor. Para empresas fuera de EE. UU. usa datos/fundamentales/<TICKER>.json.',
    inputSchema: {
      type: 'object',
      properties: {
        ticker: { type: 'string', description: 'Ticker de EE. UU. (NVDA, ADBE, BRK-B) o el nombre del archivo manual (FTK.DE).' },
        ...SUPUESTOS_ESQUEMA,
      },
      required: ['ticker'],
      additionalProperties: false,
    },
  },
  {
    name: 'cribar',
    description:
      'Analiza una lista de empresas y las ordena por puntuación de valor y calidad: la forma de encontrar las más ' +
      'infravaloradas. Sin `tickers`, criba la cartera, su lista de vigilancia y el universo de universo.json. ' +
      'Si se acaba el tiempo devuelve lo hecho y la lista `pendientes`: vuelve a llamarla y seguirá desde la caché.',
    inputSchema: {
      type: 'object',
      properties: {
        tickers: { type: 'array', items: { type: 'string' }, description: 'Empresas a cribar. Opcional.' },
        limite: { type: 'number', description: 'Cuántas devolver, de mejor a peor. Por defecto 20.' },
        ...SUPUESTOS_ESQUEMA,
      },
      additionalProperties: false,
    },
  },
  {
    name: 'proponer_aportacion',
    description:
      'Propone cómo repartir una aportación nueva entre las empresas de la cartera y de la lista de vigilancia ' +
      'mejor puntuadas, sin superar el peso máximo por posición y sin órdenes tan pequeñas que la comisión pese. ' +
      'Nunca propone vender.',
    inputSchema: {
      type: 'object',
      properties: {
        importeEUR: { type: 'number', description: 'Dinero nuevo a invertir, en euros.' },
        pesoMaximoPct: { type: 'number', description: 'Peso máximo por empresa en %. Por defecto el de cartera.json o 25.' },
        incluirVigilancia: { type: 'boolean', description: 'Considerar también la lista de vigilancia. Por defecto sí.' },
      },
      required: ['importeEUR'],
      additionalProperties: false,
    },
  },
  {
    name: 'registrar_operacion',
    description:
      'Apunta una compra, venta o dividendo en cartera.json y actualiza la posición (coste por precio medio). ' +
      'Escribe en el archivo: confirma los datos con la persona antes de llamarla.',
    inputSchema: {
      type: 'object',
      properties: {
        fecha: { type: 'string', description: 'AAAA-MM-DD' },
        tipo: { type: 'string', enum: ['compra', 'venta', 'dividendo'] },
        ticker: { type: 'string' },
        participaciones: { type: 'number', description: 'Obligatorio en compras y ventas. Admite fracciones.' },
        importeEUR: { type: 'number', description: 'Importe bruto de la operación en euros, sin comisión.' },
        comisionEUR: { type: 'number', description: 'Comisión pagada. Por defecto 0.' },
        nombre: { type: 'string', description: 'Nombre de la empresa, si es una posición nueva.' },
        simboloCotizacion: { type: 'string', description: 'Símbolo de Yahoo si no coincide con el ticker (FTK.DE).' },
        nota: { type: 'string' },
      },
      required: ['fecha', 'tipo', 'ticker', 'importeEUR'],
      additionalProperties: false,
    },
  },
  {
    name: 'exportar_panel',
    description:
      'Escribe los datos del panel (posiciones, valoraciones, histórico, alertas) como JSON {rows, meta} en un ' +
      'directorio, y apunta la foto del día en el histórico de cartera.json. Es el paso previo a subirlos al panel.',
    inputSchema: {
      type: 'object',
      properties: {
        directorio: { type: 'string', description: 'Dónde escribir. Por defecto inversiones/panel-datos/.' },
      },
      additionalProperties: false,
    },
  },
]

const EJECUTORES = {
  async ver_cartera() {
    const { valorada } = await carteraValorada()
    return valorada
  },

  async analizar_empresa(args) {
    if (!args.ticker) throw new Error('Falta el ticker')
    let simbolo
    try {
      const cartera = leerJSON(localizarCartera())
      const p = (cartera.posiciones || []).find((x) => x.ticker.toUpperCase() === args.ticker.toUpperCase())
      simbolo = p ? simboloCotizacion(p) : undefined
    } catch {
      // Sin cartera también se puede analizar una empresa.
    }
    return analizarTicker(args.ticker, { supuestos: supuestosDe(args), simbolo })
  },

  async cribar(args) {
    let tickers = args.tickers
    const simbolos = {}
    let enCartera = new Set()
    try {
      const cartera = leerJSON(localizarCartera())
      for (const p of cartera.posiciones || []) simbolos[p.ticker.toUpperCase()] = simboloCotizacion(p)
      enCartera = new Set((cartera.posiciones || []).map((p) => p.ticker.toUpperCase()))
      if (!tickers) tickers = [...enCartera, ...(cartera.vigilancia || []), ...universo()]
    } catch {
      if (!tickers) tickers = universo()
    }
    if (!tickers.length) throw new Error('No hay empresas que cribar: pasa `tickers` o rellena universo.json')
    const { resultados, pendientes } = await analizarVarias(tickers, { simbolos, supuestos: supuestosDe(args) })
    const filas = Object.values(resultados)
      .filter((a) => !a.error)
      .map((a) => ({ ...filaResumen(a), enCartera: enCartera.has(a.ticker), sector: a.sector }))
      .sort((a, b) => (b.puntuacion ?? -1) - (a.puntuacion ?? -1))
    const errores = Object.entries(resultados)
      .filter(([, a]) => a.error)
      .map(([t, a]) => ({ ticker: t, error: a.error }))
    return {
      fecha: hoyISO(),
      analizadas: filas.length,
      ranking: filas.slice(0, args.limite ?? 20),
      errores,
      pendientes,
      aviso: pendientes.length ? 'Se acabó el tiempo de esta llamada. Vuelve a llamar a cribar: lo ya descargado está en caché.' : undefined,
    }
  },

  async proponer_aportacion(args) {
    const { cartera, valorada } = await carteraValorada()
    const tickers = [...(cartera.posiciones || []).map((p) => p.ticker)]
    if (args.incluirVigilancia !== false) tickers.push(...(cartera.vigilancia || []))
    const simbolos = Object.fromEntries((cartera.posiciones || []).map((p) => [p.ticker.toUpperCase(), simboloCotizacion(p)]))
    const { resultados, pendientes } = await analizarVarias(tickers, { simbolos })
    const reglas = { ...(cartera.reglas || {}) }
    if (args.pesoMaximoPct !== undefined) reglas.pesoMaximo = args.pesoMaximoPct / 100
    const propuesta = proponerAportacion(valorada, resultados, args.importeEUR, { reglas })
    if (pendientes.length) propuesta.notas.push(`Sin analizar por tiempo: ${pendientes.join(', ')}. Repite la llamada.`)
    return propuesta
  },

  async registrar_operacion(args) {
    const ruta = localizarCartera()
    const { cartera, resultadoEUR } = registrarOperacion(leerJSON(ruta), args)
    cartera.actualizado = hoyISO()
    escribirJSON(ruta, cartera)
    const pos = cartera.posiciones.find((p) => p.ticker === args.ticker) || null
    return { archivo: ruta, posicion: pos, resultadoEUR, aviso: resultadoEUR !== null ? 'Resultado por precio medio; para Hacienda vale el FIFO del informe fiscal del broker.' : undefined }
  },

  async exportar_panel(args) {
    const { ruta, cartera, valorada } = await carteraValorada()
    const tickers = [...(cartera.posiciones || []).map((p) => p.ticker), ...(cartera.vigilancia || [])]
    const simbolos = Object.fromEntries((cartera.posiciones || []).map((p) => [p.ticker.toUpperCase(), simboloCotizacion(p)]))
    const { resultados, pendientes } = await analizarVarias(tickers, { simbolos })
    const fecha = hoyISO()
    const ahora = new Date().toISOString()

    const meta = (extra = []) => [
      { label: 'Generado por', value: 'inversiones/mcp/servidor-inversiones.mjs · exportar_panel' },
      { label: 'Fecha', value: ahora },
      ...extra,
    ]
    const fuentes = { label: 'Fuentes', value: 'SEC EDGAR (cuentas), Yahoo Finance (cotizaciones), BCE (tipos de cambio)' }
    const supuestos = {
      label: 'Supuestos',
      value: `Descuento ${SUPUESTOS_POR_DEFECTO.tasaDescuento * 100} %, crecimiento terminal ${SUPUESTOS_POR_DEFECTO.crecimientoTerminal * 100} %, ${SUPUESTOS_POR_DEFECTO.anios} años, crecimiento base recortado a ${SUPUESTOS_POR_DEFECTO.topeCrecimiento * 100} %`,
    }

    const posiciones = valorada.posiciones.map((p) => {
      const a = resultados[p.ticker.toUpperCase()]
      const ok = a && !a.error
      return {
        ...p,
        senal: ok ? a.senal : null,
        puntuacion: ok ? a.puntuacion.total : null,
        valorBase: ok ? a.valorIntrinseco?.base ?? null : null,
        margenSeguridadPct: ok ? a.valorIntrinseco?.margenSeguridadBasePct ?? null : null,
      }
    })
    const valoracion = Object.values(resultados)
      .filter((a) => !a.error)
      .map((a) => ({ ...filaResumen(a), enCartera: posiciones.some((p) => p.ticker === a.ticker), sector: a.sector }))
      .sort((a, b) => (b.puntuacion ?? -1) - (a.puntuacion ?? -1))

    const conFoto = anotarFoto(cartera, fecha, valorada)
    escribirJSON(ruta, conFoto)

    const alertas = [
      ...valorada.alertas.map((texto) => ({ ambito: 'cartera', ticker: null, texto })),
      ...Object.values(resultados).flatMap((a) => (a.error ? [] : a.alertas.map((texto) => ({ ambito: 'empresa', ticker: a.ticker, texto })))),
      ...Object.entries(resultados).filter(([, a]) => a.error).map(([t, a]) => ({ ambito: 'datos', ticker: t, texto: a.error })),
      ...pendientes.map((t) => ({ ambito: 'datos', ticker: t, texto: 'sin analizar por tiempo' })),
    ]
    const resumen = [
      {
        fecha,
        ...valorada.totales,
        pesoMaximoPct: valorada.concentracion.pesoMaximoPct,
        posicionesEfectivas: valorada.concentracion.posicionesEfectivas,
        limitePorPosicionPct: valorada.concentracion.limitePorPosicionPct,
      },
    ]

    const directorio = args.directorio ? resolve(args.directorio) : join(RAIZ, 'panel-datos')
    const archivos = {
      'resumen.json': { rows: resumen, meta: meta([fuentes]) },
      'posiciones.json': { rows: posiciones, meta: meta([fuentes, supuestos]) },
      'valoracion.json': { rows: valoracion, meta: meta([fuentes, supuestos]) },
      'historico.json': { rows: conFoto.historico, meta: meta([{ label: 'Origen', value: 'Una foto por día en que se exporta el panel' }]) },
      'alertas.json': { rows: alertas, meta: meta() },
    }
    for (const [nombre, contenido] of Object.entries(archivos)) escribirJSON(join(directorio, nombre), contenido)
    return { directorio, archivos: Object.keys(archivos), fotoAnotadaEn: ruta, pendientes }
  },
}

// ─── Protocolo (JSON-RPC por stdio) ─────────────────────────────────────────

function responder(id, resultado) {
  process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id, result: resultado }) + '\n')
}

function responderError(id, codigo, mensaje) {
  process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id, error: { code: codigo, message: mensaje } }) + '\n')
}

async function manejar(mensaje) {
  const { id, method, params } = mensaje
  const esNotificacion = id === undefined || id === null
  if (esNotificacion) return

  switch (method) {
    case 'initialize':
      responder(id, {
        protocolVersion: params?.protocolVersion || '2024-11-05',
        capabilities: { tools: {} },
        serverInfo: { name: 'cartera-de-valor', version: VERSION },
      })
      return
    case 'ping':
      responder(id, {})
      return
    case 'tools/list':
      responder(id, { tools: HERRAMIENTAS })
      return
    case 'tools/call': {
      const ejecutor = EJECUTORES[params?.name]
      if (!ejecutor) {
        responderError(id, -32602, `Herramienta desconocida: ${params?.name}`)
        return
      }
      try {
        const salida = await ejecutor(params?.arguments || {})
        responder(id, { content: [{ type: 'text', text: JSON.stringify(salida, null, 2) }] })
      } catch (error) {
        // isError deja que Claude vea el fallo y lo explique.
        responder(id, { content: [{ type: 'text', text: `Error: ${error.message}` }], isError: true })
      }
      return
    }
    default:
      responderError(id, -32601, `Método no soportado: ${method}`)
  }
}

export { EJECUTORES, HERRAMIENTAS, manejar }

// Importado desde las pruebas no arranca el bucle de stdio.
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  let pendiente = ''
  let enCurso = 0
  let cerrado = false
  const quizaSalir = () => {
    if (cerrado && enCurso === 0) process.exit(0)
  }
  process.stdin.setEncoding('utf8')
  process.stdin.on('data', (trozo) => {
    pendiente += trozo
    let salto
    while ((salto = pendiente.indexOf('\n')) !== -1) {
      const linea = pendiente.slice(0, salto).trim()
      pendiente = pendiente.slice(salto + 1)
      if (!linea) continue
      let mensaje
      try {
        mensaje = JSON.parse(linea)
      } catch (error) {
        process.stderr.write(`Mensaje ilegible: ${error.message}\n`)
        continue
      }
      enCurso++
      manejar(mensaje)
        .catch((error) => process.stderr.write(`Fallo inesperado: ${error.stack}\n`))
        .finally(() => {
          enCurso--
          quizaSalir()
        })
    }
  })
  // Las llamadas son asíncronas: salir al cerrar stdin cortaría las respuestas
  // que aún están en vuelo.
  process.stdin.on('end', () => {
    cerrado = true
    quizaSalir()
  })
}
