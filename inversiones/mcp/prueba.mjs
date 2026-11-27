#!/usr/bin/env node
/**
 * Pruebas del servidor de inversiones. Sin red: las cuentas de Zoetis y Adobe
 * son recortes reales de la SEC guardados en fixtures/, y el resto son casos
 * construidos para cada trampa que ya se ha encontrado.
 *
 *   node inversiones/mcp/prueba.mjs
 */

import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { copyFileSync, mkdtempSync, readFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

import { aEUR, anotarFoto, proponerAportacion, registrarOperacion, valorarCartera } from './cartera.mjs'
import { analizar, crecimientoImplicito, filaResumen, SUPUESTOS_POR_DEFECTO, valorPresente } from './valoracion.mjs'
import { ajustarSplits, extraerDatosSEC, ttm } from './xbrl.mjs'

const AQUI = dirname(fileURLToPath(import.meta.url))
const fixture = (nombre) => JSON.parse(readFileSync(join(AQUI, 'fixtures', nombre), 'utf8'))
const HOY = '2026-11-27'

let pasadas = 0
const fallos = []
async function prueba(nombre, fn) {
  try {
    await fn()
    pasadas++
  } catch (error) {
    fallos.push(`✗ ${nombre}\n    ${error.message.split('\n').join('\n    ')}`)
  }
}

/** Ningún NaN ni infinito en una salida: rompen el JSON y la tabla del panel. */
function sinNumerosRotos(objeto, ruta = '') {
  if (typeof objeto === 'number') assert.ok(Number.isFinite(objeto), `número roto en ${ruta}: ${objeto}`)
  else if (objeto && typeof objeto === 'object') {
    for (const [k, v] of Object.entries(objeto)) sinNumerosRotos(v, `${ruta}.${k}`)
  }
}

const M = 1e6

// ─── Extracción de la SEC ────────────────────────────────────────────────────

await prueba('Zoetis: sin resultado operativo, el EBIT sale de antes de impuestos + intereses', () => {
  const d = extraerDatosSEC(fixture('zts-companyfacts.json'), { ticker: 'ZTS' })
  assert.equal(d.fechaBalance, '2026-09-30')
  assert.equal(d.ttm.ebit, undefined)
  assert.ok(d.ttm.preImpuestos > 0)
  const a = analizar(d, { valor: 82.45, moneda: 'USD' }, { hoy: HOY })
  assert.ok(a.alertas.some((x) => x.startsWith('EBIT aproximado')))
  assert.equal(a.ttm.ebitM, Math.round((d.ttm.preImpuestos + d.ttm.intereses) / M))
})

await prueba('Zoetis: deuda = no corriente + corriente, y acciones de la portada', () => {
  const d = extraerDatosSEC(fixture('zts-companyfacts.json'), { ticker: 'ZTS' })
  assert.equal(d.balance.deuda, 8299 * M + 750 * M)
  assert.equal(d.balance.deudaCriterio, 'no corriente + corriente')
  assert.equal(d.acciones, 406316147)
})

await prueba('Zoetis: TTM = anual + acumulado − acumulado previo', () => {
  const d = extraerDatosSEC(fixture('zts-companyfacts.json'), { ticker: 'ZTS' })
  assert.equal(d.ttmDetalle.ingresos.metodo, 'anual + acumulado − acumulado previo')
  assert.equal(d.ttmDetalle.ingresos.fin, '2026-09-30')
  assert.equal(Math.round(d.ttm.ingresos / M), 9494)
})

await prueba('Adobe: LongTermDebt sin no corriente explícita suma la corriente (criterio conservador)', () => {
  const d = extraerDatosSEC(fixture('adbe-companyfacts.json'), { ticker: 'ADBE' })
  assert.equal(d.balance.deudaCriterio, 'LongTermDebt + corriente (conservador)')
  assert.equal(d.balance.deuda, 4766 * M + 1597 * M)
})

await prueba('Adobe: análisis completo sin NaN y con todas las piezas', () => {
  const d = extraerDatosSEC(fixture('adbe-companyfacts.json'), { ticker: 'ADBE' })
  const a = analizar(d, { valor: 234.79, moneda: 'USD' }, { hoy: HOY })
  sinNumerosRotos(a)
  sinNumerosRotos(filaResumen(a))
  assert.ok(a.puntuacion.total >= 0 && a.puntuacion.total <= 100)
  assert.ok(a.valorIntrinseco.pesimista < a.valorIntrinseco.base && a.valorIntrinseco.base < a.valorIntrinseco.optimista)
  assert.equal(a.valorIntrinseco.supuestos.crecimientoAnualPct.pesimista, 0, 'el pesimista es «deja de crecer»')
  assert.ok(a.calidad.piotroski.evaluables >= 7)
})

function hecho(inicio, fin, val, form = '10-Q', filed = fin) {
  return { start: inicio, end: fin, val, form, filed }
}

await prueba('ttm(): de un 10-Q de nueve meses', () => {
  const lista = [
    { inicio: '2025-01-01', fin: '2025-12-31', valor: 100, dias: 365 },
    { inicio: '2025-01-01', fin: '2025-09-30', valor: 70, dias: 273 },
    { inicio: '2026-01-01', fin: '2026-09-30', valor: 90, dias: 273 },
    { inicio: '2026-07-01', fin: '2026-09-30', valor: 31, dias: 92 },
  ]
  assert.equal(ttm(lista).valor, 120)
})

await prueba('ttm(): si lo último es un 10-K, el anual tal cual', () => {
  const lista = [{ inicio: '2025-01-01', fin: '2025-12-31', valor: 100, dias: 365 }]
  assert.deepEqual([ttm(lista).valor, ttm(lista).metodo], [100, 'anual'])
})

await prueba('Una etiqueta abandonada hace años no se usa como TTM (KLA y su EBIT de 2015)', () => {
  const cf = {
    entityName: 'Prueba',
    facts: {
      'us-gaap': {
        Assets: { units: { USD: [hecho(undefined, '2026-09-30', 1000, '10-Q')] } },
        OperatingIncomeLoss: { units: { USD: [hecho('2014-01-01', '2014-12-31', 50, '10-K')] } },
        Revenues: { units: { USD: [hecho('2025-10-01', '2026-09-30', 400, '10-K')] } },
      },
    },
  }
  delete cf.facts['us-gaap'].Assets.units.USD[0].start
  const d = extraerDatosSEC(cf)
  assert.equal(d.ttm.ebit, undefined)
  assert.equal(d.ttm.ingresos, 400)
})

await prueba('Una portada de acciones de hace años se ignora (Comcast, 2009)', () => {
  const cf = {
    entityName: 'Prueba',
    facts: {
      dei: { EntityCommonStockSharesOutstanding: { units: { shares: [{ end: '2009-12-31', val: 2e9, form: '10-K', filed: '2010-02-01' }] } } },
      'us-gaap': {
        Assets: { units: { USD: [{ end: '2026-09-30', val: 1000, form: '10-Q', filed: '2026-10-30' }] } },
        WeightedAverageNumberOfDilutedSharesOutstanding: { units: { shares: [hecho('2026-07-01', '2026-09-30', 3.7e9)] } },
      },
    },
  }
  const d = extraerDatosSEC(cf)
  assert.equal(d.acciones, 3.7e9)
  assert.match(d.accionesFuente, /media diluida/)
})

await prueba('ajustarSplits deshace un 10 por 1 y un contrasplit 1 por 5', () => {
  assert.deepEqual(ajustarSplits([157, 155, 140, 1361, 1337]), [1570, 1550, 1400, 1361, 1337])
  assert.deepEqual(ajustarSplits([500, 510, 102]), [100, 102, 102])
  assert.deepEqual(ajustarSplits([100, null, 98, 97]), [100, null, 98, 97])
})

// ─── Valoración ──────────────────────────────────────────────────────────────

await prueba('DCF inverso: recupera el crecimiento con el que se construyó el precio', () => {
  const valor = valorPresente(100, 0.07, SUPUESTOS_POR_DEFECTO)
  assert.ok(Math.abs(crecimientoImplicito(100, valor, SUPUESTOS_POR_DEFECTO) - 0.07) < 1e-6)
})

await prueba('DCF: rechaza una tasa de descuento que no supera al crecimiento terminal', () => {
  assert.throws(() => valorPresente(100, 0.05, { ...SUPUESTOS_POR_DEFECTO, tasaDescuento: 0.02 }))
})

function datosBase(extra = {}) {
  return {
    nombre: 'Prueba SA',
    ticker: 'PRB',
    moneda: 'USD',
    fechaBalance: '2026-09-30',
    ttm: { ingresos: 1000, ebit: 200, beneficioNeto: 150, fco: 220, capex: 40, sbc: 10, amortizacion: 30, preImpuestos: 190, impuestos: 40, intereses: 10 },
    balance: { activos: 2000, patrimonio: 800, caja: 100, deuda: 300, activoCorriente: 500, pasivoCorriente: 300 },
    acciones: 100,
    anual: {
      fines: ['2020-12-31', '2021-12-31', '2022-12-31', '2023-12-31', '2024-12-31', '2025-12-31'],
      ingresos: [600, 680, 750, 830, 920, 1000],
      ebit: [110, 125, 140, 160, 180, 200],
      beneficioNeto: [80, 90, 100, 115, 130, 150],
    },
    ...extra,
  }
}

await prueba('El margen de seguridad se recorta a −100 % cuando el modelo no justifica el precio', () => {
  const a = analizar(datosBase(), { valor: 10000, moneda: 'USD' }, { hoy: HOY })
  assert.equal(a.valorIntrinseco.margenSeguridadBasePct, -100)
  assert.equal(a.senal, 'exigente')
})

await prueba('Cíclica: margen que cae desde un pico con beneficio y está otra vez en máximos', () => {
  const d = datosBase({
    anual: { ...datosBase().anual, ebit: [100, 20, 150, 40, 170, 200] },
  })
  const a = analizar(d, { valor: 5, moneda: 'USD' }, { hoy: HOY })
  assert.ok(a.alertas.some((x) => x.startsWith('Negocio cíclico')))
  assert.equal(a.senal, 'cíclica en pico', 'barata sobre beneficio de pico no puede salir «infravalorada»')
})

await prueba('Una empresa que madura desde pérdidas no es cíclica (Uber)', () => {
  const d = datosBase({
    anual: { ...datosBase().anual, ebit: [-400, -330, -150, 20, 60, 200] },
  })
  const a = analizar(d, { valor: 5, moneda: 'USD' }, { hoy: HOY })
  assert.ok(!a.alertas.some((x) => x.startsWith('Negocio cíclico')), a.alertas.join(' | '))
})

await prueba('Capex muy por encima de la amortización: avisa y valora también por flujo del propietario', () => {
  const d = datosBase()
  d.ttm = { ...d.ttm, capex: 150, amortizacion: 30 }
  const a = analizar(d, { valor: 20, moneda: 'USD' }, { hoy: HOY })
  assert.ok(a.alertas.some((x) => x.startsWith('Capex 5×')))
  assert.equal(a.flujoPropietario.flujoM, 0) // 220 − 30 − 10 = 180, en millones redondea a 0
  assert.ok(a.flujoPropietario.valorBase > a.valorIntrinseco.base)
})

await prueba('Financiera: sin EV ni EV/EBIT, se valora por beneficio', () => {
  const ftk = JSON.parse(readFileSync(join(AQUI, '..', 'datos', 'fundamentales', 'FTK.DE.json'), 'utf8'))
  const a = analizar({ ...ftk, ticker: 'FTK.DE' }, { valor: 24.16, moneda: 'EUR' }, { hoy: HOY, supuestos: ftk.supuestos })
  sinNumerosRotos(a)
  assert.match(a.tipo, /^financiera/)
  assert.equal(a.multiplos.evEbit, null)
  assert.equal(a.solidez.deudaNetaEbitda, null)
  assert.equal(a.multiplos.per, 12.6)
})

await prueba('Precio en otra moneda sin conversión: lo avisa en vez de dar múltiplos falsos', () => {
  const a = analizar(datosBase(), { valor: 20, moneda: 'EUR' }, { hoy: HOY })
  assert.ok(a.alertas.some((x) => x.includes('sin conversión')))
})

// ─── Cartera ─────────────────────────────────────────────────────────────────

await prueba('aEUR: dólares con el cambio del BCE y peniques de Londres', () => {
  assert.ok(Math.abs(aEUR(110, 'USD', { USD: 1.1 }) - 100) < 1e-9)
  assert.equal(aEUR(1000, 'GBp', { GBP: 0.8 }), 12.5)
  assert.equal(aEUR(5, 'CHF', {}), null)
})

const carteraPrueba = {
  reglas: { pesoMaximo: 0.25 },
  posiciones: [
    { ticker: 'AAA', participaciones: 10, invertidoEUR: 1000 },
    { ticker: 'BBB', participaciones: 5, invertidoEUR: 300 },
    { ticker: 'CCC', simboloCotizacion: 'CCC.DE', participaciones: 2, invertidoEUR: 100 },
  ],
}
const cotPrueba = { AAA: { valor: 110, moneda: 'USD' }, BBB: { valor: 55, moneda: 'USD' }, 'CCC.DE': { valor: 50, moneda: 'EUR' } }

await prueba('valorarCartera: valores, pesos y alerta de concentración', () => {
  const v = valorarCartera(carteraPrueba, cotPrueba, { USD: 1.1 })
  assert.equal(v.totales.valorEUR, 1000 + 250 + 100)
  assert.equal(v.totales.plusvaliaEUR, 1350 - 1400)
  const pesos = v.posiciones.map((p) => p.peso)
  assert.ok(Math.abs(pesos.reduce((s, x) => s + x, 0) - 100) < 0.2)
  assert.ok(v.alertas.some((x) => x.startsWith('AAA pesa un 74.1 %')))
  assert.equal(v.concentracion.pesoMaximoPct, 74.1)
})

function analisisPrueba(ticker, puntuacion, senal, sector, margen = 30) {
  return { ticker, nombre: ticker, puntuacion: { total: puntuacion }, senal, sector, valorIntrinseco: { margenSeguridadBasePct: margen } }
}

await prueba('proponerAportacion: respeta el techo, la orden mínima, un sector por aportación y no compra lo caro', () => {
  const v = valorarCartera(carteraPrueba, cotPrueba, { USD: 1.1 })
  const analisis = {
    AAA: analisisPrueba('AAA', 90, 'infravalorada', 'Software'),
    BBB: analisisPrueba('BBB', 80, 'atractiva', 'Software'),
    CCC: analisisPrueba('CCC', 70, 'atractiva', 'Banca'),
    DDD: analisisPrueba('DDD', 95, 'exigente', 'Ropa'),
    EEE: analisisPrueba('EEE', 40, 'infravalorada', 'Ropa'),
    FFF: { error: 'sin datos' },
  }
  const p = proponerAportacion(v, analisis, 600, { reglas: { pesoMaximo: 0.25 } })
  const tickers = p.operaciones.map((o) => o.ticker)
  assert.ok(!tickers.includes('AAA'), 'AAA ya pesa más del máximo')
  assert.ok(!tickers.includes('DDD') && !tickers.includes('EEE'))
  assert.deepEqual(tickers.sort(), ['BBB', 'CCC'])
  const techo = 0.25 * (1350 + 600)
  for (const o of p.operaciones) {
    assert.ok(o.importeEUR >= 50)
    const actual = v.posiciones.find((x) => x.ticker === o.ticker)?.valorEUR ?? 0
    assert.ok(actual + o.importeEUR <= techo + 1, `${o.ticker} supera el techo`)
  }
  assert.ok(p.operaciones.reduce((s, o) => s + o.importeEUR, 0) <= 600)
  assert.ok(p.notas.some((n) => n.startsWith('AAA seguirá por encima')))
})

await prueba('proponerAportacion: sin candidatas lo dice y no inventa compras', () => {
  const v = valorarCartera(carteraPrueba, cotPrueba, { USD: 1.1 })
  const p = proponerAportacion(v, { ZZZ: analisisPrueba('ZZZ', 20, 'exigente', 'X') }, 300)
  assert.equal(p.operaciones.length, 0)
  assert.equal(p.sinAsignarEUR, 300)
})

await prueba('registrarOperacion: compra, venta a precio medio y validaciones', () => {
  let { cartera } = registrarOperacion({ posiciones: [] }, { fecha: '2026-11-01', tipo: 'compra', ticker: 'AAA', participaciones: 4, importeEUR: 400, comisionEUR: 1 })
  assert.deepEqual([cartera.posiciones[0].participaciones, cartera.posiciones[0].invertidoEUR], [4, 401])
  const venta = registrarOperacion(cartera, { fecha: '2026-11-20', tipo: 'venta', ticker: 'AAA', participaciones: 2, importeEUR: 260, comisionEUR: 1 })
  assert.equal(venta.resultadoEUR, 260 - 1 - 200.5)
  assert.equal(venta.cartera.posiciones[0].invertidoEUR, 200.5)
  assert.equal(venta.cartera.operaciones.length, 2)
  assert.throws(() => registrarOperacion(venta.cartera, { fecha: '2026-11-21', tipo: 'venta', ticker: 'AAA', participaciones: 3, importeEUR: 1 }), /solo hay/)
  assert.throws(() => registrarOperacion(venta.cartera, { fecha: '21/11/2026', tipo: 'compra', ticker: 'AAA', participaciones: 1, importeEUR: 1 }), /AAAA-MM-DD/)
  assert.throws(() => registrarOperacion(venta.cartera, { fecha: '2026-11-21', tipo: 'compra', ticker: 'AAA', participaciones: 1, importeEUR: Infinity }))
  const todo = registrarOperacion(venta.cartera, { fecha: '2026-11-22', tipo: 'venta', ticker: 'AAA', participaciones: 2, importeEUR: 250 })
  assert.equal(todo.cartera.posiciones.length, 0, 'vender todo cierra la posición')
})

await prueba('anotarFoto: una foto por día, la del mismo día se sustituye', () => {
  const v = { totales: { valorEUR: 100, invertidoEUR: 90 } }
  let c = anotarFoto({ historico: [{ fecha: '2026-11-01', valorEUR: 80, invertidoEUR: 90 }] }, '2026-11-27', v)
  c = anotarFoto(c, '2026-11-27', { totales: { valorEUR: 105, invertidoEUR: 90 } })
  assert.equal(c.historico.length, 2)
  assert.equal(c.historico[1].valorEUR, 105)
})

// ─── Protocolo ───────────────────────────────────────────────────────────────

await prueba('Protocolo: initialize, tools/list, error de herramienta y registrar_operacion por stdio', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'cartera-'))
  const ruta = join(dir, 'cartera.json')
  copyFileSync(join(AQUI, '..', 'cartera.ejemplo.json'), ruta)
  const hijo = spawn(process.execPath, [join(AQUI, 'servidor-inversiones.mjs')], {
    env: { ...process.env, CARTERA_JSON: ruta, INVERSIONES_CACHE: join(dir, 'cache') },
  })
  let salida = ''
  hijo.stdout.on('data', (t) => (salida += t))
  const mensajes = [
    { jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2025-06-18', capabilities: {} } },
    { jsonrpc: '2.0', method: 'notifications/initialized' },
    { jsonrpc: '2.0', id: 2, method: 'tools/list' },
    { jsonrpc: '2.0', id: 3, method: 'tools/call', params: { name: 'no_existe', arguments: {} } },
    {
      jsonrpc: '2.0',
      id: 4,
      method: 'tools/call',
      params: { name: 'registrar_operacion', arguments: { fecha: '2026-11-27', tipo: 'compra', ticker: 'KO', participaciones: 1, importeEUR: 62, comisionEUR: 1 } },
    },
    { jsonrpc: '2.0', id: 5, method: 'tools/call', params: { name: 'registrar_operacion', arguments: { fecha: 'ayer', tipo: 'compra', ticker: 'KO', participaciones: 1, importeEUR: 62 } } },
  ]
  hijo.stdin.end(mensajes.map((m) => JSON.stringify(m)).join('\n') + '\n')
  await new Promise((r) => hijo.on('close', r))
  const respuestas = Object.fromEntries(
    salida
      .trim()
      .split('\n')
      .map((l) => JSON.parse(l))
      .map((m) => [m.id, m])
  )
  assert.equal(Object.keys(respuestas).length, 5, 'la notificación no se responde')
  assert.equal(respuestas[1].result.serverInfo.name, 'cartera-de-valor')
  assert.deepEqual(
    respuestas[2].result.tools.map((t) => t.name),
    ['ver_cartera', 'analizar_empresa', 'cribar', 'proponer_aportacion', 'registrar_operacion', 'exportar_panel']
  )
  assert.equal(respuestas[3].error.code, -32602)
  assert.ok(!respuestas[4].result.isError, respuestas[4].result.content[0].text)
  assert.equal(respuestas[5].result.isError, true)
  const escrita = JSON.parse(readFileSync(ruta, 'utf8'))
  const ko = escrita.posiciones.find((p) => p.ticker === 'KO')
  assert.deepEqual([ko.participaciones, ko.invertidoEUR], [11, 673])
  assert.equal(escrita.operaciones.length, 1)
})

console.log(fallos.join('\n'))
console.log(`${pasadas} pruebas pasan, ${fallos.length} fallan`)
process.exit(fallos.length ? 1 : 0)
