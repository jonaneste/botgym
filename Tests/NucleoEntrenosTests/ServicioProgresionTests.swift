import XCTest
@testable import NucleoEntrenos

final class ServicioProgresionTests: XCTestCase {

    // Press banca del lunes: 4 × 8-10.
    private let pressBanca = ObjetivoEjercicio(
        series: 4, objetivoMin: 8, objetivoMax: 10, rirMin: 2, rirMax: 3, descansoSegundos: 150
    )

    private func serie(_ peso: Double, _ reps: Int, completada: Bool = true, calentamiento: Bool = false) -> SerieValor {
        SerieValor(peso: peso, repeticiones: reps, completada: completada, esCalentamiento: calentamiento)
    }

    private func serieTiempo(_ segundos: Int, peso: Double = 0, completada: Bool = true) -> SerieValor {
        SerieValor(peso: peso, repeticiones: 0, segundos: segundos, completada: completada)
    }

    // MARK: - Subir peso

    func testTodasLasSeriesEnElTopeSubeDosComaCincoEnBarra() {
        let anteriores = [serie(60, 10), serie(60, 10), serie(60, 10), serie(60, 10)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: pressBanca, material: .barra, tipo: .repeticiones
        )
        XCTAssertEqual(s.accion, .subirPeso(nuevoPeso: 62.5))
    }

    func testPorEncimaDelTopeTambienSube() {
        // 11 reps con un rango de 8-10 sigue siendo "en el tope o por encima".
        let anteriores = [serie(60, 11), serie(60, 10), serie(60, 12), serie(60, 10)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: pressBanca, material: .barra, tipo: .repeticiones
        )
        XCTAssertEqual(s.accion, .subirPeso(nuevoPeso: 62.5))
    }

    func testEnMancuernaSaltaAlSiguienteParDisponible() {
        let objetivo = ObjetivoEjercicio(series: 3, objetivoMin: 8, objetivoMax: 10)
        let anteriores = [serie(20, 10), serie(20, 10), serie(20, 10)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: objetivo, material: .mancuerna, tipo: .repeticiones
        )
        XCTAssertEqual(s.accion, .subirPeso(nuevoPeso: 22.5))
    }

    func testEnMaquinaUsaElPasoConfigurado() {
        let objetivo = ObjetivoEjercicio(series: 3, objetivoMin: 10, objetivoMax: 12)
        let reglas = ReglasIncremento(incrementoMaquina: 5)
        let anteriores = [serie(40, 12), serie(40, 12), serie(40, 12)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: objetivo, material: .maquina, tipo: .repeticiones, reglas: reglas
        )
        XCTAssertEqual(s.accion, .subirPeso(nuevoPeso: 45))
    }

    func testConPesosDistintosElPesoBaseEsElMinimo() {
        // Pirámide descendente, todas en el tope. La sugerencia parte del peso
        // que se sostuvo en todas las series, no del más alto.
        let anteriores = [serie(65, 10), serie(60, 10), serie(57.5, 10), serie(57.5, 10)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: pressBanca, material: .barra, tipo: .repeticiones
        )
        XCTAssertEqual(s.accion, .subirPeso(nuevoPeso: 60))
    }

    // MARK: - Mantener y sumar repeticiones

    func testEnMitadDelRangoMantieneElPeso() {
        let anteriores = [serie(60, 9), serie(60, 9), serie(60, 8), serie(60, 8)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: pressBanca, material: .barra, tipo: .repeticiones
        )
        // La serie más floja hizo 8, así que el siguiente objetivo es 9.
        XCTAssertEqual(s.accion, .mantener(peso: 60, objetivo: 9))
    }

    func testUnaSolaSerieFueraDelTopeImpideSubir() {
        let anteriores = [serie(60, 10), serie(60, 10), serie(60, 10), serie(60, 9)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: pressBanca, material: .barra, tipo: .repeticiones
        )
        XCTAssertEqual(s.accion, .mantener(peso: 60, objetivo: 10))
    }

    func testElSiguienteObjetivoNoPasaDelTope() {
        let anteriores = [serie(60, 10), serie(60, 10), serie(60, 10)]
        // Solo 3 de las 4 series objetivo: no sube, y el objetivo se queda en 10.
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: pressBanca, material: .barra, tipo: .repeticiones
        )
        XCTAssertEqual(s.accion, .mantener(peso: 60, objetivo: 10))
    }

    func testNoCompletarLasSeriesLoDiceEnElMotivo() {
        let anteriores = [serie(60, 10), serie(60, 10)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: pressBanca, material: .barra, tipo: .repeticiones
        )
        XCTAssertTrue(s.motivo.contains("2 de 4 series"), "motivo inesperado: \(s.motivo)")
    }

    // MARK: - Series que no cuentan

    func testLasSeriesSinCompletarNoCuentan() {
        let anteriores = [serie(60, 10), serie(60, 10), serie(60, 10), serie(60, 10, completada: false)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: pressBanca, material: .barra, tipo: .repeticiones
        )
        // Solo 3 series efectivas de 4: no sube.
        XCTAssertEqual(s.accion, .mantener(peso: 60, objetivo: 10))
    }

    func testElCalentamientoNoCuenta() {
        let anteriores = [
            serie(40, 15, calentamiento: true),
            serie(60, 10), serie(60, 10), serie(60, 10), serie(60, 10),
        ]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: pressBanca, material: .barra, tipo: .repeticiones
        )
        // Si el calentamiento contara, el peso base sería 40 y las reps 15.
        XCTAssertEqual(s.accion, .subirPeso(nuevoPeso: 62.5))
    }

    func testSoloCalentamientoEsComoNoTenerHistorial() {
        let anteriores = [serie(40, 15, calentamiento: true)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: pressBanca, material: .barra, tipo: .repeticiones
        )
        XCTAssertEqual(s.accion, .primeraVez)
    }

    // MARK: - Casos sin sugerencia

    func testSinHistorialEsPrimeraVez() {
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: [], objetivo: pressBanca, material: .barra, tipo: .repeticiones
        )
        XCTAssertEqual(s.accion, .primeraVez)
    }

    func testSeriesLibresNoTienenSugerencia() {
        // La rueda abdominal: 3 series, sin rango.
        let objetivo = ObjetivoEjercicio(series: 3, descansoSegundos: 60)
        let anteriores = [serie(0, 12), serie(0, 12), serie(0, 12)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: objetivo, material: .pesoCorporal, tipo: .repeticiones
        )
        XCTAssertEqual(s.accion, .sinRango)
    }

    // MARK: - Tiempo

    func testElIsometricoSubeSegundos() {
        // Isométrico de cuádriceps: 4 × 30-45 s.
        let objetivo = ObjetivoEjercicio(series: 4, objetivoMin: 30, objetivoMax: 45, descansoSegundos: 60)
        let anteriores = [serieTiempo(45), serieTiempo(45), serieTiempo(45), serieTiempo(45)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: objetivo, material: .maquina, tipo: .tiempo
        )
        XCTAssertEqual(s.accion, .subirTiempo(nuevosSegundos: 50))
    }

    func testElIsometricoAMediasMantiene() {
        let objetivo = ObjetivoEjercicio(series: 4, objetivoMin: 30, objetivoMax: 45, descansoSegundos: 60)
        let anteriores = [serieTiempo(40), serieTiempo(38), serieTiempo(35), serieTiempo(35)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: objetivo, material: .maquina, tipo: .tiempo
        )
        XCTAssertEqual(s.accion, .mantener(peso: 0, objetivo: 36))
    }

    func testElIsometricoRespetaElIncrementoDeTiempo() {
        let objetivo = ObjetivoEjercicio(series: 2, objetivoMin: 30, objetivoMax: 45)
        let reglas = ReglasIncremento(incrementoTiempo: 10)
        let anteriores = [serieTiempo(45), serieTiempo(45)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: objetivo, material: .maquina, tipo: .tiempo, reglas: reglas
        )
        XCTAssertEqual(s.accion, .subirTiempo(nuevosSegundos: 55))
    }

    // MARK: - Peso corporal y topes

    func testPesoCorporalEnElTopeSugiereAmpliarRango() {
        // Dominadas 4 × 6-8 sin lastre, todas a 8.
        let objetivo = ObjetivoEjercicio(series: 4, objetivoMin: 6, objetivoMax: 8)
        let anteriores = [serie(0, 8), serie(0, 8), serie(0, 8), serie(0, 8)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: objetivo, material: .pesoCorporal, tipo: .repeticiones
        )
        XCTAssertEqual(s.accion, .ampliarRango)
    }

    func testPesoCorporalConLastreSiSubeCarga() {
        let objetivo = ObjetivoEjercicio(series: 3, objetivoMin: 6, objetivoMax: 8)
        let anteriores = [serie(10, 8), serie(10, 8), serie(10, 8)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: objetivo, material: .pesoCorporal, tipo: .repeticiones
        )
        // Con lastre el material deja de ser el limitante: los discos suben.
        XCTAssertEqual(s.accion, .subirPeso(nuevoPeso: 12.5))
    }

    func testEnLaMancuernaMasPesadaSugiereAmpliarRango() {
        let objetivo = ObjetivoEjercicio(series: 3, objetivoMin: 8, objetivoMax: 10)
        let reglas = ReglasIncremento(mancuernasDisponibles: [20, 22.5, 25])
        let anteriores = [serie(25, 10), serie(25, 10), serie(25, 10)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: objetivo, material: .mancuerna, tipo: .repeticiones, reglas: reglas
        )
        XCTAssertEqual(s.accion, .ampliarRango)
    }

    // MARK: - Rango de un solo valor

    func testRangoDeUnSoloValorFunciona() {
        // Pájaros 3 × 15.
        let objetivo = ObjetivoEjercicio(series: 3, objetivoMin: 15, objetivoMax: 15)
        let anteriores = [serie(8, 15), serie(8, 15), serie(8, 15)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: objetivo, material: .mancuerna, tipo: .repeticiones
        )
        XCTAssertEqual(s.accion, .subirPeso(nuevoPeso: 10))
    }

    // MARK: - Series de descarga y series extra

    func testUnaSerieDeDescargaNoArrastraLaSugerenciaHaciaAbajo() {
        // 3×8-10 completas a 70 y una cuarta de descarga a 50. Juzgando TODAS
        // las efectivas, el peso base era el mínimo (50) y la sugerencia salía
        // "sube a 52,5": aplicada a las series pendientes, una regresión de
        // 17,5 kg en el ejercicio principal de un solo toque.
        let objetivo = ObjetivoEjercicio(series: 3, objetivoMin: 8, objetivoMax: 10)
        let anteriores = [serie(70, 10), serie(70, 10), serie(70, 10), serie(50, 12)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: objetivo, material: .barra, tipo: .repeticiones
        )
        XCTAssertEqual(s.accion, .subirPeso(nuevoPeso: 72.5))
    }

    func testUnaSerieDeDescargaFlojaNoBloqueaLaProgresion() {
        // La misma cuarta serie, esta vez a 50×7. Antes hacía falso
        // `todasEnElTope` y quien había completado 3×10 a 70 no progresaba
        // nunca.
        let objetivo = ObjetivoEjercicio(series: 3, objetivoMin: 8, objetivoMax: 10)
        let anteriores = [serie(70, 10), serie(70, 10), serie(70, 10), serie(50, 7)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: objetivo, material: .barra, tipo: .repeticiones
        )
        XCTAssertEqual(s.accion, .subirPeso(nuevoPeso: 72.5))
    }

    func testLaDescargaDaIgualDondeEsteEnElOrden() {
        let objetivo = ObjetivoEjercicio(series: 3, objetivoMin: 8, objetivoMax: 10)
        let anteriores = [serie(50, 12), serie(70, 10), serie(70, 10), serie(70, 10)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: objetivo, material: .barra, tipo: .repeticiones
        )
        XCTAssertEqual(s.accion, .subirPeso(nuevoPeso: 72.5))
    }

    func testUnaSerieExtraFallidaAlMismoPesoNoBloquea() {
        // 3×10 hechas y una cuarta que se cayó a 6. Lo pedido estaba
        // completo, así que toca subir.
        let objetivo = ObjetivoEjercicio(series: 3, objetivoMin: 8, objetivoMax: 10)
        let anteriores = [serie(70, 10), serie(70, 10), serie(70, 10), serie(70, 6)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: objetivo, material: .barra, tipo: .repeticiones
        )
        XCTAssertEqual(s.accion, .subirPeso(nuevoPeso: 72.5))
    }

    func testDentroDeLasSeriesDeTrabajoElPesoBaseSigueSiendoElMinimo() {
        // La decisión documentada no cambia: con una pirámide descendente de
        // tres series y un objetivo de tres, las tres son de trabajo y el
        // único peso que se sostuvo en todas es el menor.
        let objetivo = ObjetivoEjercicio(series: 3, objetivoMin: 8, objetivoMax: 10)
        let anteriores = [serie(70, 10), serie(65, 10), serie(60, 10)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: objetivo, material: .barra, tipo: .repeticiones
        )
        XCTAssertEqual(s.accion, .subirPeso(nuevoPeso: 62.5))
    }

    func testEnIsometricoLaSerieCortaExtraNoBloquea() {
        // Sin peso que ordenar, manda el logro: de 60, 60, 60 y 30 se juzgan
        // las tres de 60 esté la corta donde esté.
        let objetivo = ObjetivoEjercicio(series: 3, objetivoMin: 45, objetivoMax: 60)
        let anteriores = [serieTiempo(30), serieTiempo(60), serieTiempo(60), serieTiempo(60)]
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: objetivo, material: .maquina, tipo: .tiempo
        )
        XCTAssertEqual(s.accion, .subirTiempo(nuevosSegundos: 65))
    }

    func testConMenosSeriesQueElObjetivoSeJuzganTodas() {
        let objetivo = ObjetivoEjercicio(series: 4, objetivoMin: 8, objetivoMax: 10)
        let anteriores = [serie(70, 10), serie(70, 10)]
        let deTrabajo = ServicioProgresion.seriesDeTrabajo(anteriores, series: 4, tipo: .repeticiones)
        XCTAssertEqual(deTrabajo.count, 2)
        let s = ServicioProgresion.sugerencia(
            seriesAnteriores: anteriores, objetivo: objetivo, material: .barra, tipo: .repeticiones
        )
        XCTAssertEqual(s.accion, .mantener(peso: 70, objetivo: 10))
    }

    // MARK: - Formato

    func testElTextoDePesoUsaComaDecimal() {
        XCTAssertEqual(ServicioProgresion.textoPeso(62.5), "62,5 kg")
        XCTAssertEqual(ServicioProgresion.textoPeso(60), "60 kg")
    }
}
