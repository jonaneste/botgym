import XCTest
@testable import NucleoEntrenos

final class CarrerasManualesTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_792_000_000)

    private func carrera(
        _ id: String,
        minutosDespues: Double = 0,
        km: Double = 10
    ) -> Carrera {
        Carrera(
            id: id,
            fechaInicio: base.addingTimeInterval(minutosDespues * 60),
            duracion: 3_000,
            distanciaMetros: km * 1_000
        )
    }

    // MARK: - Quién gana

    func testLaDeSaludGanaALaEscritaAMano() {
        // Mismo segundo: se fusionan por instante, y la medida manda.
        let fusionada = FusionCarreras.fusionar(
            [carrera("manual-1", km: 8)],
            con: [carrera("UUID-REAL", km: 8.4)]
        )
        XCTAssertEqual(fusionada.count, 1)
        XCTAssertEqual(fusionada[0].id, "UUID-REAL")
    }

    func testLaDelArchivoTambienGanaALaEscritaAMano() {
        let fusionada = FusionCarreras.fusionar(
            [carrera("export-1", km: 8.4)],
            con: [carrera("manual-1", km: 8)]
        )
        XCTAssertEqual(fusionada.count, 1)
        XCTAssertEqual(fusionada[0].id, "export-1")
    }

    func testLaDeSaludSigueGanandoALaDelArchivo() {
        // Lo que ya hacía antes no cambia.
        let fusionada = FusionCarreras.fusionar(
            [carrera("export-1")],
            con: [carrera("UUID-REAL")]
        )
        XCTAssertEqual(fusionada[0].id, "UUID-REAL")
    }

    // MARK: - La ventana

    func testUnaCarreraMedidaCercaTapaLaEscritaAMano() {
        // El reloj dice 9:37 y el usuario escribió «esta mañana»: es la misma.
        let fusionada = FusionCarreras.fusionar(
            [carrera("manual-1", km: 8)],
            con: [carrera("UUID-REAL", minutosDespues: 37, km: 8.4)]
        )
        XCTAssertEqual(fusionada.map(\.id), ["UUID-REAL"])
    }

    func testJustoEnElBordeDeLaVentanaTodaviaEsLaMisma() {
        let fusionada = FusionCarreras.fusionar(
            [carrera("manual-1")],
            con: [carrera("UUID-REAL", minutosDespues: 90)]
        )
        XCTAssertEqual(fusionada.map(\.id), ["UUID-REAL"])
    }

    func testPasadaLaVentanaSonDosCarreras() {
        // Mañana y tarde: dos carreras, no una. Taparlas perdería uno de los
        // dos rodajes sin decir nada.
        let fusionada = FusionCarreras.fusionar(
            [carrera("manual-1")],
            con: [carrera("UUID-REAL", minutosDespues: 240)]
        )
        XCTAssertEqual(Set(fusionada.map(\.id)), ["manual-1", "UUID-REAL"])
    }

    func testLaVentanaFuncionaHaciaAtras() {
        // La medida puede empezar antes que la hora que se escribió.
        let fusionada = FusionCarreras.fusionar(
            [carrera("manual-1", minutosDespues: 60)],
            con: [carrera("UUID-REAL")]
        )
        XCTAssertEqual(fusionada.map(\.id), ["UUID-REAL"])
    }

    func testDosEscritasAManoNoSeTapanEntreSi() {
        // Sin ninguna medida de por medio, lo que hay es lo que el usuario
        // escribió, y eso no se toca.
        let fusionada = FusionCarreras.fusionar(
            [carrera("manual-1")],
            con: [carrera("manual-2", minutosDespues: 30)]
        )
        XCTAssertEqual(Set(fusionada.map(\.id)), ["manual-1", "manual-2"])
    }

    func testSinCarrerasMedidasSeQuedanTodasLasDeMano() {
        let fusionada = FusionCarreras.fusionar([], con: [carrera("manual-1")])
        XCTAssertEqual(fusionada.map(\.id), ["manual-1"])
    }

    func testUnaManualLejosDeOtraMedidaSobrevive() {
        let fusionada = FusionCarreras.fusionar(
            [carrera("manual-1", minutosDespues: 600)],
            con: [carrera("UUID-REAL")]
        )
        XCTAssertEqual(Set(fusionada.map(\.id)), ["manual-1", "UUID-REAL"])
    }

    func testElOrdenSigueSiendoDeMasRecienteAMasAntigua() {
        let fusionada = FusionCarreras.fusionar(
            [carrera("manual-1")],
            con: [carrera("manual-2", minutosDespues: 600)]
        )
        XCTAssertEqual(fusionada.map(\.id), ["manual-2", "manual-1"])
    }

    func testQueCuentaComoEscritaAMano() {
        XCTAssertTrue(FusionCarreras.esManual(carrera("manual-abc")))
        XCTAssertFalse(FusionCarreras.esManual(carrera("export-abc")))
        XCTAssertFalse(FusionCarreras.esManual(carrera("UUID")))
    }
}
