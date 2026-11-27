/**
 * La cartera: valorarla en euros, medir la concentración, proponer dónde
 * poner la próxima aportación y registrar operaciones. Funciones puras salvo
 * que se diga lo contrario.
 */

import { redondear } from './valoracion.mjs'

export const REGLAS_POR_DEFECTO = {
  // Ninguna empresa por encima de este peso. Un 25 % ya es mucha convicción
  // para una cartera de acciones sueltas.
  pesoMaximo: 0.25,
  // Por debajo de esta nota no se propone comprar, por barato que parezca.
  umbralPuntuacion: 55,
  // Con comisión fija por orden, una orden pequeña sale cara en porcentaje.
  ordenMinimaEUR: 50,
  comisionPorOrdenEUR: 1,
  // Pocas compras grandes mejor que muchas pequeñas.
  maxOperaciones: 3,
}

const eur = (x) => redondear(x, 2)

/**
 * Pasa un importe a euros. `cambios[moneda]` son unidades de esa moneda por
 * euro (lo que publica el BCE: 1 EUR = 1,0957 USD).
 */
export function aEUR(valor, moneda, cambios) {
  if (valor === null || valor === undefined) return null
  if (!moneda || moneda === 'EUR') return valor
  // La bolsa de Londres cotiza en peniques.
  if (moneda === 'GBp' || moneda === 'GBX') return aEUR(valor / 100, 'GBP', cambios)
  const porEuro = cambios?.[moneda]
  if (!porEuro) return null
  return valor / porEuro
}

export function simboloCotizacion(posicion) {
  return posicion.simboloCotizacion || posicion.ticker
}

/**
 * @param cartera      contenido de cartera.json
 * @param cotizaciones { [simbolo]: { valor, moneda, fecha } }
 * @param cambios      { [moneda]: unidades por euro }
 */
export function valorarCartera(cartera, cotizaciones, cambios) {
  const reglas = { ...REGLAS_POR_DEFECTO, ...(cartera.reglas || {}) }
  const alertas = []
  const filas = (cartera.posiciones || []).map((p) => {
    const cot = cotizaciones[simboloCotizacion(p)] || null
    const precioEUR = cot ? aEUR(cot.valor, cot.moneda, cambios) : null
    const valorEUR = precioEUR !== null && p.participaciones ? p.participaciones * precioEUR : null
    if (!cot) alertas.push(`${p.ticker}: sin cotización; no entra en los totales`)
    else if (precioEUR === null) alertas.push(`${p.ticker}: sin tipo de cambio para ${cot.moneda}`)
    if (p.participacionesEstimadas) {
      alertas.push(`${p.ticker}: participaciones estimadas a partir del valor de una captura; pon las reales`)
    }
    return {
      ticker: p.ticker,
      nombre: p.nombre || p.ticker,
      participaciones: p.participaciones ?? null,
      participacionesEstimadas: Boolean(p.participacionesEstimadas),
      moneda: cot?.moneda ?? null,
      precio: cot?.valor ?? null,
      fechaPrecio: cot?.fecha ?? null,
      precioEUR: eur(precioEUR),
      valorEUR,
      invertidoEUR: p.invertidoEUR ?? null,
      costeMedioEUR: p.invertidoEUR && p.participaciones ? eur(p.invertidoEUR / p.participaciones) : null,
      sector: p.sector || null,
    }
  })

  const conValor = filas.filter((f) => f.valorEUR !== null)
  const total = conValor.reduce((s, f) => s + f.valorEUR, 0)
  const invertido = conValor.reduce((s, f) => s + (f.invertidoEUR ?? 0), 0)

  for (const f of filas) {
    f.peso = f.valorEUR !== null && total > 0 ? f.valorEUR / total : null
    f.plusvaliaEUR = f.valorEUR !== null && f.invertidoEUR !== null ? eur(f.valorEUR - f.invertidoEUR) : null
    f.plusvaliaPct = f.plusvaliaEUR !== null && f.invertidoEUR ? redondear((f.plusvaliaEUR / f.invertidoEUR) * 100, 1) : null
    if (f.peso !== null && f.peso > reglas.pesoMaximo) {
      const hasta = f.valorEUR / reglas.pesoMaximo - total
      alertas.push(
        `${f.ticker} pesa un ${redondear(f.peso * 100, 1)} % (máximo ${reglas.pesoMaximo * 100} %). ` +
          `Para diluirlo solo con aportaciones harían falta unos ${Math.ceil(hasta)} € nuevos en otras posiciones.`
      )
    }
  }

  const hhi = conValor.reduce((s, f) => s + f.peso ** 2, 0)
  const posicionesEfectivas = hhi > 0 ? 1 / hhi : null
  if (posicionesEfectivas !== null && posicionesEfectivas < 5 && conValor.length > 0) {
    alertas.push(
      `Diversificación efectiva de ${redondear(posicionesEfectivas, 1)} posiciones: ` +
        'la cartera se comporta como si tuviera muy pocas empresas.'
    )
  }

  const porMoneda = {}
  for (const f of conValor) porMoneda[f.moneda] = (porMoneda[f.moneda] || 0) + f.valorEUR
  const porSector = {}
  for (const f of conValor) porSector[f.sector || 'sin asignar'] = (porSector[f.sector || 'sin asignar'] || 0) + f.valorEUR

  for (const f of filas) {
    f.valorEUR = eur(f.valorEUR)
    f.peso = redondear(f.peso === null ? null : f.peso * 100, 1)
  }

  return {
    moneda: 'EUR',
    totales: {
      valorEUR: eur(total),
      invertidoEUR: eur(invertido),
      plusvaliaEUR: eur(total - invertido),
      plusvaliaPct: invertido ? redondear(((total - invertido) / invertido) * 100, 1) : null,
      posiciones: filas.length,
    },
    concentracion: {
      pesoMaximoPct: redondear(Math.max(0, ...conValor.map((f) => f.peso)), 1),
      indiceHerfindahl: redondear(hhi, 3),
      posicionesEfectivas: redondear(posicionesEfectivas, 1),
      limitePorPosicionPct: reglas.pesoMaximo * 100,
    },
    exposicionMonedaPct: Object.fromEntries(Object.entries(porMoneda).map(([k, v]) => [k, redondear((v / total) * 100, 1)])),
    exposicionSectorPct: Object.fromEntries(Object.entries(porSector).map(([k, v]) => [k, redondear((v / total) * 100, 1)])),
    posiciones: filas.sort((a, b) => (b.valorEUR ?? 0) - (a.valorEUR ?? 0)),
    tiposDeCambio: cambios,
    alertas,
  }
}

/**
 * Reparte una aportación entre las empresas mejor puntuadas que aún caben
 * bajo el peso máximo.
 *
 * Rebalancear con dinero nuevo en vez de vendiendo es deliberado: vender
 * realiza plusvalías que tributan en el IRPF, y la aportación ya diluye lo que
 * pesa de más. La propuesta no vende nunca; si hace falta vender, lo tiene que
 * decidir una persona con la fiscalidad delante.
 */
export function proponerAportacion(valorada, analisis, importeEUR, opciones = {}) {
  const reglas = { ...REGLAS_POR_DEFECTO, ...(opciones.reglas || {}) }
  if (!(importeEUR > 0)) throw new Error('El importe de la aportación tiene que ser positivo')
  const total = valorada.totales.valorEUR
  const totalNuevo = total + importeEUR
  const techo = reglas.pesoMaximo * totalNuevo
  const enCartera = new Map(valorada.posiciones.map((p) => [p.ticker, p]))

  const descartados = []
  const candidatos = []
  for (const [ticker, a] of Object.entries(analisis)) {
    if (!a || a.error) {
      descartados.push({ ticker, motivo: a?.error ? `sin análisis: ${a.error}` : 'sin análisis' })
      continue
    }
    const puntuacion = a.puntuacion?.total ?? null
    if (puntuacion === null) {
      descartados.push({ ticker, motivo: 'sin puntuación (faltan datos)' })
      continue
    }
    if (['exigente', 'sin valoración', 'cíclica en pico'].includes(a.senal)) {
      descartados.push({ ticker, motivo: `señal «${a.senal}»` })
      continue
    }
    if (puntuacion < reglas.umbralPuntuacion) {
      descartados.push({ ticker, motivo: `puntuación ${puntuacion} < ${reglas.umbralPuntuacion}` })
      continue
    }
    const actual = enCartera.get(ticker)?.valorEUR ?? 0
    const hueco = techo - actual
    if (hueco < reglas.ordenMinimaEUR) {
      descartados.push({ ticker, motivo: `ya está en el peso máximo (${reglas.pesoMaximo * 100} %)` })
      continue
    }
    const margen = a.valorIntrinseco?.margenSeguridadBasePct ?? 0
    candidatos.push({
      ticker,
      nombre: a.nombre,
      puntuacion,
      senal: a.senal,
      margen,
      actual,
      hueco,
      // Más nota y más margen, más prioridad. El +5 evita que una empresa
      // justo en el umbral reciba cero.
      prioridad: (puntuacion - reglas.umbralPuntuacion + 5) * (1 + Math.max(0, margen) / 100),
    })
  }

  candidatos.sort((a, b) => b.prioridad - a.prioridad)
  // Una por sector en cada aportación: cuando un sector entero cae a la vez
  // (el software en 2026), las tres más baratas suelen ser la misma apuesta.
  const elegidos = []
  const sectores = new Set()
  for (const c of candidatos) {
    if (elegidos.length >= Math.max(1, reglas.maxOperaciones)) break
    const sector = analisis[c.ticker]?.sector
    if (sector && sectores.has(sector)) continue
    if (sector) sectores.add(sector)
    elegidos.push(c)
  }
  for (const c of candidatos) {
    if (elegidos.includes(c)) continue
    const repetido = analisis[c.ticker]?.sector && sectores.has(analisis[c.ticker].sector)
    descartados.push({
      ticker: c.ticker,
      motivo: repetido
        ? `apta, pero su sector (${analisis[c.ticker].sector}) ya entra en esta aportación`
        : `apta, pero fuera de las ${reglas.maxOperaciones} mejores`,
    })
  }

  // Reparto proporcional a la prioridad con tope por hueco; lo que no cabe en
  // una se reparte entre las demás.
  const asignado = new Map(elegidos.map((c) => [c.ticker, 0]))
  let pendiente = importeEUR
  let activos = elegidos.slice()
  for (let vuelta = 0; vuelta < 10 && pendiente > 0.5 && activos.length; vuelta++) {
    const suma = activos.reduce((s, c) => s + c.prioridad, 0)
    let sobrante = 0
    const siguen = []
    for (const c of activos) {
      const parte = (pendiente * c.prioridad) / suma
      const cabe = c.hueco - asignado.get(c.ticker)
      const toma = Math.min(parte, cabe)
      asignado.set(c.ticker, asignado.get(c.ticker) + toma)
      sobrante += parte - toma
      if (parte < cabe) siguen.push(c)
    }
    pendiente = sobrante
    activos = siguen
  }

  // Órdenes demasiado pequeñas: su importe pasa a la primera que tenga sitio.
  for (const c of [...elegidos].reverse()) {
    const cantidad = asignado.get(c.ticker)
    if (cantidad > 0 && cantidad < reglas.ordenMinimaEUR) {
      asignado.set(c.ticker, 0)
      const destino = elegidos.find((d) => d !== c && asignado.get(d.ticker) >= reglas.ordenMinimaEUR && d.hueco - asignado.get(d.ticker) >= cantidad)
      if (destino) asignado.set(destino.ticker, asignado.get(destino.ticker) + cantidad)
      else pendiente += cantidad
    }
  }

  const operaciones = elegidos
    .filter((c) => asignado.get(c.ticker) >= reglas.ordenMinimaEUR)
    .map((c) => {
      const importe = Math.floor(asignado.get(c.ticker))
      return {
        ticker: c.ticker,
        nombre: c.nombre,
        importeEUR: importe,
        yaEnCartera: c.actual > 0,
        pesoTrasAportacionPct: redondear(((c.actual + importe) / totalNuevo) * 100, 1),
        motivo: `puntuación ${c.puntuacion}, señal «${c.senal}», margen de seguridad base ${c.margen ?? '—'} %`,
      }
    })
  const usado = operaciones.reduce((s, o) => s + o.importeEUR, 0)

  const notas = []
  const comision = operaciones.length * reglas.comisionPorOrdenEUR
  if (comision > 0) {
    notas.push(
      `${operaciones.length} órdenes × ${reglas.comisionPorOrdenEUR} € = ${comision} € de comisión ` +
        `(${redondear((comision / Math.max(usado, 1)) * 100, 2)} % de lo invertido). Un plan de ahorro periódico suele no tener comisión.`
    )
  }
  for (const p of valorada.posiciones) {
    if (p.valorEUR !== null && p.valorEUR / totalNuevo > reglas.pesoMaximo) {
      notas.push(
        `${p.ticker} seguirá por encima del ${reglas.pesoMaximo * 100} % tras esta aportación ` +
          `(${redondear((p.valorEUR / totalNuevo) * 100, 1)} %). No se propone vender: ver la skill de revisión para la parte fiscal.`
      )
    }
  }
  if (!candidatos.length) {
    notas.push('Ninguna empresa analizada pasa los filtros. Quedarse en liquidez también es una decisión.')
  }

  return {
    importeEUR,
    reglas,
    operaciones,
    sinAsignarEUR: redondear(importeEUR - usado, 2),
    descartados,
    notas,
  }
}

function numeroPositivo(x, nombre) {
  if (typeof x !== 'number' || !Number.isFinite(x) || x <= 0) {
    throw new Error(`${nombre} tiene que ser un número positivo`)
  }
  return x
}

/**
 * Aplica una compra, venta o dividendo a la cartera. Devuelve una copia; no
 * escribe en disco.
 *
 * El coste de las ventas se calcula por precio medio, que es lo que enseña el
 * broker. Hacienda usa FIFO para valores homogéneos: para la declaración vale
 * el informe fiscal del broker, no esto.
 */
export function registrarOperacion(cartera, op) {
  const copia = structuredClone(cartera)
  copia.posiciones = copia.posiciones || []
  copia.operaciones = copia.operaciones || []
  const tipo = op.tipo
  if (!['compra', 'venta', 'dividendo'].includes(tipo)) throw new Error('tipo tiene que ser compra, venta o dividendo')
  if (!op.ticker) throw new Error('Falta el ticker')
  if (!/^\d{4}-\d{2}-\d{2}$/.test(op.fecha || '')) throw new Error('fecha tiene que ser AAAA-MM-DD')
  const importe = numeroPositivo(op.importeEUR, 'importeEUR')
  const comision = op.comisionEUR ?? 0
  if (typeof comision !== 'number' || !Number.isFinite(comision) || comision < 0) throw new Error('comisionEUR no válida')

  let pos = copia.posiciones.find((p) => p.ticker === op.ticker)
  let resultado = null

  if (tipo === 'compra') {
    const participaciones = numeroPositivo(op.participaciones, 'participaciones')
    if (!pos) {
      pos = { nombre: op.nombre || op.ticker, ticker: op.ticker, participaciones: 0, invertidoEUR: 0 }
      if (op.simboloCotizacion) pos.simboloCotizacion = op.simboloCotizacion
      copia.posiciones.push(pos)
    }
    pos.participaciones = redondear(pos.participaciones + participaciones, 6)
    pos.invertidoEUR = redondear(pos.invertidoEUR + importe + comision, 2)
  } else if (tipo === 'venta') {
    const participaciones = numeroPositivo(op.participaciones, 'participaciones')
    if (!pos) throw new Error(`No hay posición en ${op.ticker} que vender`)
    if (participaciones > pos.participaciones + 1e-6) {
      throw new Error(`Vendes ${participaciones} y solo hay ${pos.participaciones}`)
    }
    const costeMedio = pos.invertidoEUR / pos.participaciones
    const costeVendido = costeMedio * participaciones
    resultado = redondear(importe - comision - costeVendido, 2)
    pos.participaciones = redondear(pos.participaciones - participaciones, 6)
    pos.invertidoEUR = redondear(pos.invertidoEUR - costeVendido, 2)
    if (pos.participaciones <= 1e-6) copia.posiciones = copia.posiciones.filter((p) => p !== pos)
  }

  copia.operaciones.push({
    fecha: op.fecha,
    tipo,
    ticker: op.ticker,
    participaciones: op.participaciones ?? null,
    importeEUR: importe,
    comisionEUR: comision,
    ...(resultado !== null ? { resultadoEUR: resultado } : {}),
    ...(op.nota ? { nota: op.nota } : {}),
  })
  return { cartera: copia, resultadoEUR: resultado }
}

/** Añade o sustituye la foto del día en el histórico. */
export function anotarFoto(cartera, fecha, valorada) {
  const copia = structuredClone(cartera)
  const historico = (copia.historico || []).filter((h) => h.fecha !== fecha)
  historico.push({
    fecha,
    valorEUR: valorada.totales.valorEUR,
    invertidoEUR: valorada.totales.invertidoEUR,
  })
  copia.historico = historico.sort((a, b) => a.fecha.localeCompare(b.fecha))
  return copia
}
