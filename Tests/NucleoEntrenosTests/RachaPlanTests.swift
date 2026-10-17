import XCTest
@testable import NucleoEntrenos

final class RachaPlanTests: XCTestCase {

    private let hoy = try! LectorPlanJSON.fecha("2026-10-13", ruta: "")

    private func dia(
        _ fecha: String,
        exigible: Bool = true,
        hecho: Bool
    ) -> (fecha: Date, esExigible: Bool, hecho: Bool) {
        (try! LectorPlanJSON.fecha(fecha, ruta: ""), exigible, hecho)
    }

    func testTresDiasSeguidosHechosSonTres() {
        let racha = ResumenPlan.racha(de: [
            dia("2026-10-10", hecho: true),
            dia("2026-10-11", hecho: true),
            dia("2026-10-12", hecho: true),
        ], hoy: hoy)
        XCTAssertEqual(racha.actual, 3)
        XCTAssertEqual(racha.mejor, 3)
    }

    func testUnDiaSaltadoRompeLaRachaActual() {
        let racha = ResumenPlan.racha(de: [
            dia("2026-10-09", hecho: true),
            dia("2026-10-10", hecho: true),
            dia("2026-10-11", hecho: false),
            dia("2026-10-12", hecho: true),
        ], hoy: hoy)
        XCTAssertEqual(racha.actual, 1)
        XCTAssertEqual(racha.mejor, 2)
    }

    func testElDescansoNoRompeNiSumaLaRacha() {
        // Si el descanso contara como fallo, la racha se apagaría cada
        // miércoles; si contara como acierto, se regalaría.
        let racha = ResumenPlan.racha(de: [
            dia("2026-10-10", hecho: true),
            dia("2026-10-11", exigible: false, hecho: false),
            dia("2026-10-12", hecho: true),
        ], hoy: hoy)
        XCTAssertEqual(racha.actual, 2)
        XCTAssertEqual(racha.mejor, 2)
    }

    func testHoySinMarcarNoRompeLaRacha() {
        // Lo de hoy aún se puede hacer: una racha que se rompe a las 00:01
        // por lo que falta por hacer no es una racha.
        let racha = ResumenPlan.racha(de: [
            dia("2026-10-11", hecho: true),
            dia("2026-10-12", hecho: true),
            dia("2026-10-13", hecho: false),
        ], hoy: hoy)
        XCTAssertEqual(racha.actual, 2)
    }

    func testHoyMarcadoSiCuenta() {
        let racha = ResumenPlan.racha(de: [
            dia("2026-10-12", hecho: true),
            dia("2026-10-13", hecho: true),
        ], hoy: hoy)
        XCTAssertEqual(racha.actual, 2)
    }

    func testElFuturoNoCuentaAunqueEsteMarcado() {
        let racha = ResumenPlan.racha(de: [
            dia("2026-10-12", hecho: true),
            dia("2026-10-20", hecho: true),
        ], hoy: hoy)
        XCTAssertEqual(racha.actual, 1)
    }

    func testSinDiasLaRachaEsCero() {
        let racha = ResumenPlan.racha(de: [], hoy: hoy)
        XCTAssertEqual(racha.actual, 0)
        XCTAssertEqual(racha.mejor, 0)
    }

    func testLaMejorRachaPuedeEstarEnElPasado() {
        let racha = ResumenPlan.racha(de: [
            dia("2026-10-05", hecho: true),
            dia("2026-10-06", hecho: true),
            dia("2026-10-07", hecho: true),
            dia("2026-10-08", hecho: true),
            dia("2026-10-09", hecho: false),
            dia("2026-10-12", hecho: true),
        ], hoy: hoy)
        XCTAssertEqual(racha.actual, 1)
        XCTAssertEqual(racha.mejor, 4)
    }

    func testLosDiasDesordenadosSeOrdenanSolos() {
        let racha = ResumenPlan.racha(de: [
            dia("2026-10-12", hecho: true),
            dia("2026-10-10", hecho: true),
            dia("2026-10-11", hecho: true),
        ], hoy: hoy)
        XCTAssertEqual(racha.actual, 3)
    }
}
