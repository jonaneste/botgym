import XCTest
@testable import NucleoEntrenos

final class RevisionSerieTests: XCTestCase {

    // MARK: - Repeticiones

    func testSerieNormalNoTieneSospechas() {
        let serie = SerieValor(peso: 60, repeticiones: 10, rir: 2, completada: true)
        XCTAssertTrue(RevisionSerie.sospechas(de: serie, tipo: .repeticiones).isEmpty)
    }

    func testCientoVeintisieteRepeticionesSeSeñalan() {
        // El dedazo real del primer entreno volcado: 32 kg × 12, escrito 127.
        let serie = SerieValor(peso: 32, repeticiones: 127, completada: true)
        XCTAssertEqual(RevisionSerie.sospechas(de: serie, tipo: .repeticiones), [.repeticiones])
    }

    func testVeinteRepeticionesTodaviaNoSeSeñalan() {
        let serie = SerieValor(peso: 20, repeticiones: 20, completada: true)
        XCTAssertTrue(RevisionSerie.sospechas(de: serie, tipo: .repeticiones).isEmpty)
    }

    func testVeintiunaRepeticionesSeSeñalan() {
        let serie = SerieValor(peso: 20, repeticiones: 21, completada: true)
        XCTAssertEqual(RevisionSerie.sospechas(de: serie, tipo: .repeticiones), [.repeticiones])
    }

    func testSinPesoLasRepeticionesAltasNoSeSeñalan() {
        // Cincuenta fondos a peso corporal son cincuenta fondos.
        let serie = SerieValor(peso: 0, repeticiones: 50, completada: true)
        XCTAssertTrue(RevisionSerie.sospechas(de: serie, tipo: .repeticiones).isEmpty)
    }

    func testEnUnEjercicioDeTiempoNoSeMiranLasRepeticiones() {
        let serie = SerieValor(peso: 10, repeticiones: 99, segundos: 45, completada: true)
        XCTAssertTrue(RevisionSerie.sospechas(de: serie, tipo: .tiempo).isEmpty)
    }

    func testLasRepeticionesPorLadoSeMiranIgual() {
        let serie = SerieValor(peso: 24, repeticiones: 121, completada: true)
        XCTAssertEqual(
            RevisionSerie.sospechas(de: serie, tipo: .repeticionesPorLado),
            [.repeticiones]
        )
    }

    // MARK: - RIR

    func testRirDeSetentaSeSeñala() {
        // El otro dedazo: RIR 7 escrito 70.
        let serie = SerieValor(peso: 4.5, repeticiones: 12, rir: 70, completada: true)
        XCTAssertEqual(RevisionSerie.sospechas(de: serie, tipo: .repeticiones), [.rir])
    }

    func testRirDeDiezTodaviaNoSeSeñala() {
        let serie = SerieValor(peso: 40, repeticiones: 8, rir: 10, completada: true)
        XCTAssertTrue(RevisionSerie.sospechas(de: serie, tipo: .repeticiones).isEmpty)
    }

    func testSinRirNoHaySospecha() {
        let serie = SerieValor(peso: 40, repeticiones: 8, rir: nil, completada: true)
        XCTAssertTrue(RevisionSerie.sospechas(de: serie, tipo: .repeticiones).isEmpty)
    }

    func testRirAltoSeSeñalaTambienEnUnEjercicioDeTiempo() {
        let serie = SerieValor(peso: 0, repeticiones: 0, segundos: 45, rir: 30, completada: true)
        XCTAssertEqual(RevisionSerie.sospechas(de: serie, tipo: .tiempo), [.rir])
    }

    func testDosSospechasLleganEnElOrdenDeLosCampos() {
        let serie = SerieValor(peso: 10, repeticiones: 121, rir: 70, completada: true)
        XCTAssertEqual(
            RevisionSerie.sospechas(de: serie, tipo: .repeticiones),
            [.repeticiones, .rir]
        )
    }

    // MARK: - Series vacías

    func testSerieSinRepeticionesEstaVacia() {
        // Las dos búlgaras del entreno que se abandonó: casilla marcada, 0 × 0.
        let serie = SerieValor(peso: 0, repeticiones: 0, completada: true)
        XCTAssertTrue(RevisionSerie.estaVacia(serie, tipo: .repeticiones))
    }

    func testSerieAPesoCorporalConRepeticionesNoEstaVacia() {
        let serie = SerieValor(peso: 0, repeticiones: 12, completada: true)
        XCTAssertFalse(RevisionSerie.estaVacia(serie, tipo: .repeticiones))
    }

    func testSerieConPesoPeroSinRepeticionesEstaVacia() {
        let serie = SerieValor(peso: 80, repeticiones: 0, completada: true)
        XCTAssertTrue(RevisionSerie.estaVacia(serie, tipo: .repeticiones))
    }

    func testIsometricoSinSegundosEstaVacio() {
        let serie = SerieValor(peso: 0, repeticiones: 0, segundos: nil, completada: true)
        XCTAssertTrue(RevisionSerie.estaVacia(serie, tipo: .tiempo))
    }

    func testIsometricoConSegundosNoEstaVacio() {
        let serie = SerieValor(peso: 0, repeticiones: 0, segundos: 30, completada: true)
        XCTAssertFalse(RevisionSerie.estaVacia(serie, tipo: .tiempo))
    }

    func testEnUnIsometricoLasRepeticionesNoSalvanLaSerie() {
        // El campo que se rellena es el de segundos; las repeticiones de un
        // isométrico son ruido heredado de haber cambiado el tipo de registro.
        let serie = SerieValor(peso: 0, repeticiones: 12, segundos: 0, completada: true)
        XCTAssertTrue(RevisionSerie.estaVacia(serie, tipo: .tiempo))
    }
}
