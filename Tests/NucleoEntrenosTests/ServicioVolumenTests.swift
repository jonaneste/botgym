import XCTest
@testable import NucleoEntrenos

final class ServicioVolumenTests: XCTestCase {

    private let calendario = CalendarioEntrenos.es

    /// 5 de octubre de 2026 es lunes.
    private func fecha(_ dia: Int, _ mes: Int = 10, _ año: Int = 2026) -> Date {
        var componentes = DateComponents()
        componentes.year = año
        componentes.month = mes
        componentes.day = dia
        componentes.hour = 18
        return calendario.date(from: componentes)!
    }

    private func serie(
        _ fecha: Date,
        _ principal: GrupoMuscular,
        _ secundarios: [GrupoMuscular] = [],
        peso: Double = 60,
        reps: Int = 10,
        efectiva: Bool = true
    ) -> SerieConEjercicio {
        SerieConEjercicio(
            fecha: fecha,
            grupoPrincipal: principal,
            gruposSecundarios: secundarios,
            peso: peso,
            repeticiones: reps,
            esEfectiva: efectiva
        )
    }

    // MARK: - Volumen

    func testVolumenSumaPesoPorReps() {
        let series = [
            SerieValor(peso: 60, repeticiones: 10, completada: true),
            SerieValor(peso: 62.5, repeticiones: 8, completada: true),
        ]
        XCTAssertEqual(ServicioVolumen.volumen(de: series), 600 + 500, accuracy: 0.0001)
    }

    func testElVolumenIgnoraLoQueNoEsEfectivo() {
        let series = [
            SerieValor(peso: 60, repeticiones: 10, completada: true),
            SerieValor(peso: 100, repeticiones: 10, completada: false),
            SerieValor(peso: 40, repeticiones: 20, completada: true, esCalentamiento: true),
        ]
        XCTAssertEqual(ServicioVolumen.volumen(de: series), 600, accuracy: 0.0001)
    }

    // MARK: - Series por grupo

    func testElGrupoPrincipalSumaUnaSerieEntera() throws {
        let series = [serie(fecha(5), .pecho), serie(fecha(5), .pecho)]
        let cuenta = ServicioVolumen.seriesPorGrupo(series)
        XCTAssertEqual(try XCTUnwrap(cuenta[.pecho]), 2, accuracy: 0.0001)
    }

    func testLosSecundariosSumanMediaSerie() throws {
        // Press banca: pecho principal, hombro anterior y tríceps secundarios.
        let series = [serie(fecha(5), .pecho, [.hombroAnterior, .triceps])]
        let cuenta = ServicioVolumen.seriesPorGrupo(series)
        XCTAssertEqual(try XCTUnwrap(cuenta[.pecho]), 1, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(cuenta[.hombroAnterior]), 0.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(cuenta[.triceps]), 0.5, accuracy: 0.0001)
    }

    func testUnGrupoRepetidoComoSecundarioNoSeCuentaDosVeces() throws {
        // Si alguien pone el mismo grupo dos veces en los secundarios, cuenta
        // una sola media serie.
        let series = [serie(fecha(5), .pecho, [.triceps, .triceps])]
        let cuenta = ServicioVolumen.seriesPorGrupo(series)
        XCTAssertEqual(try XCTUnwrap(cuenta[.triceps]), 0.5, accuracy: 0.0001)
    }

    func testElPrincipalNoSeSumaOtraVezComoSecundario() throws {
        let series = [serie(fecha(5), .pecho, [.pecho, .triceps])]
        let cuenta = ServicioVolumen.seriesPorGrupo(series)
        XCTAssertEqual(try XCTUnwrap(cuenta[.pecho]), 1, accuracy: 0.0001)
    }

    func testLasSeriesNoEfectivasNoCuentan() {
        let series = [serie(fecha(5), .pecho, efectiva: false)]
        XCTAssertTrue(ServicioVolumen.seriesPorGrupo(series).isEmpty)
    }

    func testLaSumaDeUnaSesionRealDeEmpuje() throws {
        // Lunes: 4 press banca + 3 press inclinado, ambos pecho con tríceps.
        var series: [SerieConEjercicio] = []
        for _ in 0..<4 { series.append(serie(fecha(5), .pecho, [.hombroAnterior, .triceps])) }
        for _ in 0..<3 { series.append(serie(fecha(5), .pecho, [.hombroAnterior, .triceps])) }
        // 4 elevaciones laterales, hombro lateral sin secundarios.
        for _ in 0..<4 { series.append(serie(fecha(5), .hombroLateral)) }

        let cuenta = ServicioVolumen.seriesPorGrupo(series)
        XCTAssertEqual(try XCTUnwrap(cuenta[.pecho]), 7, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(cuenta[.triceps]), 3.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(cuenta[.hombroAnterior]), 3.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(cuenta[.hombroLateral]), 4, accuracy: 0.0001)
    }

    // MARK: - Semanas

    func testSoloCuentaLasSeriesDeLaSemanaPedida() throws {
        let series = [
            serie(fecha(5), .pecho),    // lunes 5, semana en curso
            serie(fecha(11), .pecho),   // domingo 11, misma semana
            serie(fecha(12), .pecho),   // lunes 12, semana siguiente
            serie(fecha(4), .pecho),    // domingo 4, semana anterior
        ]
        let resultado = ServicioVolumen.seriesSemanales(series, semanaDe: fecha(7), calendario: calendario)
        let pecho = try XCTUnwrap(resultado.first { $0.grupo == .pecho })
        XCTAssertEqual(pecho.series, 2, accuracy: 0.0001)
    }

    func testLaSemanaEmpiezaEnLunes() {
        // El domingo 11 y el lunes 5 están en la misma semana; el lunes 12 no.
        XCTAssertTrue(CalendarioEntrenos.mismaSemana(fecha(5), fecha(11), calendario: calendario))
        XCTAssertFalse(CalendarioEntrenos.mismaSemana(fecha(11), fecha(12), calendario: calendario))
    }

    func testSeIncluyenLosGruposConObjetivoAunqueNoSeEntrenaran() throws {
        let resultado = ServicioVolumen.seriesSemanales(
            [],
            semanaDe: fecha(7),
            objetivos: [.pecho: 12],
            calendario: calendario
        )
        let pecho = try XCTUnwrap(resultado.first { $0.grupo == .pecho })
        XCTAssertEqual(pecho.series, 0, accuracy: 0.0001)
        XCTAssertEqual(pecho.objetivo, 12)
        XCTAssertFalse(pecho.cumplido)
        XCTAssertEqual(pecho.faltan, 12)
    }

    func testLosGruposSinSeriesNiObjetivoNoAparecen() {
        let series = [serie(fecha(5), .pecho)]
        let resultado = ServicioVolumen.seriesSemanales(series, semanaDe: fecha(7), calendario: calendario)
        XCTAssertFalse(resultado.contains { $0.grupo == .gemelo })
    }

    func testElOrdenDeLosGruposEsEstable() {
        let series = [
            serie(fecha(5), .gemelo),
            serie(fecha(5), .pecho),
            serie(fecha(5), .biceps),
        ]
        let primera = ServicioVolumen.seriesSemanales(series, semanaDe: fecha(7), calendario: calendario)
        let segunda = ServicioVolumen.seriesSemanales(series.reversed(), semanaDe: fecha(7), calendario: calendario)
        XCTAssertEqual(primera.map(\.grupo), segunda.map(\.grupo))
        // Y sigue el orden de declaración del enum, no el de llegada.
        XCTAssertEqual(primera.map(\.grupo), [.pecho, .biceps, .gemelo])
    }

    // MARK: - Progreso frente al objetivo

    func testProgresoYCumplimiento() throws {
        let aMedias = SeriesDeGrupo(grupo: .pecho, series: 6, objetivo: 12)
        XCTAssertEqual(try XCTUnwrap(aMedias.progreso), 0.5, accuracy: 0.0001)
        XCTAssertFalse(aMedias.cumplido)
        XCTAssertEqual(aMedias.faltan, 6)

        let justo = SeriesDeGrupo(grupo: .pecho, series: 12, objetivo: 12)
        XCTAssertTrue(justo.cumplido)
        XCTAssertEqual(justo.faltan, 0)

        let pasado = SeriesDeGrupo(grupo: .pecho, series: 15, objetivo: 12)
        XCTAssertTrue(pasado.cumplido)
        XCTAssertEqual(try XCTUnwrap(pasado.progreso), 1, accuracy: 0.0001, "el progreso se corta en 1")
        XCTAssertEqual(pasado.faltan, 0)
    }

    func testSinObjetivoNoHayProgreso() {
        let sinObjetivo = SeriesDeGrupo(grupo: .pecho, series: 6, objetivo: nil)
        XCTAssertNil(sinObjetivo.progreso)
        XCTAssertNil(sinObjetivo.faltan)
        XCTAssertFalse(sinObjetivo.cumplido)
    }

    func testLasMediasSeriesRedondeanHaciaArribaAlFaltar() {
        // 10,5 de 12: faltan 1,5, que se presentan como 2.
        let grupo = SeriesDeGrupo(grupo: .triceps, series: 10.5, objetivo: 12)
        XCTAssertEqual(grupo.faltan, 2)
    }

    // MARK: - Tendencia por semanas

    func testLaTendenciaDevuelveUnaEntradaPorSemanaIncluidasLasVacias() {
        let series = [serie(fecha(5), .pecho), serie(fecha(5), .pecho)]
        let tendencia = ServicioVolumen.seriesPorSemana(
            series, semanas: 4, hasta: fecha(7), calendario: calendario
        )
        XCTAssertEqual(tendencia.count, 4)
        // Las tres primeras semanas están vacías; la última tiene 2 series.
        XCTAssertEqual(tendencia.map(\.series), [0, 0, 0, 2])
    }

    func testLaTendenciaVaDeMasAntiguaAMasReciente() {
        let tendencia = ServicioVolumen.seriesPorSemana(
            [], semanas: 3, hasta: fecha(7), calendario: calendario
        )
        XCTAssertEqual(tendencia.map(\.inicioSemana), tendencia.map(\.inicioSemana).sorted())
    }

    func testLaTendenciaPuedeFiltrarPorGrupo() {
        let series = [
            serie(fecha(5), .pecho, [.triceps]),
            serie(fecha(5), .hombroLateral),
        ]
        let soloTriceps = ServicioVolumen.seriesPorSemana(
            series, semanas: 1, hasta: fecha(7), grupo: .triceps, calendario: calendario
        )
        XCTAssertEqual(soloTriceps.map(\.series), [0.5])
    }

    func testCeroSemanasDevuelveListaVacia() {
        XCTAssertTrue(ServicioVolumen.seriesPorSemana([], semanas: 0, hasta: fecha(7), calendario: calendario).isEmpty)
    }

    // MARK: - Calendario

    func testUltimasSemanasDevuelveLunes() throws {
        let semanas = CalendarioEntrenos.ultimasSemanas(3, hasta: fecha(7), calendario: calendario)
        XCTAssertEqual(semanas.count, 3)
        for lunes in semanas {
            // 2 es lunes con firstWeekday = 2.
            XCTAssertEqual(calendario.component(.weekday, from: lunes), 2)
        }
    }

    func testInicioDeSemanaDeUnLunesEsEseMismoLunes() {
        let lunes = CalendarioEntrenos.inicioDeSemana(de: fecha(5), calendario: calendario)
        XCTAssertEqual(calendario.component(.day, from: lunes), 5)
    }

    func testInicioDeSemanaDeUnDomingoEsElLunesAnterior() {
        let lunes = CalendarioEntrenos.inicioDeSemana(de: fecha(11), calendario: calendario)
        XCTAssertEqual(calendario.component(.day, from: lunes), 5)
    }
}
