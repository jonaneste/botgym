import XCTest
@testable import NucleoEntrenos

final class ComparacionSesionTests: XCTestCase {

    private let ayer = Date().addingTimeInterval(-86_400)

    func testMasVolumenEsMejora() throws {
        let c = try XCTUnwrap(
            ComparadorSesiones.comparar(
                seriesAhora: 20,
                volumenAhora: 12_000,
                anterior: (fecha: ayer, series: 20, volumen: 11_000)
            )
        )
        XCTAssertEqual(c.diferenciaVolumen, 1_000)
        XCTAssertEqual(c.diferenciaSeries, 0)
        XCTAssertTrue(c.esMejora)
        XCTAssertFalse(c.esIgual)
    }

    func testMenosVolumenNoEsMejora() throws {
        let c = try XCTUnwrap(
            ComparadorSesiones.comparar(
                seriesAhora: 18,
                volumenAhora: 9_000,
                anterior: (fecha: ayer, series: 20, volumen: 11_000)
            )
        )
        XCTAssertEqual(c.diferenciaSeries, -2)
        XCTAssertFalse(c.esMejora)
    }

    func testMismasSeriesYMismoVolumenEsIgual() throws {
        // Pasa de verdad: mismo peso y mismas repeticiones.
        let c = try XCTUnwrap(
            ComparadorSesiones.comparar(
                seriesAhora: 20,
                volumenAhora: 11_000,
                anterior: (fecha: ayer, series: 20, volumen: 11_000)
            )
        )
        XCTAssertTrue(c.esIgual)
        XCTAssertFalse(c.esMejora)
    }

    func testUnaSerieMasConElMismoVolumenCuentaComoMejora() throws {
        let c = try XCTUnwrap(
            ComparadorSesiones.comparar(
                seriesAhora: 21,
                volumenAhora: 11_000,
                anterior: (fecha: ayer, series: 20, volumen: 11_000)
            )
        )
        XCTAssertTrue(c.esMejora)
    }

    func testSinSesionAnteriorNoHayComparacion() {
        XCTAssertNil(
            ComparadorSesiones.comparar(seriesAhora: 20, volumenAhora: 12_000, anterior: nil)
        )
    }

    func testUnaSesionAnteriorSinSeriesNoSirveParaComparar() {
        XCTAssertNil(
            ComparadorSesiones.comparar(
                seriesAhora: 20,
                volumenAhora: 12_000,
                anterior: (fecha: ayer, series: 0, volumen: 0)
            )
        )
    }

    func testElPorcentajeDeVolumen() throws {
        let c = try XCTUnwrap(
            ComparadorSesiones.comparar(
                seriesAhora: 20,
                volumenAhora: 11_000,
                anterior: (fecha: ayer, series: 20, volumen: 10_000)
            )
        )
        XCTAssertEqual(try XCTUnwrap(c.porcentajeVolumen), 10, accuracy: 0.001)
    }

    func testSinVolumenAnteriorNoHayPorcentaje() throws {
        // Una sesión a peso corporal da volumen 0: dividir por él sería
        // infinito, y de un infinito a un `Int` la app se cierra.
        let c = try XCTUnwrap(
            ComparadorSesiones.comparar(
                seriesAhora: 12,
                volumenAhora: 0,
                anterior: (fecha: ayer, series: 12, volumen: 0)
            )
        )
        XCTAssertNil(c.porcentajeVolumen)
        XCTAssertTrue(c.esIgual)
    }

    func testUnVolumenNoFinitoNoSeCompara() {
        // Un peso imposible guardado en una serie vieja no puede tumbar la
        // pantalla de cierre del entreno de hoy.
        XCTAssertNil(
            ComparadorSesiones.comparar(
                seriesAhora: 20,
                volumenAhora: .infinity,
                anterior: (fecha: ayer, series: 20, volumen: 10_000)
            )
        )
        XCTAssertNil(
            ComparadorSesiones.comparar(
                seriesAhora: 20,
                volumenAhora: 10_000,
                anterior: (fecha: ayer, series: 20, volumen: .nan)
            )
        )
    }
}
