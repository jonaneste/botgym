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

    // MARK: - Tope de repeticiones

    func testNoSeEstimaPorEncimaDelTope() {
        // El caso real: un dedo de más al teclear convirtió «12» en «127», y
        // Epley devolvía 167,5 kg para una serie de 32. Ese número se guardaba
        // como récord y ya no se podía superar nunca.
        XCTAssertNil(
            CalculadoraRM.epley(peso: 32, repeticiones: 127),
            "127 repeticiones no pueden producir una estimación"
        )
        XCTAssertNil(CalculadoraRM.epley(peso: 10, repeticiones: 121))
    }

    func testJustoEnElTopeSiSeEstima() {
        let tope = CalculadoraRM.repeticionesMaximasParaEstimar
        XCTAssertNotNil(CalculadoraRM.epley(peso: 50, repeticiones: tope))
        XCTAssertNil(CalculadoraRM.epley(peso: 50, repeticiones: tope + 1))
    }

    func testElRangoNormalDeEntrenoSigueEstimando() {
        // Series de 8 a 15 son lo que se hace de verdad: el tope no puede
        // estorbar ahí.
        for reps in 1...15 {
            XCTAssertNotNil(
                CalculadoraRM.epley(peso: 60, repeticiones: reps),
                "dejó de estimar en \(reps) repeticiones"
            )
        }
    }

    func testElRIRCuentaParaElTope() {
        // El RIR se suma a las repeticiones antes de aplicar Epley, así que
        // también tiene que contar para decidir si la estimación vale.
        let tope = CalculadoraRM.repeticionesMaximasParaEstimar
        XCTAssertNotNil(CalculadoraRM.epleyConRIR(peso: 40, repeticiones: tope - 2, rir: 2))
        XCTAssertNil(CalculadoraRM.epleyConRIR(peso: 40, repeticiones: tope, rir: 3))
    }
}
