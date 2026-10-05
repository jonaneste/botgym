import XCTest
@testable import NucleoEntrenos

final class CalculadoraRMTests: XCTestCase {

    func testEpleyConUnaRepeticionDevuelveElPeso() {
        XCTAssertEqual(CalculadoraRM.epley(peso: 100, repeticiones: 1), 100)
    }

    func testEpleyConDiezRepeticiones() throws {
        // 100 × (1 + 10/30) = 133,333…
        let resultado = CalculadoraRM.epley(peso: 100, repeticiones: 10)
        XCTAssertEqual(try XCTUnwrap(resultado), 133.333, accuracy: 0.001)
    }

    func testEpleyConValorRealDeLaRutina() throws {
        // Press banca 60 kg × 9 → 78 kg estimados.
        let resultado = CalculadoraRM.epley(peso: 60, repeticiones: 9)
        XCTAssertEqual(try XCTUnwrap(resultado), 78.0, accuracy: 0.001)
    }

    func testEpleyCreceConLasRepeticiones() throws {
        let ocho = try XCTUnwrap(CalculadoraRM.epley(peso: 80, repeticiones: 8))
        let diez = try XCTUnwrap(CalculadoraRM.epley(peso: 80, repeticiones: 10))
        XCTAssertGreaterThan(diez, ocho)
    }

    func testEpleyRechazaPesoCeroONegativo() {
        XCTAssertNil(CalculadoraRM.epley(peso: 0, repeticiones: 10))
        XCTAssertNil(CalculadoraRM.epley(peso: -20, repeticiones: 10))
    }

    func testEpleyRechazaCeroRepeticiones() {
        XCTAssertNil(CalculadoraRM.epley(peso: 100, repeticiones: 0))
        XCTAssertNil(CalculadoraRM.epley(peso: 100, repeticiones: -3))
    }

    func testEpleyConRIRSumaLasRepeticionesEnReserva() throws {
        // 8 reps con RIR 2 equivale a 10 al fallo.
        let conRIR = CalculadoraRM.epleyConRIR(peso: 80, repeticiones: 8, rir: 2)
        let sinRIR = CalculadoraRM.epley(peso: 80, repeticiones: 10)
        XCTAssertEqual(try XCTUnwrap(conRIR), try XCTUnwrap(sinRIR), accuracy: 0.0001)
    }

    func testEpleyConRIRNuloEquivaleASinRIR() throws {
        let conRIR = CalculadoraRM.epleyConRIR(peso: 80, repeticiones: 8, rir: nil)
        let sinRIR = CalculadoraRM.epley(peso: 80, repeticiones: 8)
        XCTAssertEqual(try XCTUnwrap(conRIR), try XCTUnwrap(sinRIR), accuracy: 0.0001)
    }

    func testEpleyConRIRNegativoNoResta() throws {
        // Un RIR negativo no debería bajar la estimación por debajo de las
        // repeticiones realmente hechas.
        let conRIR = CalculadoraRM.epleyConRIR(peso: 80, repeticiones: 8, rir: -3)
        let sinRIR = CalculadoraRM.epley(peso: 80, repeticiones: 8)
        XCTAssertEqual(try XCTUnwrap(conRIR), try XCTUnwrap(sinRIR), accuracy: 0.0001)
    }

    func testEjerciciosDeTiempoNoTienenEstimacionDeMaximo() {
        let serie = SerieValor(peso: 0, segundos: 40, completada: true)
        XCTAssertNil(CalculadoraRM.epley(serie: serie, tipo: .tiempo))
    }

    func testEstimacionDesdeSerieDeRepeticiones() throws {
        let serie = SerieValor(peso: 60, repeticiones: 9, completada: true)
        let resultado = CalculadoraRM.epley(serie: serie, tipo: .repeticiones)
        XCTAssertEqual(try XCTUnwrap(resultado), 78.0, accuracy: 0.001)
    }

    func testPesoParaEsLaInversaDeEpley() throws {
        let unRM = try XCTUnwrap(CalculadoraRM.epley(peso: 60, repeticiones: 9))
        let vuelta = try XCTUnwrap(CalculadoraRM.pesoPara(unRM: unRM, repeticiones: 9))
        XCTAssertEqual(vuelta, 60.0, accuracy: 0.0001)
    }

    func testPesoParaRechazaEntradasInvalidas() {
        XCTAssertNil(CalculadoraRM.pesoPara(unRM: 0, repeticiones: 8))
        XCTAssertNil(CalculadoraRM.pesoPara(unRM: 100, repeticiones: 0))
    }
}
