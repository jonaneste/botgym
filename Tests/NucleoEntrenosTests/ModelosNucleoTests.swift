import XCTest
@testable import NucleoEntrenos

final class SerieValorTests: XCTestCase {

    func testVolumenEsPesoPorRepeticiones() {
        let serie = SerieValor(peso: 62.5, repeticiones: 8, completada: true)
        XCTAssertEqual(serie.volumen, 500.0, accuracy: 0.0001)
    }

    func testSerieCompletadaNoDeCalentamientoEsEfectiva() {
        let serie = SerieValor(peso: 60, repeticiones: 9, completada: true)
        XCTAssertTrue(serie.esEfectiva)
    }

    func testSerieSinCompletarNoEsEfectiva() {
        let serie = SerieValor(peso: 60, repeticiones: 9, completada: false)
        XCTAssertFalse(serie.esEfectiva)
    }

    func testSerieDeCalentamientoNoEsEfectiva() {
        let serie = SerieValor(peso: 40, repeticiones: 10, completada: true, esCalentamiento: true)
        XCTAssertFalse(serie.esEfectiva)
    }

    func testLogroUsaRepeticionesEnEjerciciosNormales() {
        let serie = SerieValor(peso: 60, repeticiones: 9, segundos: 99, completada: true)
        XCTAssertEqual(serie.logro(tipo: .repeticiones), 9)
        XCTAssertEqual(serie.logro(tipo: .repeticionesPorLado), 9)
    }

    func testLogroUsaSegundosEnEjerciciosDeTiempo() {
        let serie = SerieValor(peso: 0, repeticiones: 0, segundos: 40, completada: true)
        XCTAssertEqual(serie.logro(tipo: .tiempo), 40)
    }

    func testLogroDeTiempoSinSegundosEsCero() {
        let serie = SerieValor(peso: 0, completada: true)
        XCTAssertEqual(serie.logro(tipo: .tiempo), 0)
    }
}

final class ObjetivoEjercicioTests: XCTestCase {

    func testRangoNormalSePintaConGuion() {
        let objetivo = ObjetivoEjercicio(series: 4, objetivoMin: 8, objetivoMax: 10)
        XCTAssertEqual(objetivo.textoRango(tipo: .repeticiones), "8-10")
    }

    func testRangoDeUnSoloValorNoRepiteElNumero() {
        let objetivo = ObjetivoEjercicio(series: 3, objetivoMin: 15, objetivoMax: 15)
        XCTAssertEqual(objetivo.textoRango(tipo: .repeticiones), "15")
    }

    func testRangoDeTiempoLlevaUnidadDeSegundos() {
        let objetivo = ObjetivoEjercicio(series: 4, objetivoMin: 30, objetivoMax: 45)
        XCTAssertEqual(objetivo.textoRango(tipo: .tiempo), "30-45 s")
    }

    func testSeriesLibresSinRango() {
        let objetivo = ObjetivoEjercicio(series: 3)
        XCTAssertTrue(objetivo.sinRango)
        XCTAssertEqual(objetivo.textoRango(tipo: .repeticiones), "libre")
        XCTAssertNil(objetivo.tope)
        XCTAssertNil(objetivo.suelo)
    }

    func testTopeYSueloConRangoCompleto() {
        let objetivo = ObjetivoEjercicio(series: 4, objetivoMin: 6, objetivoMax: 8)
        XCTAssertEqual(objetivo.suelo, 6)
        XCTAssertEqual(objetivo.tope, 8)
    }

    func testTopeYSueloConUnSoloExtremo() {
        let soloMin = ObjetivoEjercicio(series: 3, objetivoMin: 12)
        XCTAssertEqual(soloMin.suelo, 12)
        XCTAssertEqual(soloMin.tope, 12)

        let soloMax = ObjetivoEjercicio(series: 3, objetivoMax: 12)
        XCTAssertEqual(soloMax.suelo, 12)
        XCTAssertEqual(soloMax.tope, 12)
    }

    func testTextoRIRConRango() {
        let objetivo = ObjetivoEjercicio(series: 4, objetivoMin: 8, objetivoMax: 10, rirMin: 2, rirMax: 3)
        XCTAssertEqual(objetivo.textoRIR, "RIR 2-3")
    }

    func testTextoRIRConValorUnico() {
        let objetivo = ObjetivoEjercicio(series: 3, rirMin: 2, rirMax: 2)
        XCTAssertEqual(objetivo.textoRIR, "RIR 2")
    }

    func testTextoRIRVacioSinObjetivo() {
        let objetivo = ObjetivoEjercicio(series: 3)
        XCTAssertEqual(objetivo.textoRIR, "")
    }
}

final class GrupoMuscularTests: XCTestCase {

    func testTodosLosGruposTienenNombreLegible() {
        for grupo in GrupoMuscular.allCases {
            XCTAssertFalse(grupo.nombre.isEmpty, "\(grupo.rawValue) sin nombre")
        }
    }

    func testTodosLosGruposTienenRegion() {
        // Si se añade un grupo nuevo y se olvida clasificarlo, el switch de
        // `region` no compila. Este test documenta la intención.
        let regiones = Set(GrupoMuscular.allCases.map(\.region))
        XCTAssertEqual(regiones.count, RegionCorporal.allCases.count)
    }

    func testMaterialesTienenNombreEIcono() {
        for material in Material.allCases {
            XCTAssertFalse(material.nombre.isEmpty, "\(material.rawValue) sin nombre")
            XCTAssertFalse(material.icono.isEmpty, "\(material.rawValue) sin icono")
        }
    }

    func testSoloElTipoTiempoSeMideEnSegundos() {
        XCTAssertTrue(TipoRegistro.tiempo.esTiempo)
        XCTAssertFalse(TipoRegistro.repeticiones.esTiempo)
        XCTAssertFalse(TipoRegistro.repeticionesPorLado.esTiempo)
    }
}
