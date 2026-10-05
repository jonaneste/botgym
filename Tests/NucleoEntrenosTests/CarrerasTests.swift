import XCTest
@testable import NucleoEntrenos

final class CarreraTests: XCTestCase {

    private let calendario = CalendarioEntrenos.es

    private func fecha(_ dia: Int, _ mes: Int = 10, _ año: Int = 2026) -> Date {
        var c = DateComponents()
        c.year = año; c.month = mes; c.day = dia; c.hour = 9
        return calendario.date(from: c)!
    }

    func testRitmoYVelocidad() throws {
        // 10 km en 50 minutos: 5:00 /km y 12 km/h.
        let carrera = Carrera(id: "a", fechaInicio: fecha(5), duracion: 50 * 60, distanciaMetros: 10_000)
        XCTAssertEqual(try XCTUnwrap(carrera.ritmoSegundosPorKm), 300, accuracy: 0.01)
        XCTAssertEqual(carrera.ritmoTexto, "5:00 /km")
        XCTAssertEqual(try XCTUnwrap(carrera.velocidadKmH), 12, accuracy: 0.01)
    }

    func testRitmoConSegundosSueltos() {
        // 5 km en 26:00 → 5:12 /km.
        let carrera = Carrera(id: "a", fechaInicio: fecha(5), duracion: 26 * 60, distanciaMetros: 5_000)
        XCTAssertEqual(carrera.ritmoTexto, "5:12 /km")
    }

    func testSinDistanciaNoHayRitmo() {
        let carrera = Carrera(id: "a", fechaInicio: fecha(5), duracion: 1800, distanciaMetros: 0)
        XCTAssertNil(carrera.ritmoSegundosPorKm)
        XCTAssertNil(carrera.ritmoTexto)
        XCTAssertNil(carrera.velocidadKmH)
    }

    func testResumenSemanalSumaSoloLaSemanaPedida() {
        let carreras = [
            Carrera(id: "a", fechaInicio: fecha(5), duracion: 1800, distanciaMetros: 5_000),
            Carrera(id: "b", fechaInicio: fecha(8), duracion: 2400, distanciaMetros: 7_000),
            Carrera(id: "c", fechaInicio: fecha(12), duracion: 1800, distanciaMetros: 5_000),  // semana siguiente
        ]
        let resumen = ServicioCarreras.resumenSemanal(carreras, semanaDe: fecha(7), calendario: calendario)
        XCTAssertEqual(resumen.carreras, 2)
        XCTAssertEqual(resumen.kilometros, 12, accuracy: 0.001)
        XCTAssertEqual(resumen.duracion, 4200, accuracy: 0.001)
    }

    func testRitmoMedioDeLaSemana() throws {
        let carreras = [
            Carrera(id: "a", fechaInicio: fecha(5), duracion: 1500, distanciaMetros: 5_000),
            Carrera(id: "b", fechaInicio: fecha(8), duracion: 1500, distanciaMetros: 5_000),
        ]
        let resumen = ServicioCarreras.resumenSemanal(carreras, semanaDe: fecha(7), calendario: calendario)
        // 3000 s / 10 km = 300 s/km.
        XCTAssertEqual(try XCTUnwrap(resumen.ritmoMedioSegundosPorKm), 300, accuracy: 0.01)
    }

    func testSemanaSinCorrerDaResumenACero() {
        let resumen = ServicioCarreras.resumenSemanal([], semanaDe: fecha(7), calendario: calendario)
        XCTAssertEqual(resumen.carreras, 0)
        XCTAssertEqual(resumen.kilometros, 0, accuracy: 0.001)
        XCTAssertNil(resumen.ritmoMedioSegundosPorKm)
    }

    func testKilometrosPorSemanaIncluyeLasSemanasVacias() {
        let carreras = [Carrera(id: "a", fechaInicio: fecha(5), duracion: 1800, distanciaMetros: 5_000)]
        let semanas = ServicioCarreras.kilometrosPorSemana(carreras, semanas: 3, hasta: fecha(7), calendario: calendario)
        XCTAssertEqual(semanas.count, 3)
        XCTAssertEqual(semanas.map { $0.kilometros }, [0, 0, 5])
    }
}

final class InterpreteHealthTests: XCTestCase {

    private func registro(
        tipo: String = InterpreteHealth.tipoCarrera,
        inicio: String = "2026-10-05 09:30:00 +0200",
        duracion: String = "32.5",
        unidadDuracion: String = "min",
        estadisticas: [[String: String]] = []
    ) -> RegistroEntrenoHealth {
        RegistroEntrenoHealth(
            atributos: [
                "workoutActivityType": tipo,
                "startDate": inicio,
                "duration": duracion,
                "durationUnit": unidadDuracion,
                "sourceName": "Zepp",
            ],
            estadisticas: estadisticas
        )
    }

    func testInterpretaUnaCarreraCompleta() throws {
        let entrada = registro(estadisticas: [
            ["type": "HKQuantityTypeIdentifierDistanceWalkingRunning", "sum": "6.2", "unit": "km"],
            ["type": "HKQuantityTypeIdentifierHeartRate", "average": "148.5", "unit": "count/min"],
            ["type": "HKQuantityTypeIdentifierActiveEnergyBurned", "sum": "480", "unit": "kcal"],
        ])
        let carrera = try XCTUnwrap(InterpreteHealth.carrera(de: entrada))
        XCTAssertEqual(carrera.duracion, 32.5 * 60, accuracy: 0.01)
        XCTAssertEqual(carrera.distanciaMetros, 6200, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(carrera.pulsoMedio), 148.5, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(carrera.calorias), 480, accuracy: 0.01)
        XCTAssertEqual(carrera.origen, "Zepp")
    }

    func testLoQueNoEsUnaCarreraSeIgnora() {
        let ciclismo = registro(tipo: "HKWorkoutActivityTypeCycling")
        XCTAssertFalse(InterpreteHealth.esCarrera(ciclismo))
        XCTAssertNil(InterpreteHealth.carrera(de: ciclismo))
    }

    func testSinFechaNoSePuedeInterpretar() {
        var entrada = registro()
        entrada.atributos["startDate"] = nil
        XCTAssertNil(InterpreteHealth.carrera(de: entrada))
    }

    func testSinDuracionNoSePuedeInterpretar() {
        var entrada = registro()
        entrada.atributos["duration"] = nil
        XCTAssertNil(InterpreteHealth.carrera(de: entrada))
    }

    func testUnaCarreraSinDistanciaSeInterpretaConCero() throws {
        let carrera = try XCTUnwrap(InterpreteHealth.carrera(de: registro()))
        XCTAssertEqual(carrera.distanciaMetros, 0, accuracy: 0.001)
        XCTAssertNil(carrera.ritmoTexto)
    }

    func testUnidadesDeDuracion() {
        XCTAssertEqual(InterpreteHealth.duracionSegundos(valor: "30", unidad: "min"), 1800)
        XCTAssertEqual(InterpreteHealth.duracionSegundos(valor: "90", unidad: "s"), 90)
        XCTAssertEqual(InterpreteHealth.duracionSegundos(valor: "1.5", unidad: "h"), 5400)
        XCTAssertEqual(InterpreteHealth.duracionSegundos(valor: "30", unidad: nil), 1800, "por defecto, minutos")
        XCTAssertNil(InterpreteHealth.duracionSegundos(valor: "nada", unidad: "min"))
    }

    func testUnidadesDeDistancia() {
        XCTAssertEqual(InterpreteHealth.enMetros(5, unidad: "km"), 5000, accuracy: 0.01)
        XCTAssertEqual(InterpreteHealth.enMetros(5000, unidad: "m"), 5000, accuracy: 0.01)
        XCTAssertEqual(InterpreteHealth.enMetros(1, unidad: "mi"), 1609.344, accuracy: 0.01)
        XCTAssertEqual(InterpreteHealth.enMetros(5, unidad: nil), 5000, accuracy: 0.01, "por defecto, km")
    }

    func testDistanciaDesdeElAtributoAntiguo() throws {
        var entrada = registro()
        entrada.atributos["totalDistance"] = "8.4"
        entrada.atributos["totalDistanceUnit"] = "km"
        let carrera = try XCTUnwrap(InterpreteHealth.carrera(de: entrada))
        XCTAssertEqual(carrera.distanciaMetros, 8400, accuracy: 0.01)
    }

    func testFormatosDeFecha() {
        XCTAssertNotNil(InterpreteHealth.fecha(de: "2026-10-05 09:30:00 +0200"))
        XCTAssertNotNil(InterpreteHealth.fecha(de: "2026-10-05T09:30:00Z"))
        XCTAssertNil(InterpreteHealth.fecha(de: "ayer por la mañana"))
    }

    func testElIdentificadorEsEstableSinUUID() throws {
        // Releer el mismo archivo no debe duplicar la carrera.
        let primera = try XCTUnwrap(InterpreteHealth.carrera(de: registro()))
        let segunda = try XCTUnwrap(InterpreteHealth.carrera(de: registro()))
        XCTAssertEqual(primera.id, segunda.id)
    }

    func testSeUsaElUUIDSiVieneEnElRegistro() throws {
        var entrada = registro()
        entrada.atributos["uuid"] = "ABC-123"
        let carrera = try XCTUnwrap(InterpreteHealth.carrera(de: entrada))
        XCTAssertEqual(carrera.id, "ABC-123")
    }
}
