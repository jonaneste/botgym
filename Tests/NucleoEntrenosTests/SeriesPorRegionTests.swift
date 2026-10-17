import XCTest
@testable import NucleoEntrenos

final class SeriesPorRegionTests: XCTestCase {

    private let calendario = CalendarioEntrenos.es

    private func serie(
        _ grupo: GrupoMuscular,
        diasAtras: Int,
        efectiva: Bool = true
    ) -> SerieConEjercicio {
        let fecha = calendario.date(byAdding: .day, value: -diasAtras, to: Date()) ?? Date()
        return SerieConEjercicio(
            fecha: fecha,
            grupoPrincipal: grupo,
            gruposSecundarios: [],
            peso: 50,
            repeticiones: 10,
            esEfectiva: efectiva
        )
    }

    func testCadaSerieCuentaEnLaRegionDeSuGrupo() {
        let tramos = ServicioVolumen.seriesPorSemanaYRegion(
            [serie(.pecho, diasAtras: 0), serie(.cuadriceps, diasAtras: 0)],
            semanas: 1
        )
        XCTAssertEqual(tramos.count, 2)
        XCTAssertEqual(tramos.first { $0.region == .torso }?.series, 1)
        XCTAssertEqual(tramos.first { $0.region == .pierna }?.series, 1)
    }

    func testLasSeriesDelMismoGrupoSeSuman() {
        let tramos = ServicioVolumen.seriesPorSemanaYRegion(
            [serie(.pecho, diasAtras: 0), serie(.dorsal, diasAtras: 0), serie(.core, diasAtras: 0)],
            semanas: 1
        )
        // Pecho, dorsal y core son los tres torso.
        XCTAssertEqual(tramos.count, 1)
        XCTAssertEqual(tramos[0].series, 3)
    }

    func testLasSeriesNoEfectivasNoCuentan() {
        let tramos = ServicioVolumen.seriesPorSemanaYRegion(
            [serie(.pecho, diasAtras: 0, efectiva: false)],
            semanas: 1
        )
        XCTAssertTrue(tramos.isEmpty)
    }

    func testUnaRegionSinSeriesNoDejaTramoVacio() {
        let tramos = ServicioVolumen.seriesPorSemanaYRegion(
            [serie(.biceps, diasAtras: 0)],
            semanas: 1
        )
        XCTAssertEqual(tramos.map(\.region), [.brazo])
    }

    func testLosTramosSalenEnElOrdenDelEnum() {
        // Si el orden bailara de una semana a otra, los tramos de la barra se
        // apilarían distintos cada semana y la gráfica parecería saltar.
        let tramos = ServicioVolumen.seriesPorSemanaYRegion(
            [
                serie(.biceps, diasAtras: 0),
                serie(.cuadriceps, diasAtras: 0),
                serie(.pecho, diasAtras: 0),
                serie(.hombroLateral, diasAtras: 0),
            ],
            semanas: 1
        )
        XCTAssertEqual(tramos.map(\.region), [.torso, .hombro, .brazo, .pierna])
    }

    func testLoSinClasificarTieneSuPropioTramo() {
        // No suma en el recuento por grupo, pero la serie se hizo: esconderla
        // aquí dejaría la barra más baja que el total que se enseña al lado.
        let tramos = ServicioVolumen.seriesPorSemanaYRegion(
            [serie(.sinClasificar, diasAtras: 0)],
            semanas: 1
        )
        XCTAssertEqual(tramos.map(\.region), [.sinClasificar])
        XCTAssertEqual(tramos[0].series, 1)
    }

    func testLosTramosDeUnaSemanaSumanElTotalDeLaBarra() {
        let series = [
            serie(.pecho, diasAtras: 0),
            serie(.triceps, diasAtras: 0),
            serie(.cuadriceps, diasAtras: 0),
            serie(.sinClasificar, diasAtras: 0),
        ]
        let tramos = ServicioVolumen.seriesPorSemanaYRegion(series, semanas: 1)
        let porSemana = ServicioVolumen.seriesPorSemana(series, semanas: 1)
        XCTAssertEqual(
            Double(tramos.reduce(0) { $0 + $1.series }),
            porSemana.last?.series,
            "la suma de los tramos tiene que cuadrar con la altura de la barra"
        )
    }

    func testCadaTramoTieneIdentidadPropia() {
        // La fecha no vale como identidad: hay una fila por región y semana, y
        // con solo la fecha el Chart hacía desaparecer tramos en silencio.
        let tramos = ServicioVolumen.seriesPorSemanaYRegion(
            [serie(.pecho, diasAtras: 0), serie(.cuadriceps, diasAtras: 0)],
            semanas: 1
        )
        XCTAssertEqual(Set(tramos.map(\.id)).count, tramos.count)
    }
}

// MARK: - Agrupar la lista semanal por región

extension SeriesPorRegionTests {

    private func grupoDe(_ grupo: GrupoMuscular, series: Double, objetivo: Int?) -> SeriesDeGrupo {
        SeriesDeGrupo(grupo: grupo, series: series, objetivo: objetivo)
    }

    func testLosGruposSeAgrupanPorRegionEnSuOrden() {
        let bloques = ServicioVolumen.porRegion([
            grupoDe(.pecho, series: 3, objetivo: 16),
            grupoDe(.dorsal, series: 0, objetivo: 11),
            grupoDe(.biceps, series: 2, objetivo: 20),
            grupoDe(.cuadriceps, series: 0, objetivo: 7),
        ])

        XCTAssertEqual(bloques.map(\.region), [.torso, .brazo, .pierna])
        XCTAssertEqual(bloques[0].grupos.map(\.grupo), [.pecho, .dorsal])
    }

    func testElTotalDeLaRegionSumaSusGrupos() {
        let torso = SeriesDeRegion(region: .torso, grupos: [
            grupoDe(.pecho, series: 3, objetivo: 16),
            grupoDe(.dorsal, series: 1.5, objetivo: 11),
        ])
        XCTAssertEqual(torso.series, 4.5)
        XCTAssertEqual(torso.objetivo, 27)
    }

    /// Un grupo sin objetivo no cuenta como un cero en el de la región: si
    /// contara, una región entera saldría «cumplida» por grupos que nadie se
    /// propuso.
    func testElObjetivoDeLaRegionSoloSumaLosGruposQueLoTienen() {
        let brazo = SeriesDeRegion(region: .brazo, grupos: [
            grupoDe(.biceps, series: 4, objetivo: 20),
            grupoDe(.antebrazo, series: 0, objetivo: nil),
        ])
        XCTAssertEqual(brazo.objetivo, 20)

        let sinNinguno = SeriesDeRegion(region: .brazo, grupos: [
            grupoDe(.antebrazo, series: 1, objetivo: nil),
        ])
        XCTAssertNil(sinNinguno.objetivo)
    }

    func testUnaListaVaciaNoDaBloques() {
        XCTAssertTrue(ServicioVolumen.porRegion([]).isEmpty)
    }
}
