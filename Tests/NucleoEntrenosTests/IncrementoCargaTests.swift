import XCTest
@testable import NucleoEntrenos

final class IncrementoCargaTests: XCTestCase {

    func testBarraSubeDosComaCinco() {
        let resultado = IncrementoCarga.siguientePeso(desde: 60, material: .barra)
        XCTAssertEqual(resultado, 62.5, accuracy: 0.0001)
    }

    func testPoleaYMaquinaUsanSuPropioIncremento() {
        let reglas = ReglasIncremento(incrementoPolea: 2.5, incrementoMaquina: 5)
        XCTAssertEqual(IncrementoCarga.siguientePeso(desde: 30, material: .polea, reglas: reglas), 32.5, accuracy: 0.0001)
        XCTAssertEqual(IncrementoCarga.siguientePeso(desde: 30, material: .maquina, reglas: reglas), 35, accuracy: 0.0001)
    }

    func testPesoCorporalNoSube() {
        // A peso corporal se progresa en repeticiones, no en kilos.
        XCTAssertEqual(IncrementoCarga.siguientePeso(desde: 0, material: .pesoCorporal), 0, accuracy: 0.0001)
    }

    func testMancuernaSaltaAlSiguienteParDisponible() {
        let resultado = IncrementoCarga.siguientePeso(desde: 20, material: .mancuerna)
        XCTAssertEqual(resultado, 22.5, accuracy: 0.0001)
    }

    func testMancuernaSaltaBienEntreDecimales() {
        // De 22,5 a 25, sin quedarse atascada por el coma cinco.
        let resultado = IncrementoCarga.siguienteMancuerna(desde: 22.5, disponibles: ReglasIncremento.mancuernasHabituales)
        XCTAssertEqual(resultado, 25, accuracy: 0.0001)
    }

    func testMancuernaEnElTopeSeQuedaEnElTope() {
        // No sugerir una mancuerna que no existe en la sala.
        let resultado = IncrementoCarga.siguienteMancuerna(desde: 50, disponibles: ReglasIncremento.mancuernasHabituales)
        XCTAssertEqual(resultado, 50, accuracy: 0.0001)
    }

    func testMancuernaPorDebajoDelJuegoEmpiezaPorLaMasLigera() {
        let resultado = IncrementoCarga.siguienteMancuerna(desde: 0, disponibles: [6, 8, 10])
        XCTAssertEqual(resultado, 6, accuracy: 0.0001)
    }

    func testMancuernaConPesoIntermedioSubeAlSiguienteReal() {
        // 21 kg no existe en el juego: la siguiente es la de 22,5.
        let resultado = IncrementoCarga.siguienteMancuerna(desde: 21, disponibles: ReglasIncremento.mancuernasHabituales)
        XCTAssertEqual(resultado, 22.5, accuracy: 0.0001)
    }

    func testMancuernaSinJuegoDisponibleDevuelveElMismoPeso() {
        XCTAssertEqual(IncrementoCarga.siguienteMancuerna(desde: 12, disponibles: []), 12, accuracy: 0.0001)
    }

    func testLasMancuernasSeOrdenanAlConstruirLasReglas() {
        let reglas = ReglasIncremento(mancuernasDisponibles: [10, 2, 6])
        XCTAssertEqual(reglas.mancuernasDisponibles, [2, 6, 10])
    }

    func testTiempoSubeCincoSegundosPorDefecto() {
        XCTAssertEqual(IncrementoCarga.siguienteTiempo(desde: 30), 35)
    }

    func testTiempoRespetaElIncrementoConfigurado() {
        let reglas = ReglasIncremento(incrementoTiempo: 10)
        XCTAssertEqual(IncrementoCarga.siguienteTiempo(desde: 30, reglas: reglas), 40)
    }
}
