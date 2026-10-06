import XCTest
@testable import NucleoEntrenos

/// Lo que se escribe a mano en un campo numérico tiene que quedarse en un
/// rango que el resto de la app pueda convertir a `Int` sin atrapar.
final class LimitesEntradaTests: XCTestCase {

    func testElPesoNormalPasaIntacto() {
        XCTAssertEqual(LimitesEntrada.peso(62.5), 62.5)
        XCTAssertEqual(LimitesEntrada.peso(0), 0)
        XCTAssertEqual(LimitesEntrada.peso(LimitesEntrada.pesoMaximo), LimitesEntrada.pesoMaximo)
    }

    func testElPesoSeRecortaAlTope() {
        XCTAssertEqual(LimitesEntrada.peso(1e20), LimitesEntrada.pesoMaximo)
        XCTAssertEqual(LimitesEntrada.peso(-5), 0)
    }

    func testUnPesoNoFinitoSeVaACero() {
        XCTAssertEqual(LimitesEntrada.peso(.infinity), 0)
        XCTAssertEqual(LimitesEntrada.peso(-.infinity), 0)
        XCTAssertEqual(LimitesEntrada.peso(.nan), 0)
    }

    func testLaConversionAEnteroNoAtrapaConValoresImposibles() {
        // `Int(1e20)` cierra la app. Esto es justo lo que evita que un peso
        // pegado en un campo deje el historial inservible.
        XCTAssertEqual(LimitesEntrada.entero(1e20), Int(1e15))
        XCTAssertEqual(LimitesEntrada.entero(-1e20), Int(-1e15))
        XCTAssertEqual(LimitesEntrada.entero(Double.infinity), 0)
        XCTAssertEqual(LimitesEntrada.entero(Double.nan), 0)
    }

    func testLaConversionAEnteroRedondea() {
        XCTAssertEqual(LimitesEntrada.entero(12.4), 12)
        XCTAssertEqual(LimitesEntrada.entero(12.6), 13)
        XCTAssertEqual(LimitesEntrada.entero(12.0), 12)
    }

    func testRecortarEnteros() {
        XCTAssertEqual(LimitesEntrada.recortar(10), 10)
        XCTAssertEqual(LimitesEntrada.recortar(-1), 0)
        XCTAssertEqual(LimitesEntrada.recortar(Int.max), LimitesEntrada.enteroMaximo)
    }

    func testElVolumenDeUnaSerieAlTopeSigueSiendoConvertible() {
        // peso máximo × repeticiones máximas, que es el peor caso que puede
        // llegar a `Formato.volumen` o al CSV.
        let peor = LimitesEntrada.pesoMaximo * Double(LimitesEntrada.enteroMaximo)
        XCTAssertEqual(LimitesEntrada.entero(peor), Int(peor.rounded()))
    }
}
