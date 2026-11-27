/**
 * Las tres fuentes de datos, todas públicas y sin cuenta:
 *
 *   SEC EDGAR   cuentas oficiales de las empresas que cotizan en EE. UU.
 *   Yahoo       cotizaciones (endpoint de gráficos, no documentado)
 *   BCE         tipos de cambio de referencia
 *
 * Todo pasa por una caché en disco: las cuentas cambian una vez por trimestre
 * y la SEC pide no pasar de diez peticiones por segundo.
 */

import { mkdirSync, readFileSync, renameSync, statSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { join } from 'node:path'
import { CONCEPTOS_BALANCE, CONCEPTOS_FLUJO } from './xbrl.mjs'

// La SEC exige identificarse. Sin correo por defecto: cada cual pone el suyo
// en la variable si la SEC empieza a rechazar las peticiones.
const AGENTE = process.env.INVERSIONES_USER_AGENT || 'cartera-de-valor/1.0 (uso personal)'

export const DIR_CACHE = process.env.INVERSIONES_CACHE || join(homedir(), '.cache', 'cartera-de-valor')

const HORA = 3600000
export const VIGENCIA = {
  cuentas: 24 * HORA,
  empresa: 7 * 24 * HORA,
  tickers: 7 * 24 * HORA,
  cotizacion: 15 * 60000,
  cambio: 12 * HORA,
}

function rutaCache(clave) {
  return join(DIR_CACHE, clave.replace(/[^A-Za-z0-9._-]/g, '_') + '.json')
}

function leerCache(clave, vigencia) {
  try {
    const ruta = rutaCache(clave)
    if (Date.now() - statSync(ruta).mtimeMs > vigencia) return null
    return JSON.parse(readFileSync(ruta, 'utf8'))
  } catch {
    return null
  }
}

/** La copia caducada, para cuando la red falla: mejor un dato viejo con fecha que nada. */
function leerCacheCaducada(clave) {
  try {
    return JSON.parse(readFileSync(rutaCache(clave), 'utf8'))
  } catch {
    return null
  }
}

function escribirCache(clave, datos) {
  try {
    mkdirSync(DIR_CACHE, { recursive: true })
    const ruta = rutaCache(clave)
    const temporal = `${ruta}.${process.pid}.tmp`
    writeFileSync(temporal, JSON.stringify(datos))
    renameSync(temporal, ruta)
  } catch {
    // Sin caché se funciona igual, solo más lento.
  }
}

const esperar = (ms) => new Promise((r) => setTimeout(r, ms))

// Las peticiones a cada servicio hacen cola aunque las lancen varios análisis
// en paralelo. La SEC permite diez por segundo y aquí van unas ocho; Yahoo no
// publica límite pero responde 429 a ráfagas.
const ESPACIADO_MS = { sec: 125, yahoo: 300 }
const colas = {}
function turno(servicio) {
  const t = (colas[servicio] || Promise.resolve()).then(() => esperar(ESPACIADO_MS[servicio]))
  colas[servicio] = t
  return t
}

function servicioDe(url) {
  const host = new URL(url).host
  if (host.endsWith('sec.gov')) return 'sec'
  if (host.endsWith('yahoo.com')) return 'yahoo'
  return null
}

async function pedirJSON(url, { intentos = 3 } = {}) {
  let ultimoError
  const servicio = servicioDe(url)
  for (let i = 0; i < intentos; i++) {
    if (servicio) await turno(servicio)
    try {
      const respuesta = await fetch(url, {
        headers: { 'User-Agent': AGENTE, Accept: 'application/json' },
        signal: AbortSignal.timeout(30000),
      })
      if (respuesta.status === 429 || respuesta.status >= 500) {
        ultimoError = new Error(`${new URL(url).host} respondió ${respuesta.status}`)
        await esperar(1000 * 2 ** i)
        continue
      }
      if (!respuesta.ok) throw new Error(`${new URL(url).host} respondió ${respuesta.status}`)
      return await respuesta.json()
    } catch (error) {
      ultimoError = error
      if (error.name === 'TimeoutError' || error.cause) await esperar(1000 * 2 ** i)
      else throw error
    }
  }
  throw ultimoError
}

async function conCache(clave, vigencia, obtener) {
  const fresca = leerCache(clave, vigencia)
  if (fresca) return fresca
  try {
    const datos = await obtener()
    escribirCache(clave, datos)
    return datos
  } catch (error) {
    const vieja = leerCacheCaducada(clave)
    if (vieja) return { ...vieja, _caducada: `red no disponible (${error.message}); copia anterior` }
    throw error
  }
}

// ─── SEC ─────────────────────────────────────────────────────────────────────

export async function mapaTickers() {
  const crudo = await conCache('sec-tickers', VIGENCIA.tickers, () =>
    pedirJSON('https://www.sec.gov/files/company_tickers.json')
  )
  const mapa = {}
  for (const v of Object.values(crudo)) {
    if (v && v.ticker) mapa[v.ticker.toUpperCase()] = { cik: v.cik_str, nombre: v.title }
  }
  return mapa
}

export async function cikDe(ticker) {
  const mapa = await mapaTickers()
  // La SEC escribe las clases con guion (BRK-B) y otros sitios con punto.
  const t = ticker.toUpperCase().replace('.', '-')
  const entrada = mapa[t]
  if (!entrada) {
    throw new Error(
      `${ticker} no está en la SEC. Si cotiza fuera de EE. UU., crea ` +
        `datos/fundamentales/${ticker}.json con sus cuentas (ver README).`
    )
  }
  return entrada.cik
}

const cik10 = (cik) => String(cik).padStart(10, '0')

// Lo que xbrl.mjs puede llegar a leer. El companyfacts entero pesa 2-5 MB por
// empresa; recortado a esto se queda en unos cientos de KB, y una criba de
// cincuenta empresas cabe en caché sin pensarlo.
const CONCEPTOS_USADOS = new Set([
  ...Object.values(CONCEPTOS_FLUJO).flat(),
  ...Object.values(CONCEPTOS_BALANCE).flat(),
  'WeightedAverageNumberOfDilutedSharesOutstanding',
])

export function recortarCuentas(cf) {
  const usGaap = cf?.facts?.['us-gaap'] || {}
  return {
    cik: cf.cik,
    entityName: cf.entityName,
    facts: {
      dei: { EntityCommonStockSharesOutstanding: cf?.facts?.dei?.EntityCommonStockSharesOutstanding },
      'us-gaap': Object.fromEntries(Object.entries(usGaap).filter(([c]) => CONCEPTOS_USADOS.has(c))),
    },
  }
}

export async function cuentasSEC(ticker) {
  const cik = await cikDe(ticker)
  return conCache(`sec-cuentas-${cik10(cik)}`, VIGENCIA.cuentas, async () =>
    recortarCuentas(await pedirJSON(`https://data.sec.gov/api/xbrl/companyfacts/CIK${cik10(cik)}.json`))
  )
}

/** Sector (código SIC) y cierre fiscal. Pequeño: solo se guarda lo que se usa. */
export async function fichaSEC(ticker) {
  const cik = await cikDe(ticker)
  return conCache(`sec-ficha-${cik10(cik)}`, VIGENCIA.empresa, async () => {
    const d = await pedirJSON(`https://data.sec.gov/submissions/CIK${cik10(cik)}.json`)
    return {
      nombre: d.name,
      sic: d.sic ? Number(d.sic) : null,
      sector: d.sicDescription || null,
      cierreFiscal: d.fiscalYearEnd || null,
      tickers: d.tickers || [],
    }
  })
}

/**
 * Bancos, aseguradoras, brokers y gestoras (SIC 6000-6799, salvo los REIT de
 * 6798, que sí se valoran por flujos): ahí EV, deuda y flujo libre no
 * significan lo que en una empresa industrial.
 */
export function esFinanciera(sic) {
  return sic !== null && sic >= 6000 && sic <= 6799 && sic !== 6798
}

// ─── Cotizaciones ────────────────────────────────────────────────────────────

export async function cotizacion(simbolo) {
  const datos = await conCache(`cot-${simbolo}`, VIGENCIA.cotizacion, async () => {
    const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(simbolo)}?range=1y&interval=1wk&events=split`
    const d = await pedirJSON(url)
    const r = d?.chart?.result?.[0]
    if (!r?.meta?.regularMarketPrice) {
      throw new Error(`Sin cotización para ${simbolo}: ${d?.chart?.error?.description || 'respuesta vacía'}`)
    }
    const cierres = (r.timestamp || [])
      .map((ts, i) => ({ fecha: new Date(ts * 1000).toISOString().slice(0, 10), cierre: r.indicators?.quote?.[0]?.close?.[i] }))
      .filter((x) => typeof x.cierre === 'number')
    return {
      simbolo,
      valor: r.meta.regularMarketPrice,
      moneda: r.meta.currency,
      fecha: new Date(r.meta.regularMarketTime * 1000).toISOString(),
      nombre: r.meta.longName || r.meta.shortName || simbolo,
      maximo52: r.meta.fiftyTwoWeekHigh ?? null,
      minimo52: r.meta.fiftyTwoWeekLow ?? null,
      semanal: cierres.map((x) => ({ fecha: x.fecha, cierre: Math.round(x.cierre * 100) / 100 })),
      // Hacen falta para cuadrar el número de acciones de la SEC, que puede
      // ser de antes del split, con un precio que ya es de después.
      splits: Object.values(r.events?.splits || {})
        .filter((s) => s.numerator > 0 && s.denominator > 0)
        .map((s) => ({ fecha: new Date(s.date * 1000).toISOString().slice(0, 10), factor: s.numerator / s.denominator })),
    }
  })
  return datos
}

// ─── Tipos de cambio ─────────────────────────────────────────────────────────

/** Unidades de `moneda` por euro, del BCE. */
export async function cambioPorEuro(moneda) {
  if (moneda === 'EUR') return { valor: 1, fecha: null }
  const datos = await conCache(`bce-${moneda}`, VIGENCIA.cambio, async () => {
    const url = `https://data-api.ecb.europa.eu/service/data/EXR/D.${moneda}.EUR.SP00.A?lastNObservations=1&format=jsondata`
    const d = await pedirJSON(url)
    const serie = Object.values(d?.dataSets?.[0]?.series || {})[0]
    const obs = serie?.observations || {}
    const claves = Object.keys(obs)
    if (!claves.length) throw new Error(`El BCE no publica cambio para ${moneda}`)
    const ultima = claves.sort((a, b) => Number(a) - Number(b)).pop()
    const fechas = d.structure?.dimensions?.observation?.[0]?.values || []
    return { valor: obs[ultima][0], fecha: fechas[Number(ultima)]?.id ?? null }
  })
  return datos
}

export async function cambiosPara(monedas) {
  const cambios = {}
  const fechas = {}
  for (const m of new Set(monedas.filter(Boolean).map((x) => (x === 'GBp' || x === 'GBX' ? 'GBP' : x)))) {
    const c = await cambioPorEuro(m)
    cambios[m] = c.valor
    fechas[m] = c.fecha
  }
  return { cambios, fechas }
}
