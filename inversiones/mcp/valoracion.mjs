/**
 * Análisis de inversión en valor a partir de un objeto `datos` normalizado
 * (ver xbrl.mjs) y un precio. Funciones puras: no tocan la red ni el disco.
 *
 * Criterio general: cuando un dato falta o no tiene sentido, la métrica sale
 * `null` y se dice por qué. Una cifra inventada en una valoración es peor que
 * un hueco, porque nadie la vuelve a mirar.
 */

export const SUPUESTOS_POR_DEFECTO = {
  tasaDescuento: 0.09,
  crecimientoTerminal: 0.025,
  anios: 10,
  // Nadie sostiene un 40 % diez años. El histórico se recorta a este tope
  // antes de usarlo como hipótesis central.
  topeCrecimiento: 0.12,
  sueloCrecimiento: -0.05,
}

const M = 1e6

export function redondear(x, decimales = 1) {
  if (x === null || x === undefined || !Number.isFinite(x)) return null
  const f = 10 ** decimales
  return Math.round(x * f) / f
}

const pct = (x) => redondear(x === null ? null : x * 100, 1)
const millones = (x) => redondear(x === null ? null : x / M, 0)

function dividir(a, b) {
  if (a === null || a === undefined || b === null || b === undefined || b === 0) return null
  const r = a / b
  return Number.isFinite(r) ? r : null
}

/** Tasa de crecimiento anual compuesta entre dos valores positivos. */
export function cagr(inicial, final, anios) {
  if (!(inicial > 0) || !(final > 0) || !(anios > 0)) return null
  return (final / inicial) ** (1 / anios) - 1
}

function cagrSerie(serie, anios) {
  const valores = serie.filter((v) => v !== null)
  if (serie.length < anios + 1) return null
  const final = serie[serie.length - 1]
  const inicial = serie[serie.length - 1 - anios]
  if (final === null || inicial === null || valores.length < 2) return null
  return cagr(inicial, final, anios)
}

/**
 * Valor presente de un flujo que crece a `g` durante `anios` y después a
 * `gTerminal` para siempre, descontado a `r`.
 */
export function valorPresente(flujo0, g, { tasaDescuento: r, crecimientoTerminal: gt, anios }) {
  if (!(r > gt)) throw new Error('La tasa de descuento tiene que superar al crecimiento terminal')
  let total = 0
  let flujo = flujo0
  for (let t = 1; t <= anios; t++) {
    flujo *= 1 + g
    total += flujo / (1 + r) ** t
  }
  const terminal = (flujo * (1 + gt)) / (r - gt)
  return total + terminal / (1 + r) ** anios
}

/**
 * DCF inverso: qué crecimiento anual del flujo durante `anios` justifica el
 * valor que el mercado le da hoy. Es la pregunta de Mauboussin: en vez de
 * adivinar el futuro, leer qué futuro está pagando el precio.
 */
export function crecimientoImplicito(flujo0, valorObjetivo, supuestos) {
  if (!(flujo0 > 0) || !(valorObjetivo > 0)) return null
  let bajo = -0.5
  let alto = 1.0
  if (valorPresente(flujo0, alto, supuestos) < valorObjetivo) return alto
  if (valorPresente(flujo0, bajo, supuestos) > valorObjetivo) return bajo
  for (let i = 0; i < 100; i++) {
    const medio = (bajo + alto) / 2
    if (valorPresente(flujo0, medio, supuestos) < valorObjetivo) bajo = medio
    else alto = medio
  }
  return (bajo + alto) / 2
}

/**
 * F-Score de Piotroski con los dos últimos ejercicios. Cada criterio que no se
 * puede evaluar queda `null` y no suma ni resta: la nota se da sobre los
 * evaluables.
 */
export function piotroski(anual) {
  const n = anual.fines.length
  if (n < 2) return null
  const i = n - 1
  const j = n - 2
  const a = (clave, k) => anual[clave]?.[k] ?? null
  const roa = (k) => dividir(a('beneficioNeto', k), a('activos', k))
  const ratioCorriente = (k) => dividir(a('activoCorriente', k), a('pasivoCorriente', k))
  const apalancamiento = (k) => dividir(a('deuda', k) ?? 0, a('activos', k))
  const margenBruto = (k) => {
    const bruto = a('beneficioBruto', k) ?? (a('ingresos', k) !== null && a('costeVentas', k) !== null ? a('ingresos', k) - a('costeVentas', k) : null)
    return dividir(bruto, a('ingresos', k))
  }
  const rotacion = (k) => dividir(a('ingresos', k), a('activos', k))
  const compara = (x, y, mejorSiMayor = true) => (x === null || y === null ? null : mejorSiMayor ? x > y : x < y)

  const criterios = {
    'ROA positivo': roa(i) === null ? null : roa(i) > 0,
    'Flujo operativo positivo': a('fco', i) === null ? null : a('fco', i) > 0,
    'ROA mejora': compara(roa(i), roa(j)),
    'Flujo operativo > beneficio (calidad del beneficio)':
      a('fco', i) === null || a('beneficioNeto', i) === null ? null : a('fco', i) > a('beneficioNeto', i),
    // Sin deuda los dos años cuenta como punto: no hay apalancamiento que bajar.
    'Apalancamiento baja':
      apalancamiento(i) === 0 && apalancamiento(j) === 0 ? true : compara(apalancamiento(i), apalancamiento(j), false),
    'Liquidez corriente mejora': compara(ratioCorriente(i), ratioCorriente(j)),
    'Sin emisión de acciones': compara(a('accionesDiluidas', i), a('accionesDiluidas', j) === null ? null : a('accionesDiluidas', j) * 1.005, false),
    'Margen bruto mejora': compara(margenBruto(i), margenBruto(j)),
    'Rotación de activos mejora': compara(rotacion(i), rotacion(j)),
  }
  const evaluables = Object.values(criterios).filter((v) => v !== null)
  return {
    puntos: evaluables.filter(Boolean).length,
    evaluables: evaluables.length,
    ejercicio: anual.fines[i],
    criterios,
  }
}

/** Interpolación lineal recortada a [0, 100] entre un valor malo y uno bueno. */
function nota(valor, malo, bueno) {
  if (valor === null || valor === undefined || !Number.isFinite(valor)) return null
  const t = (valor - malo) / (bueno - malo)
  return Math.max(0, Math.min(100, t * 100))
}

function media(notas) {
  const v = notas.filter((x) => x !== null)
  return v.length ? v.reduce((s, x) => s + x, 0) / v.length : null
}

/**
 * Análisis completo de una empresa.
 *
 * @param datos     objeto normalizado (xbrl.mjs o archivo manual)
 * @param precio    { valor, moneda, fecha } del mercado
 * @param opciones  { conversion, supuestos, financiera, hoy }
 *   conversion: multiplica el precio para pasarlo a la moneda de informe
 *   (1 si coinciden). financiera: bancos, aseguradoras y brokers, donde EV,
 *   deuda y flujo libre no significan lo mismo y se valora por beneficio.
 */
export function analizar(datos, precio, opciones = {}) {
  const supuestos = { ...SUPUESTOS_POR_DEFECTO, ...(opciones.supuestos || {}) }
  const financiera = Boolean(opciones.financiera ?? datos.financiera)
  const conversion = opciones.conversion ?? 1
  const hoy = opciones.hoy ? new Date(opciones.hoy) : new Date()
  const t = datos.ttm || {}
  const b = datos.balance || {}
  const anual = datos.anual || { fines: [] }
  const alertas = []

  const precioInforme = precio?.valor ? precio.valor * conversion : null
  const acciones = datos.acciones ?? null
  const capitalizacion = precioInforme && acciones ? precioInforme * acciones : null

  const caja = (b.caja ?? 0) + (b.inversionesCP ?? 0)
  const deuda = b.deuda ?? 0
  const deudaNeta = financiera ? null : deuda - caja
  const ev = capitalizacion === null ? null : financiera ? capitalizacion : capitalizacion + deudaNeta

  const bruto = t.beneficioBruto ?? (t.ingresos !== undefined && t.costeVentas !== undefined ? t.ingresos - t.costeVentas : null)
  let ebit = t.ebit ?? null
  let ebitAproximado = false
  if (ebit === null && t.preImpuestos !== undefined) {
    // Sin línea de resultado operativo (Zoetis): antes de impuestos más
    // intereses es la aproximación estándar.
    ebit = t.preImpuestos + (t.intereses ?? 0)
    ebitAproximado = true
  }
  const fcl = t.fco !== undefined && t.capex !== undefined ? t.fco - t.capex : t.fco ?? null
  // La remuneración en acciones es un gasto real aunque no salga de caja:
  // diluye al accionista. Restarla es lo conservador, y en tecnológicas
  // cambia mucho la foto.
  const fclAjustado = fcl === null ? null : fcl - (t.sbc ?? 0)
  // Flujo del propietario (Buffett): operativo menos la amortización como
  // capex de mantenimiento, menos acciones. Cuando una empresa invierte muy por
  // encima de lo que se le desgasta (Alphabet, Meta en 2026), el flujo libre
  // sale deprimido por crecimiento y no por falta de caja. Se enseña al lado,
  // sin sustituir al conservador: que esa inversión rinda está por demostrar.
  const capexIntensivo = !financiera && t.capex !== undefined && t.amortizacion > 0 && t.capex > 1.5 * t.amortizacion
  const flujoPropietario = t.fco !== undefined && t.amortizacion !== undefined ? t.fco - t.amortizacion - (t.sbc ?? 0) : null
  const tipoImpositivo = (() => {
    const tasa = dividir(t.impuestos, t.preImpuestos)
    return tasa === null || tasa < 0 || tasa > 0.35 ? 0.21 : tasa
  })()

  const capitalInvertido = b.patrimonio !== null && b.patrimonio !== undefined ? b.patrimonio + deuda - caja : null
  const capitalSignificativo = capitalInvertido !== null && b.activos ? capitalInvertido > 0.05 * b.activos : false
  const roic = !financiera && capitalSignificativo && ebit !== null ? (ebit * (1 - tipoImpositivo)) / capitalInvertido : null
  const roe = b.patrimonio > 0 && t.beneficioNeto !== undefined ? t.beneficioNeto / b.patrimonio : null

  const ebitda = ebit !== null ? ebit + (t.amortizacion ?? 0) : null

  const multiplos = {
    per: t.beneficioNeto > 0 && capitalizacion ? redondear(capitalizacion / t.beneficioNeto) : null,
    evEbit: !financiera && ebit > 0 && ev ? redondear(ev / ebit) : null,
    precioValorContable: b.patrimonio > 0 && capitalizacion ? redondear(capitalizacion / b.patrimonio, 2) : null,
    rentabilidadBeneficioPct: !financiera && ev > 0 && ebit !== null ? pct(ebit / ev) : null,
    rentabilidadFclPct: !financiera && capitalizacion && fclAjustado !== null ? pct(fclAjustado / capitalizacion) : null,
    rentabilidadDividendoPct: capitalizacion && t.dividendos ? pct(t.dividendos / capitalizacion) : null,
    rentabilidadAccionistaPct: capitalizacion && (t.dividendos || t.recompras) ? pct(((t.dividendos ?? 0) + (t.recompras ?? 0)) / capitalizacion) : null,
  }

  const crecimiento = {
    ingresos3aPct: pct(cagrSerie(anual.ingresos || [], 3)),
    ingresos5aPct: pct(cagrSerie(anual.ingresos || [], 5)),
    beneficio3aPct: pct(cagrSerie(anual.beneficioNeto || [], 3)),
    acciones3aPct: pct(cagrSerie(anual.accionesDiluidas || [], 3)),
  }

  // Crecimiento «sostenible»: el menor de los históricos de 3 y 5 años,
  // recortado. Es la hipótesis central deliberadamente aburrida.
  const historicos = [crecimiento.ingresos3aPct, crecimiento.ingresos5aPct].filter((x) => x !== null)
  const historico = historicos.length ? Math.min(...historicos) / 100 : null
  const crecimientoBase =
    opciones.supuestos?.crecimientoBase ??
    (historico === null ? null : Math.max(supuestos.sueloCrecimiento, Math.min(supuestos.topeCrecimiento, historico)))

  // Flujo que se valora: FCL menos acciones para empresas normales; beneficio
  // neto para financieras. El valor que se compara es el EV o, en
  // financieras, la capitalización.
  const flujo = financiera ? t.beneficioNeto ?? null : fclAjustado
  const flujoNombre = financiera ? 'beneficio neto' : 'flujo de caja libre menos remuneración en acciones'

  let expectativas = null
  let valorIntrinseco = null
  if (flujo > 0 && ev > 0) {
    const implicito = crecimientoImplicito(flujo, ev, supuestos)
    expectativas = {
      crecimientoImplicitoPct: pct(implicito),
      crecimientoSostenibleHistoricoPct: pct(crecimientoBase),
      brechaPP: crecimientoBase === null ? null : redondear((crecimientoBase - implicito) * 100),
      lectura:
        crecimientoBase === null
          ? 'Sin histórico suficiente para comparar.'
          : implicito <= crecimientoBase
            ? 'El precio pide menos crecimiento del que la empresa ha logrado: margen a favor.'
            : 'El precio pide más crecimiento del que la empresa ha logrado: hay que creer en una aceleración.',
    }
  } else if (flujo !== null && flujo <= 0) {
    alertas.push(`${flujoNombre} negativo o nulo: no se puede valorar por flujos`)
  }

  const escenario = (f, g, r) => {
    const s = { ...supuestos, tasaDescuento: r }
    const valorEmpresa = valorPresente(f, g, s)
    const valorAccionistas = financiera ? valorEmpresa : valorEmpresa - deudaNeta
    return Math.max(0, valorAccionistas) / acciones / conversion
  }
  // Un margen de −2.900 % no dice más que uno de −100 %: el modelo no
  // justifica el precio. Se recorta para que las tablas se puedan leer.
  const margenDe = (valor) => pct(valor > 0 ? Math.max(-1, 1 - precio.valor / valor) : -1)

  let propietario = null
  if (capexIntensivo) {
    alertas.push(
      `Capex ${redondear(t.capex / t.amortizacion)}× la amortización: el flujo libre está deprimido por inversión; mira flujoPropietario`
    )
    if (flujoPropietario > 0 && ev > 0) {
      const base = crecimientoBase !== null && acciones && capitalizacion ? escenario(flujoPropietario, crecimientoBase, supuestos.tasaDescuento) : null
      propietario = {
        flujoM: millones(flujoPropietario),
        como: 'flujo operativo − amortización (capex de mantenimiento) − remuneración en acciones',
        crecimientoImplicitoPct: pct(crecimientoImplicito(flujoPropietario, ev, supuestos)),
        valorBase: redondear(base, 2),
        margenSeguridadBasePct: base === null ? null : margenDe(base),
        lectura: 'Valoración que da por buena toda la inversión por encima de la amortización. Es la tesis optimista sobre ese capex, no la conservadora.',
      }
    }
  }

  if (flujo > 0 && crecimientoBase !== null && acciones && capitalizacion) {
    const r = supuestos.tasaDescuento
    // El pesimista es «la empresa deja de crecer»: la pregunta de Graham de
    // cuánto vale el negocio sin pagar nada por el futuro. Si ya decrece, se
    // le resta algo más.
    const gPesimista = crecimientoBase > 0 ? 0 : crecimientoBase - 0.03
    const gOptimista = Math.min(crecimientoBase + 0.04, 0.2)
    const base = escenario(flujo, crecimientoBase, r)
    valorIntrinseco = {
      moneda: precio?.moneda ?? datos.moneda,
      pesimista: redondear(escenario(flujo, gPesimista, r + 0.01), 2),
      base: redondear(base, 2),
      optimista: redondear(escenario(flujo, gOptimista, r - 0.01), 2),
      margenSeguridadBasePct: margenDe(base),
      supuestos: {
        flujo: flujoNombre,
        flujoInicialM: millones(flujo),
        crecimientoAnualPct: { pesimista: pct(gPesimista), base: pct(crecimientoBase), optimista: pct(gOptimista) },
        tasaDescuentoPct: { pesimista: pct(r + 0.01), base: pct(r), optimista: pct(r - 0.01) },
        crecimientoTerminalPct: pct(supuestos.crecimientoTerminal),
        anios: supuestos.anios,
      },
    }
  }

  const pf = financiera ? null : piotroski(anual)

  const calidad = {
    roicPct: pct(roic),
    roePct: pct(roe),
    margenBrutoPct: pct(dividir(bruto, t.ingresos)),
    margenOperativoPct: pct(dividir(ebit, t.ingresos)),
    margenFclPct: financiera ? null : pct(dividir(fclAjustado, t.ingresos)),
    piotroski: pf,
  }
  const solidez = {
    deudaNetaEbitda: !financiera && ebitda > 0 ? redondear(deudaNeta / ebitda, 2) : null,
    coberturaIntereses: !financiera && t.intereses > 0 && ebit !== null ? redondear(ebit / t.intereses) : null,
    deudaCriterio: b.deudaCriterio ?? null,
  }

  // ─── Alertas que convierten un «barato» en una trampa de valor ───
  if (!financiera && solidez.deudaNetaEbitda !== null && solidez.deudaNetaEbitda > 3) alertas.push(`Deuda neta alta: ${solidez.deudaNetaEbitda}× EBITDA`)
  if (crecimiento.acciones3aPct !== null && crecimiento.acciones3aPct > 2) alertas.push(`Dilución: las acciones crecen un ${crecimiento.acciones3aPct} % al año`)
  if (crecimiento.ingresos3aPct !== null && crecimiento.ingresos3aPct < 0) alertas.push(`Ingresos cayendo: ${crecimiento.ingresos3aPct} % anual en 3 años`)
  if (pf && pf.evaluables >= 7 && pf.puntos <= 3) alertas.push(`Piotroski bajo: ${pf.puntos}/${pf.evaluables}`)
  if (!financiera && solidez.coberturaIntereses !== null && solidez.coberturaIntereses < 4) alertas.push(`Cobertura de intereses justa: ${solidez.coberturaIntereses}×`)
  // Cíclicas: en el pico del ciclo el PER sale bajísimo justo cuando el
  // beneficio está a punto de caer. Es la trampa de valor más clásica.
  const margenesAnuales = anual.fines
    .map((_, k) => dividir(anual.ebit?.[k] ?? anual.beneficioNeto?.[k] ?? null, anual.ingresos?.[k] ?? null))
    .slice(-8)
    .filter((x) => x !== null)
  const ingresosAnuales = (anual.ingresos || []).slice(-8)
  // Un solo hundimiento de ingresos puede ser la pandemia; dos ya es ciclo.
  const caidas = ingresosAnuales.filter((v, k) => k > 0 && v !== null && ingresosAnuales[k - 1] > 0 && v < 0.85 * ingresosAnuales[k - 1]).length
  const huboCaida = caidas >= 2
  // Lo que distingue un ciclo de una empresa que madura (Uber pasó de −66 % a
  // +11 % de margen) es que el margen cae desde un máximo anterior, no la
  // distancia entre extremos.
  // Y solo cuenta caer desde un pico con beneficio: pasar de −27 % a −60 %
  // en el año de la salida a bolsa no es un ciclo.
  let caidaMargen = 0
  let picoPrevio = -Infinity
  for (const m of margenesAnuales) {
    picoPrevio = Math.max(picoPrevio, m)
    if (picoPrevio > 0.05) caidaMargen = Math.max(caidaMargen, picoPrevio - m)
  }
  let ciclicaEnPico = false
  if (margenesAnuales.length >= 4) {
    const maximo = Math.max(...margenesAnuales)
    const minimo = Math.min(...margenesAnuales)
    if (caidaMargen > 0.15 || huboCaida) {
      const margenActual = dividir(ebit ?? t.beneficioNeto ?? null, t.ingresos ?? null)
      const enMaximos = margenActual !== null && margenActual >= 0.9 * maximo
      ciclicaEnPico = enMaximos
      alertas.push(
        `Negocio cíclico (margen entre ${pct(minimo)} % y ${pct(maximo)} % en ${margenesAnuales.length} años` +
          (huboCaida ? `, con ${caidas} caídas de ingresos de más del 15 %` : '') +
          (enMaximos ? '): márgenes en máximos, los múltiplos de hoy pueden ser de pico' : '): normaliza el beneficio antes de fiarte de los múltiplos')
      )
    }
  }
  if (ebitAproximado) alertas.push('EBIT aproximado como resultado antes de impuestos + intereses (no publica resultado operativo)')
  if (t.sbc && fcl > 0 && t.sbc / fcl > 0.25) alertas.push(`La remuneración en acciones se come el ${pct(t.sbc / fcl)} % del flujo libre`)
  if (datos.fechaBalance) {
    const antiguedad = (hoy - new Date(datos.fechaBalance)) / 86400000
    if (antiguedad > 200) alertas.push(`Datos de hace ${Math.round(antiguedad)} días (balance a ${datos.fechaBalance})`)
  }
  if (!acciones) alertas.push('Sin número de acciones: no hay capitalización ni múltiplos')
  if (precio?.moneda && datos.moneda && precio.moneda !== datos.moneda && conversion === 1) {
    alertas.push(`Precio en ${precio.moneda} y cuentas en ${datos.moneda} sin conversión: múltiplos no fiables`)
  }

  // ─── Puntuación absoluta 0-100: comparable entre empresas y entre fechas ───
  const notasValor = financiera
    ? [nota(multiplos.per ? 1 / multiplos.per : null, 0.03, 0.12), nota(multiplos.precioValorContable === null ? null : -multiplos.precioValorContable, -4, -1)]
    : [
        nota(multiplos.rentabilidadBeneficioPct, 0, 10),
        nota(multiplos.rentabilidadFclPct, 0, 8),
      ]
  notasValor.push(nota(expectativas?.brechaPP ?? null, -10, 10))
  notasValor.push(nota(valorIntrinseco?.margenSeguridadBasePct ?? null, -50, 40))
  const notasCalidad = financiera
    ? [nota(calidad.roePct, 5, 20)]
    : [nota(calidad.roicPct, 5, 25), nota(calidad.margenBrutoPct, 20, 70), nota(pf && pf.evaluables >= 5 ? (pf.puntos / pf.evaluables) * 9 : null, 2, 8)]
  notasCalidad.push(nota(crecimiento.acciones3aPct === null ? null : -crecimiento.acciones3aPct, -3, 2))
  const notasSolidez = financiera ? [] : [nota(solidez.deudaNetaEbitda === null ? null : -solidez.deudaNetaEbitda, -4, 0), nota(solidez.coberturaIntereses, 3, 15)]

  const valor = media(notasValor)
  const cal = media(notasCalidad)
  const sol = media(notasSolidez)
  const pesos = [
    [valor, 0.5],
    [cal, 0.35],
    [sol, 0.15],
  ].filter(([v]) => v !== null)
  const sumaPesos = pesos.reduce((s, [, p]) => s + p, 0)
  const total = sumaPesos ? pesos.reduce((s, [v, p]) => s + v * p, 0) / sumaPesos : null

  const margen = valorIntrinseco?.margenSeguridadBasePct ?? null
  const brecha = expectativas?.brechaPP ?? null
  let senal
  if (margen === null && brecha === null) senal = 'sin valoración'
  else if ((margen ?? -Infinity) >= 25 && (brecha ?? 0) >= 0) senal = 'infravalorada'
  else if ((margen ?? -Infinity) >= 10 && (brecha ?? 0) >= -2) senal = 'atractiva'
  else if ((margen !== null && margen <= -25) || (brecha !== null && brecha <= -5)) senal = 'exigente'
  else senal = 'en precio'
  // Barata sobre beneficios de pico no es barata: la señal no lo puede decir
  // sin que alguien normalice el ciclo a mano.
  if (ciclicaEnPico && (senal === 'infravalorada' || senal === 'atractiva')) senal = 'cíclica en pico'

  return {
    ticker: datos.ticker,
    nombre: datos.nombre,
    tipo: financiera ? 'financiera (se valora por beneficio, sin EV ni flujo libre)' : 'general',
    fuente: datos.fuente,
    monedaCuentas: datos.moneda,
    fechaBalance: datos.fechaBalance,
    presentado: datos.presentado ?? null,
    precio: precio ? { valor: precio.valor, moneda: precio.moneda, fecha: precio.fecha ?? null } : null,
    tamano: {
      capitalizacionM: millones(capitalizacion),
      evM: millones(ev),
      cajaM: millones(caja),
      deudaM: millones(deuda),
      deudaNetaM: millones(deudaNeta),
      acciones: acciones,
      accionesFuente: datos.accionesFuente ?? null,
    },
    ttm: {
      ingresosM: millones(t.ingresos ?? null),
      ebitM: millones(ebit),
      beneficioNetoM: millones(t.beneficioNeto ?? null),
      fclM: millones(fcl),
      sbcM: millones(t.sbc ?? null),
      fclAjustadoM: millones(fclAjustado),
      periodo: datos.ttmDetalle?.ingresos?.fin ?? datos.fechaBalance ?? null,
    },
    multiplos,
    calidad,
    solidez,
    crecimiento,
    expectativas,
    valorIntrinseco,
    flujoPropietario: propietario,
    puntuacion: {
      total: redondear(total, 0),
      valor: redondear(valor, 0),
      calidad: redondear(cal, 0),
      solidez: redondear(sol, 0),
      como: 'Absoluta 0-100. Valor 50 %: EBIT/EV, FCL ajustado/capitalización, brecha de crecimiento, margen de seguridad. Calidad 35 %: ROIC, margen bruto, Piotroski, dilución. Solidez 15 %: deuda neta/EBITDA, cobertura de intereses.',
    },
    senal,
    alertas,
  }
}

/** Fila plana para tablas y para el panel. */
export function filaResumen(a) {
  return {
    ticker: a.ticker,
    nombre: a.nombre,
    senal: a.senal,
    puntuacion: a.puntuacion.total,
    notaValor: a.puntuacion.valor,
    notaCalidad: a.puntuacion.calidad,
    notaSolidez: a.puntuacion.solidez,
    precio: a.precio?.valor ?? null,
    moneda: a.precio?.moneda ?? null,
    valorBase: a.valorIntrinseco?.base ?? null,
    valorPesimista: a.valorIntrinseco?.pesimista ?? null,
    valorOptimista: a.valorIntrinseco?.optimista ?? null,
    margenSeguridadPct: a.valorIntrinseco?.margenSeguridadBasePct ?? null,
    margenPropietarioPct: a.flujoPropietario?.margenSeguridadBasePct ?? null,
    crecimientoImplicitoPct: a.expectativas?.crecimientoImplicitoPct ?? null,
    crecimientoHistoricoPct: a.expectativas?.crecimientoSostenibleHistoricoPct ?? null,
    per: a.multiplos.per,
    evEbit: a.multiplos.evEbit,
    rentabilidadFclPct: a.multiplos.rentabilidadFclPct,
    roicPct: a.calidad.roicPct,
    margenBrutoPct: a.calidad.margenBrutoPct,
    piotroski: a.calidad.piotroski ? `${a.calidad.piotroski.puntos}/${a.calidad.piotroski.evaluables}` : null,
    deudaNetaEbitda: a.solidez.deudaNetaEbitda,
    alertas: a.alertas.join(' · '),
    fechaBalance: a.fechaBalance,
  }
}
