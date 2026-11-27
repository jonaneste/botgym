/**
 * Convierte el `companyfacts` de la SEC en las cifras que necesita una
 * valoración: últimos doce meses (TTM), balance más reciente y series anuales.
 *
 * Funciones puras: entra el JSON tal cual lo sirve data.sec.gov y sale un
 * objeto `datos` con el mismo formato que un archivo manual de
 * `datos/fundamentales/`, así el análisis no sabe de dónde vienen las cifras.
 */

const DIA = 86400000

// Cada cifra admite varias etiquetas porque las empresas cambian de etiqueta
// con los años o usan otra para lo mismo: NVIDIA dejó de usar
// PaymentsToAcquirePropertyPlantAndEquipment en 2020 y Zoetis no publica
// OperatingIncomeLoss. El orden es la preferencia cuando dos están al día.
export const CONCEPTOS_FLUJO = {
  ingresos: [
    'RevenueFromContractWithCustomerExcludingAssessedTax',
    'Revenues',
    'SalesRevenueNet',
    'RevenueFromContractWithCustomerIncludingAssessedTax',
  ],
  costeVentas: ['CostOfRevenue', 'CostOfGoodsAndServicesSold', 'CostOfGoodsSold'],
  beneficioBruto: ['GrossProfit'],
  ebit: ['OperatingIncomeLoss'],
  preImpuestos: [
    'IncomeLossFromContinuingOperationsBeforeIncomeTaxesExtraordinaryItemsNoncontrollingInterest',
    'IncomeLossFromContinuingOperationsBeforeIncomeTaxesMinorityInterestAndIncomeLossFromEquityMethodInvestments',
  ],
  impuestos: ['IncomeTaxExpenseBenefit'],
  intereses: ['InterestExpense', 'InterestExpenseNonoperating', 'InterestExpenseDebt'],
  beneficioNeto: ['NetIncomeLoss', 'ProfitLoss'],
  fco: [
    'NetCashProvidedByUsedInOperatingActivities',
    'NetCashProvidedByUsedInOperatingActivitiesContinuingOperations',
  ],
  capex: [
    'PaymentsToAcquirePropertyPlantAndEquipment',
    'PaymentsToAcquireProductiveAssets',
    'PaymentsToAcquireOtherPropertyPlantAndEquipment',
  ],
  sbc: ['ShareBasedCompensation', 'AllocatedShareBasedCompensationExpense'],
  amortizacion: [
    'DepreciationDepletionAndAmortization',
    'DepreciationAmortizationAndAccretionNet',
    'DepreciationAndAmortization',
  ],
  recompras: ['PaymentsForRepurchaseOfCommonStock'],
  dividendos: ['PaymentsOfDividends', 'PaymentsOfDividendsCommonStock'],
}

export const CONCEPTOS_BALANCE = {
  activos: ['Assets'],
  activoCorriente: ['AssetsCurrent'],
  pasivoCorriente: ['LiabilitiesCurrent'],
  patrimonio: [
    'StockholdersEquity',
    'StockholdersEquityIncludingPortionAttributableToNoncontrollingInterest',
  ],
  caja: [
    'CashAndCashEquivalentsAtCarryingValue',
    'CashCashEquivalentsRestrictedCashAndRestrictedCashEquivalents',
  ],
  inversionesCP: [
    'MarketableSecuritiesCurrent',
    'ShortTermInvestments',
    'AvailableForSaleSecuritiesDebtSecuritiesCurrent',
    'DebtSecuritiesCurrent',
  ],
  deudaLP: ['LongTermDebt'],
  deudaLPNoCorriente: ['LongTermDebtNoncurrent', 'LongTermDebtAndCapitalLeaseObligations'],
  deudaLPCorriente: ['LongTermDebtCurrent', 'LongTermDebtAndCapitalLeaseObligationsCurrent'],
  deudaCorriente: ['DebtCurrent'],
  papelComercial: ['CommercialPaper'],
  prestamosCP: ['ShortTermBorrowings'],
}

function dias(inicio, fin) {
  return Math.round((Date.parse(fin) - Date.parse(inicio)) / DIA) + 1
}

function esAnual(h) {
  return h.dias >= 350 && h.dias <= 380
}

/**
 * Hechos de un concepto, sin duplicados. El mismo periodo reaparece en cada
 * 10-Q o 10-K posterior que lo compara; manda la presentación más reciente,
 * que es la que recoge las reexpresiones.
 */
export function hechos(cf, concepto, taxonomia = 'us-gaap') {
  const nodo = cf?.facts?.[taxonomia]?.[concepto]
  if (!nodo) return []
  // Moneda de informe: la primera unidad que no sea por acción ni acciones.
  const unidades = Object.keys(nodo.units)
  const unidad =
    unidades.find((u) => /^[A-Z]{3}$/.test(u)) ||
    unidades.find((u) => u === 'shares') ||
    unidades.find((u) => u.includes('/shares')) ||
    unidades[0]
  const porPeriodo = new Map()
  for (const v of nodo.units[unidad]) {
    if (typeof v.val !== 'number' || !Number.isFinite(v.val)) continue
    // Solo informes periódicos: un 8-K o un S-1 trae cifras sueltas y a veces
    // proforma que no casan con la serie.
    if (v.form && !/^(10-K|10-Q|10-KT|10-QT|20-F|40-F)(\/A)?$/.test(v.form)) continue
    const clave = `${v.start || ''}|${v.end}`
    const previo = porPeriodo.get(clave)
    if (!previo || (v.filed || '') >= (previo.presentado || '')) {
      porPeriodo.set(clave, {
        inicio: v.start || null,
        fin: v.end,
        valor: v.val,
        form: v.form,
        presentado: v.filed || null,
        dias: v.start ? dias(v.start, v.end) : 0,
        unidad,
      })
    }
  }
  return [...porPeriodo.values()].sort((a, b) => a.fin.localeCompare(b.fin) || a.dias - b.dias)
}

function ultimoFin(lista) {
  return lista.reduce((m, h) => (h.fin > m ? h.fin : m), '')
}

/** De varias etiquetas alternativas, la que tiene el dato más reciente. */
export function elegirConcepto(cf, conceptos, { soloFlujos = false } = {}) {
  let mejor = null
  for (const concepto of conceptos) {
    const lista = hechos(cf, concepto).filter((h) => (soloFlujos ? h.inicio : !h.inicio))
    if (!lista.length) continue
    const fin = ultimoFin(lista)
    if (!mejor || fin > mejor.fin) mejor = { concepto, lista, fin }
  }
  return mejor
}

function cercanas(a, b, toleranciaDias) {
  return Math.abs(Date.parse(a) - Date.parse(b)) <= toleranciaDias * DIA
}

/**
 * Últimos doce meses de una cifra de flujo.
 *
 * Los 10-Q no traen el cuarto trimestre: va dentro del anual del 10-K. Por eso
 * se calcula como «último anual + acumulado del año en curso − acumulado del
 * mismo periodo del año anterior», que es como lo hacen los analistas y no
 * necesita trimestres sueltos.
 */
export function ttm(lista) {
  const flujos = lista.filter((h) => h.inicio)
  if (!flujos.length) return null
  const fin = ultimoFin(flujos)
  const acabanAhi = flujos.filter((h) => h.fin === fin && h.dias <= 380)
  if (!acabanAhi.length) return null
  const acumulado = acabanAhi.reduce((m, h) => (h.dias > m.dias ? h : m))
  if (esAnual(acumulado)) {
    return { valor: acumulado.valor, fin, metodo: 'anual', presentado: acumulado.presentado }
  }

  const anual = flujos
    .filter((h) => esAnual(h) && h.fin < acumulado.inicio && cercanas(h.fin, acumulado.inicio, 10))
    .pop()
  const finPrevio = new Date(Date.parse(fin) - 364 * DIA).toISOString().slice(0, 10)
  const previo = flujos.find(
    (h) => Math.abs(h.dias - acumulado.dias) <= 10 && cercanas(h.fin, finPrevio, 12)
  )
  if (anual && previo) {
    return {
      valor: anual.valor + acumulado.valor - previo.valor,
      fin,
      metodo: 'anual + acumulado − acumulado previo',
      presentado: acumulado.presentado,
    }
  }

  // Sin acumulado comparable (una empresa recién salida a bolsa, por
  // ejemplo), lo honrado es quedarse con el último anual y decir de cuándo es.
  const ultimoAnual = flujos.filter(esAnual).pop()
  if (ultimoAnual) {
    return {
      valor: ultimoAnual.valor,
      fin: ultimoAnual.fin,
      metodo: 'último anual (sin acumulado comparable)',
      presentado: ultimoAnual.presentado,
    }
  }
  return null
}

/** Serie anual (un valor por ejercicio), combinando etiquetas si cambiaron. */
export function serieAnual(cf, conceptos) {
  const porFin = new Map()
  const elegido = elegirConcepto(cf, conceptos, { soloFlujos: true })
  const orden = elegido ? [elegido.concepto, ...conceptos.filter((c) => c !== elegido.concepto)] : conceptos
  for (const concepto of orden) {
    for (const h of hechos(cf, concepto)) {
      if (!h.inicio || !esAnual(h)) continue
      const yaHay = [...porFin.keys()].some((f) => cercanas(f, h.fin, 7))
      if (!yaHay) porFin.set(h.fin, h.valor)
    }
  }
  return [...porFin.entries()].sort((a, b) => a[0].localeCompare(b[0])).map(([fin, valor]) => ({ fin, valor }))
}

/** Valor de balance en una fecha, probando las etiquetas en orden. */
export function balanceEn(cf, conceptos, fecha) {
  for (const concepto of conceptos) {
    const h = hechos(cf, concepto).find((x) => !x.inicio && x.fin === fecha)
    if (h) return { valor: h.valor, concepto }
  }
  return null
}

/**
 * Deuda financiera total en la fecha del balance.
 *
 * Las empresas no etiquetan igual: en NVIDIA `LongTermDebt` incluye la parte
 * corriente y en Adobe no. Si hay no corriente explícita se suma la corriente;
 * si solo hay `LongTermDebt`, se le suma la corriente igualmente. En el
 * segundo caso puede contar dos veces la parte corriente, y se acepta: es
 * preferible sobrestimar deuda que esconderla en una valoración.
 */
export function deudaEn(cf, fecha) {
  const v = (clave) => balanceEn(cf, CONCEPTOS_BALANCE[clave], fecha)?.valor ?? null
  const noCorriente = v('deudaLPNoCorriente')
  const lp = v('deudaLP')
  const lpCorriente = v('deudaLPCorriente')
  const corrienteTotal = v('deudaCorriente')
  const papel = v('papelComercial') ?? 0
  const prestamos = v('prestamosCP') ?? 0

  // DebtCurrent ya incluye papel comercial y préstamos a corto.
  const corriente = lpCorriente !== null ? lpCorriente + papel + prestamos : corrienteTotal ?? papel + prestamos

  let total
  let criterio
  if (noCorriente !== null) {
    total = noCorriente + corriente
    criterio = 'no corriente + corriente'
  } else if (lp !== null) {
    total = lp + corriente
    criterio = 'LongTermDebt + corriente (conservador)'
  } else {
    total = corriente
    criterio = 'solo deuda corriente'
  }
  return { total, criterio, noCorriente, lp, corriente }
}

function alinear(serie, fines) {
  return fines.map((f) => serie.find((x) => cercanas(x.fin, f, 7))?.valor ?? null)
}

const RATIOS_SPLIT = [2, 3, 4, 5, 6, 8, 10, 15, 20, 25, 30, 40, 50]

/**
 * Deshace los splits en una serie de número de acciones.
 *
 * La SEC guarda cada ejercicio tal como se presentó por última vez: los dos o
 * tres últimos vienen reexpresados tras un split y los anteriores no. Sin
 * esto, el 10 por 1 de KLA parecía una emisión del 900 % y hundía la nota.
 */
export function ajustarSplits(serie) {
  const ajustada = serie.slice()
  for (let i = ajustada.length - 1; i > 0; i--) {
    const actual = ajustada[i]
    let j = i - 1
    while (j >= 0 && ajustada[j] === null) j--
    if (actual === null || j < 0) continue
    const ratio = actual / ajustada[j]
    const directo = RATIOS_SPLIT.find((r) => Math.abs(ratio / r - 1) < 0.12)
    const inverso = RATIOS_SPLIT.find((r) => Math.abs(ratio * r - 1) < 0.12)
    const factor = directo ?? (inverso ? 1 / inverso : null)
    if (!factor) continue
    for (let k = 0; k <= j; k++) if (ajustada[k] !== null) ajustada[k] *= factor
  }
  return ajustada
}

/** El objeto `datos` normalizado a partir de companyfacts. */
export function extraerDatosSEC(cf, { ticker } = {}) {
  const activos = elegirConcepto(cf, CONCEPTOS_BALANCE.activos)
  if (!activos) throw new Error(`La SEC no tiene balance etiquetado para ${ticker || cf?.entityName}`)
  const fechaBalance = activos.fin

  const ttmValores = {}
  const ttmDetalle = {}
  let moneda = null
  for (const [clave, conceptos] of Object.entries(CONCEPTOS_FLUJO)) {
    const elegido = elegirConcepto(cf, conceptos, { soloFlujos: true })
    if (!elegido) continue
    const r = ttm(elegido.lista)
    if (!r) continue
    // Una etiqueta abandonada hace años sigue siendo «la más reciente» si es
    // la única: KLA dejó OperatingIncomeLoss en 2015 y su EBIT salía de
    // entonces. Mejor sin dato que con uno de otra época.
    if (Date.parse(fechaBalance) - Date.parse(r.fin) > 200 * DIA) continue
    moneda = moneda || elegido.lista[0].unidad
    ttmValores[clave] = r.valor
    ttmDetalle[clave] = { concepto: elegido.concepto, fin: r.fin, metodo: r.metodo }
  }

  const balance = {}
  for (const clave of ['activos', 'activoCorriente', 'pasivoCorriente', 'patrimonio', 'caja', 'inversionesCP']) {
    balance[clave] = balanceEn(cf, CONCEPTOS_BALANCE[clave], fechaBalance)?.valor ?? null
  }
  const deuda = deudaEn(cf, fechaBalance)
  balance.deuda = deuda.total
  balance.deudaCriterio = deuda.criterio

  // Acciones: la portada del último informe (dei). En empresas con varias
  // clases la SEC no la sirve sin dimensión, o sirve solo una clase; ahí la
  // media diluida del último trimestre es mejor aproximación.
  // Comcast dejó de servirla sin dimensión en 2009: una portada de hace años
  // no vale aunque sea la última.
  const dei = hechos(cf, 'EntityCommonStockSharesOutstanding', 'dei').filter(
    (h) => !h.inicio && Date.parse(fechaBalance) - Date.parse(h.fin) < 200 * DIA
  )
  const portada = dei.length ? dei[dei.length - 1] : null
  const diluidas = hechos(cf, 'WeightedAverageNumberOfDilutedSharesOutstanding').filter((h) => h.inicio)
  const ultimaDiluida = diluidas.length ? diluidas[diluidas.length - 1] : null
  let acciones = portada?.valor ?? null
  let accionesFuente = portada ? `portada del informe (${portada.fin})` : null
  let accionesFecha = portada?.fin ?? null
  if (ultimaDiluida && (!acciones || acciones < 0.5 * ultimaDiluida.valor)) {
    acciones = ultimaDiluida.valor
    accionesFuente = `media diluida (${ultimaDiluida.fin})`
    accionesFecha = ultimaDiluida.fin
  }

  const ingresosAnual = serieAnual(cf, CONCEPTOS_FLUJO.ingresos)
  const base = ingresosAnual.length ? ingresosAnual : serieAnual(cf, CONCEPTOS_FLUJO.beneficioNeto)
  const fines = base.slice(-11).map((x) => x.fin)
  const anual = { fines }
  for (const clave of ['ingresos', 'beneficioNeto', 'fco', 'capex', 'ebit', 'beneficioBruto', 'costeVentas', 'sbc']) {
    anual[clave] = alinear(serieAnual(cf, CONCEPTOS_FLUJO[clave]), fines)
  }
  anual.accionesDiluidas = ajustarSplits(alinear(serieAnual(cf, ['WeightedAverageNumberOfDilutedSharesOutstanding']), fines))
  for (const clave of ['activos', 'activoCorriente', 'pasivoCorriente', 'patrimonio']) {
    anual[clave] = fines.map((f) => balanceEn(cf, CONCEPTOS_BALANCE[clave], f)?.valor ?? null)
  }
  anual.deuda = fines.map((f) => {
    const d = deudaEn(cf, f)
    return d.noCorriente === null && d.lp === null && d.corriente === 0 ? null : d.total
  })

  const presentado = activos.lista.filter((h) => h.fin === fechaBalance).pop()?.presentado ?? null

  return {
    nombre: cf.entityName,
    ticker: ticker || null,
    moneda: moneda || 'USD',
    fuente: 'SEC EDGAR (companyfacts)',
    fechaBalance,
    presentado,
    ttm: ttmValores,
    ttmDetalle,
    balance,
    acciones,
    accionesFuente,
    accionesFecha,
    anual,
  }
}
