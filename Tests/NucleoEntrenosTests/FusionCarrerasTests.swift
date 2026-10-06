import XCTest
@testable import NucleoEntrenos

/// Una carrera leída por los dos caminos (HealthKit y el `exportar.xml`) no
/// puede contar dos veces.
final class FusionCarrerasTests: XCTestCase {

    private let inicio = Date(timeIntervalSince1970: 1_790_000_000)

    private func deArchivo(_ fecha: Date, km: Double = 10) -> Carrera {
        Carrera(
            id: "\(FusionCarreras.prefijoExport)\(fecha)",
            fechaInicio: fecha,
            duracion: 3_000,
            distanciaMetros: km * 1_000,
            origen: "Exportación de Salud"
        )
    }

    private func deSalud(_ fecha: Date, km: Double = 10, pulso: Double? = 150) -> Carrera {
        Carrera(
            id: "UUID-REAL",
            fechaInicio: fecha,
            duracion: 3_000,
            distanciaMetros: km * 1_000,
            pulsoMedio: pulso,
            origen: "Zepp"
        )
    }

    func testLaMismaCarreraPorLosDosCaminosNoSeDuplica() {
        let fusionadas = FusionCarreras.fusionar([deArchivo(inicio)], con: [deSalud(inicio)])
        XCTAssertEqual(fusionadas.count, 1)
    }

    func testGanaLaDeSaludPorqueTraeElUUIDRealYElPulso() {
        let fusionadas = FusionCarreras.fusionar([deArchivo(inicio)], con: [deSalud(inicio)])
        XCTAssertEqual(fusionadas.first?.id, "UUID-REAL")
        XCTAssertEqual(fusionadas.first?.pulsoMedio, 150)
    }

    func testGanaLaDeSaludTambienSiLLegaPrimero() {
        // El orden de importación no puede decidir qué dato se queda.
        let fusionadas = FusionCarreras.fusionar([deSalud(inicio)], con: [deArchivo(inicio)])
        XCTAssertEqual(fusionadas.first?.id, "UUID-REAL")
        XCTAssertEqual(fusionadas.first?.pulsoMedio, 150)
    }

    func testReimportarElMismoArchivoNoDuplica() {
        let fusionadas = FusionCarreras.fusionar([deArchivo(inicio)], con: [deArchivo(inicio)])
        XCTAssertEqual(fusionadas.count, 1)
    }

    func testDosLecturasDelArchivoSeQuedanConLaUltima() {
        let corregida = deArchivo(inicio, km: 12)
        let fusionadas = FusionCarreras.fusionar([deArchivo(inicio, km: 10)], con: [corregida])
        XCTAssertEqual(fusionadas.first?.distanciaMetros, 12_000)
    }

    func testCarrerasDeDiasDistintosSeConservanLasDos() {
        let otra = inicio.addingTimeInterval(86_400)
        let fusionadas = FusionCarreras.fusionar([deArchivo(inicio)], con: [deArchivo(otra)])
        XCTAssertEqual(fusionadas.count, 2)
    }

    func testCarrerasDelMismoDiaADistintaHoraSeConservanLasDos() {
        let tarde = inicio.addingTimeInterval(8 * 3_600)
        let fusionadas = FusionCarreras.fusionar([deArchivo(inicio)], con: [deArchivo(tarde)])
        XCTAssertEqual(fusionadas.count, 2)
    }

    func testSalenDeMasRecienteAMasAntigua() {
        let ayer = inicio.addingTimeInterval(-86_400)
        let fusionadas = FusionCarreras.fusionar([deArchivo(ayer)], con: [deArchivo(inicio)])
        XCTAssertEqual(fusionadas.map(\.fechaInicio), [inicio, ayer])
    }

    func testUnaDiferenciaDeMilisegundosSigueSiendoLaMismaCarrera() {
        // Los dos caminos leen la misma muestra, así que el instante coincide
        // al segundo; el redondeo absorbe cualquier ruido por debajo.
        let casiIgual = inicio.addingTimeInterval(0.2)
        let fusionadas = FusionCarreras.fusionar([deArchivo(inicio)], con: [deSalud(casiIgual)])
        XCTAssertEqual(fusionadas.count, 1)
    }

    func testUnaFechaAbsurdaNoRompeLaFusion() {
        // `Int(Date.distantFuture.timeIntervalSince1970)` no atrapa, pero sí lo
        // haría con un valor no finito llegado de un archivo corrupto.
        let fusionadas = FusionCarreras.fusionar(
            [deArchivo(Date.distantFuture)],
            con: [deArchivo(Date.distantPast)]
        )
        XCTAssertEqual(fusionadas.count, 2)
    }
}
