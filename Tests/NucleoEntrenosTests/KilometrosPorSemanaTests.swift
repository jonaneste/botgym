import XCTest
@testable import NucleoEntrenos

/// Los kilómetros del plan frente a los que se corrieron de verdad.
final class KilometrosPorSemanaTests: XCTestCase {

    private let calendario = CalendarioEntrenos.es

    /// Un lunes cualquiera, para que las semanas salgan limpias.
    private var lunes: Date {
        CalendarioEntrenos.inicioDeSemana(de: Date(), calendario: calendario)
    }

    private func dia(_ diasDesdeElLunes: Int, km: Double?) -> DiaPlanValor {
        let fecha = calendario.date(byAdding: .day, value: diasDesdeElLunes, to: lunes) ?? lunes
        return DiaPlanValor(
            fecha: fecha,
            tipo: km == nil ? .gimnasio : .carrera,
            titulo: "",
            kilometros: km
        )
    }

    private func carrera(_ diasDesdeElLunes: Int, km: Double) -> Carrera {
        let fecha = calendario.date(byAdding: .day, value: diasDesdeElLunes, to: lunes) ?? lunes
        return Carrera(
            id: "c-\(diasDesdeElLunes)-\(km)",
            fechaInicio: fecha,
            duracion: 60 * 30,
            distanciaMetros: km * 1_000
        )
    }

    func testCadaSemanaEnfrentaLoPrevistoConLoCorrido() {
        let semanas = ResumenPlan.kilometrosPorSemana(
            plan: [dia(1, km: 8), dia(4, km: 12)],
            carreras: [carrera(1, km: 8), carrera(4, km: 10)],
            calendario: calendario
        )

        XCTAssertEqual(semanas.count, 1)
        XCTAssertEqual(semanas[0].previstos, 20)
        XCTAssertEqual(semanas[0].hechos, 18)
        XCTAssertEqual(semanas[0].faltan, 2)
        XCTAssertFalse(semanas[0].cumplida)
    }

    func testUnaSemanaConLoPrevistoHechoEstaCumplida() {
        let semanas = ResumenPlan.kilometrosPorSemana(
            plan: [dia(1, km: 10)],
            carreras: [carrera(1, km: 10)],
            calendario: calendario
        )
        XCTAssertTrue(semanas[0].cumplida)
        XCTAssertEqual(semanas[0].faltan, 0)
        XCTAssertEqual(semanas[0].fraccion, 1)
    }

    /// Correr de más no deja kilómetros negativos pendientes, ni una fracción
    /// por encima de 1 que se saldría de la barra.
    func testCorrerDeMasNoDaNegativosNiPasaDeUno() {
        let semanas = ResumenPlan.kilometrosPorSemana(
            plan: [dia(1, km: 10)],
            carreras: [carrera(1, km: 15)],
            calendario: calendario
        )
        XCTAssertEqual(semanas[0].faltan, 0)
        XCTAssertEqual(semanas[0].fraccion, 1)
    }

    /// Una semana sin kilómetros previstos no se puede incumplir.
    func testUnaSemanaSinPrevistosNoTieneFraccion() {
        let semanas = ResumenPlan.kilometrosPorSemana(
            plan: [dia(1, km: nil)],
            carreras: [],
            calendario: calendario
        )
        XCTAssertNil(semanas[0].fraccion)
        XCTAssertFalse(semanas[0].cumplida)
    }

    /// Las semanas sin kilómetros previstos salen igualmente: saltárselas
    /// dejaría huecos y haría parecer seguidas dos semanas que no lo son.
    func testLasSemanasDeDescansoSiguenSaliendo() {
        let semanas = ResumenPlan.kilometrosPorSemana(
            plan: [dia(1, km: 10), dia(8, km: nil), dia(15, km: 12)],
            carreras: [],
            calendario: calendario
        )
        XCTAssertEqual(semanas.count, 3)
        XCTAssertEqual(semanas.map(\.previstos), [10, 0, 12])
    }

    /// Van en orden, de la semana más antigua a la más reciente, aunque el
    /// plan llegue desordenado.
    func testSalenEnOrdenAunqueElPlanLlegueDesordenado() {
        let semanas = ResumenPlan.kilometrosPorSemana(
            plan: [dia(15, km: 12), dia(1, km: 10), dia(8, km: 6)],
            carreras: [],
            calendario: calendario
        )
        XCTAssertEqual(semanas.map(\.previstos), [10, 6, 12])
        XCTAssertEqual(semanas, semanas.sorted { $0.inicioSemana < $1.inicioSemana })
    }

    /// Una carrera de otra semana no se cuela en esta.
    func testUnaCarreraDeOtraSemanaNoCuenta() {
        let semanas = ResumenPlan.kilometrosPorSemana(
            plan: [dia(1, km: 10)],
            carreras: [carrera(8, km: 10)],
            calendario: calendario
        )
        XCTAssertEqual(semanas[0].hechos, 0)
    }

    func testSinPlanNoHaySemanas() {
        XCTAssertTrue(
            ResumenPlan.kilometrosPorSemana(plan: [], carreras: [], calendario: calendario).isEmpty
        )
    }
}
