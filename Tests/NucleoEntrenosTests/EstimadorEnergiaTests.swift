import XCTest
@testable import NucleoEntrenos

final class EstimadorEnergiaTests: XCTestCase {

    func testFormulaMET() throws {
        // 4,5 MET × 80 kg × 1 h = 360 kcal.
        let kcal = EstimadorEnergia.kilocalorias(duracion: 3600, pesoCorporal: 80, met: 4.5)
        XCTAssertEqual(try XCTUnwrap(kcal), 360, accuracy: 0.5)
    }

    func testUnaSesionRealDeHoraYCuarto() throws {
        // 75 min a 4,5 MET con 80 kg → 450 kcal.
        let kcal = EstimadorEnergia.kilocalorias(duracion: 75 * 60, pesoCorporal: 80)
        XCTAssertEqual(try XCTUnwrap(kcal), 450, accuracy: 0.5)
    }

    func testEscalaConElPesoCorporal() throws {
        let ligero = try XCTUnwrap(EstimadorEnergia.kilocalorias(duracion: 3600, pesoCorporal: 60))
        let pesado = try XCTUnwrap(EstimadorEnergia.kilocalorias(duracion: 3600, pesoCorporal: 90))
        XCTAssertGreaterThan(pesado, ligero)
        XCTAssertEqual(pesado / ligero, 1.5, accuracy: 0.01)
    }

    func testEscalaConLaDuracion() throws {
        let corto = try XCTUnwrap(EstimadorEnergia.kilocalorias(duracion: 1800, pesoCorporal: 80))
        let largo = try XCTUnwrap(EstimadorEnergia.kilocalorias(duracion: 3600, pesoCorporal: 80))
        XCTAssertEqual(largo / corto, 2, accuracy: 0.01)
    }

    func testSinPesoCorporalNoSeEstima() {
        // Es el caso importante: antes que inventar un peso, no se escribe nada.
        XCTAssertNil(EstimadorEnergia.kilocalorias(duracion: 3600, pesoCorporal: 0))
        XCTAssertNil(EstimadorEnergia.kilocalorias(duracion: 3600, pesoCorporal: -80))
    }

    func testSinDuracionNoSeEstima() {
        XCTAssertNil(EstimadorEnergia.kilocalorias(duracion: 0, pesoCorporal: 80))
        XCTAssertNil(EstimadorEnergia.kilocalorias(duracion: -60, pesoCorporal: 80))
    }

    func testMETNoValidoNoEstima() {
        XCTAssertNil(EstimadorEnergia.kilocalorias(duracion: 3600, pesoCorporal: 80, met: 0))
    }

    func testElResultadoEsEntero() throws {
        let kcal = try XCTUnwrap(EstimadorEnergia.kilocalorias(duracion: 2000, pesoCorporal: 77.5))
        XCTAssertEqual(kcal, kcal.rounded(), "no se dan decimales en una estimación")
    }

    func testElMETSeAcota() {
        XCTAssertEqual(EstimadorEnergia.metValido(0.5), EstimadorEnergia.metMinimo)
        XCTAssertEqual(EstimadorEnergia.metValido(20), EstimadorEnergia.metMaximo)
        XCTAssertEqual(EstimadorEnergia.metValido(4.5), 4.5)
    }
}
