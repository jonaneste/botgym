import XCTest
@testable import NucleoEntrenos

final class ServicioRecordsTests: XCTestCase {

    private let calendario = CalendarioEntrenos.es

    private func fecha(_ dia: Int, _ mes: Int = 10, _ año: Int = 2026) -> Date {
        var componentes = DateComponents()
        componentes.year = año
        componentes.month = mes
        componentes.day = dia
        componentes.hour = 18
        return calendario.date(from: componentes)!
    }

    private func serie(_ peso: Double, _ reps: Int, completada: Bool = true, calentamiento: Bool = false) -> SerieValor {
        SerieValor(peso: peso, repeticiones: reps, completada: completada, esCalentamiento: calentamiento)
    }

    // MARK: - Cálculo de récords

    func testPesoMaximoSeQuedaConElMasAlto() throws {
        let sesiones = [
            SesionEjercicio(fecha: fecha(1), series: [serie(60, 10), serie(60, 9)]),
            SesionEjercicio(fecha: fecha(8), series: [serie(65, 8), serie(62.5, 8)]),
            SesionEjercicio(fecha: fecha(15), series: [serie(62.5, 10)]),
        ]
        let r = ServicioRecords.records(de: sesiones, tipo: .repeticiones)
        XCTAssertEqual(try XCTUnwrap(r.pesoMaximo), 65, accuracy: 0.0001)
        XCTAssertEqual(r.fechaPesoMaximo, fecha(8))
    }

    func testMejorUnRMPuedeSerDeOtraSesionQueElPesoMaximo() throws {
        // 65 × 8 → 82,3. 62,5 × 12 → 87,5. El 1RM récord no coincide con el
        // peso récord, y eso es correcto.
        let sesiones = [
            SesionEjercicio(fecha: fecha(1), series: [serie(65, 8)]),
            SesionEjercicio(fecha: fecha(8), series: [serie(62.5, 12)]),
        ]
        let r = ServicioRecords.records(de: sesiones, tipo: .repeticiones)
        XCTAssertEqual(try XCTUnwrap(r.pesoMaximo), 65, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(r.mejorUnRM), 87.5, accuracy: 0.001)
        XCTAssertEqual(r.fechaMejorUnRM, fecha(8))
    }

    func testMejorVolumenDeSesion() throws {
        let sesiones = [
            // 60×10 + 60×10 = 1200
            SesionEjercicio(fecha: fecha(1), series: [serie(60, 10), serie(60, 10)]),
            // 65×8 + 65×8 + 65×8 = 1560
            SesionEjercicio(fecha: fecha(8), series: [serie(65, 8), serie(65, 8), serie(65, 8)]),
        ]
        let r = ServicioRecords.records(de: sesiones, tipo: .repeticiones)
        XCTAssertEqual(try XCTUnwrap(r.mejorVolumenSesion), 1560, accuracy: 0.0001)
        XCTAssertEqual(r.fechaMejorVolumen, fecha(8))
    }

    func testLasSeriesSinCompletarNoCuentanParaRecords() throws {
        let sesiones = [
            SesionEjercicio(fecha: fecha(1), series: [serie(60, 10), serie(100, 10, completada: false)]),
        ]
        let r = ServicioRecords.records(de: sesiones, tipo: .repeticiones)
        XCTAssertEqual(try XCTUnwrap(r.pesoMaximo), 60, accuracy: 0.0001)
    }

    func testElCalentamientoNoCuentaParaRecords() throws {
        let sesiones = [
            SesionEjercicio(fecha: fecha(1), series: [serie(80, 20, calentamiento: true), serie(60, 10)]),
        ]
        let r = ServicioRecords.records(de: sesiones, tipo: .repeticiones)
        XCTAssertEqual(try XCTUnwrap(r.pesoMaximo), 60, accuracy: 0.0001)
    }

    func testSinHistorialLosRecordsEstanVacios() {
        let r = ServicioRecords.records(de: [], tipo: .repeticiones)
        XCTAssertTrue(r.estaVacio)
    }

    func testPesoCorporalSinLastreNoGeneraRecordDePeso() {
        // Dominadas sin lastre: no tiene sentido un récord de 0 kg.
        let sesiones = [SesionEjercicio(fecha: fecha(1), series: [serie(0, 10)])]
        let r = ServicioRecords.records(de: sesiones, tipo: .repeticiones)
        XCTAssertNil(r.pesoMaximo)
    }

    func testLosEjerciciosDeTiempoNoTienenUnRM() {
        let sesiones = [
            SesionEjercicio(fecha: fecha(1), series: [
                SerieValor(peso: 0, segundos: 40, completada: true),
            ]),
        ]
        let r = ServicioRecords.records(de: sesiones, tipo: .tiempo)
        XCTAssertNil(r.mejorUnRM)
        XCTAssertEqual(r.mejorTiempo, 40)
    }

    func testMejorTiempoSeQuedaConElMasLargo() {
        let sesiones = [
            SesionEjercicio(fecha: fecha(1), series: [SerieValor(peso: 0, segundos: 35, completada: true)]),
            SesionEjercicio(fecha: fecha(8), series: [SerieValor(peso: 0, segundos: 45, completada: true)]),
            SesionEjercicio(fecha: fecha(15), series: [SerieValor(peso: 0, segundos: 40, completada: true)]),
        ]
        let r = ServicioRecords.records(de: sesiones, tipo: .tiempo)
        XCTAssertEqual(r.mejorTiempo, 45)
        XCTAssertEqual(r.fechaMejorTiempo, fecha(8))
    }

    // MARK: - Detección durante el entreno

    func testUnaSerieMasPesadaBateElRecordDePeso() throws {
        var previos = RecordsEjercicio()
        previos.pesoMaximo = 60
        previos.mejorUnRM = 78

        let batidos = ServicioRecords.recordsBatidos(
            por: serie(65, 8), tipo: .repeticiones, frenteA: previos
        )
        let peso = try XCTUnwrap(batidos.first { $0.tipo == .peso })
        XCTAssertEqual(peso.valor, 65, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(peso.anterior), 60, accuracy: 0.0001)
    }

    func testUnaSerieIgualAlRecordNoLoBate() {
        var previos = RecordsEjercicio()
        previos.pesoMaximo = 60
        previos.mejorUnRM = 1000  // alto, para aislar el récord de peso

        let batidos = ServicioRecords.recordsBatidos(
            por: serie(60, 8), tipo: .repeticiones, frenteA: previos
        )
        XCTAssertTrue(batidos.isEmpty, "llegaron \(batidos)")
    }

    func testPuedeBatirPesoYUnRMALaVez() {
        let batidos = ServicioRecords.recordsBatidos(
            por: serie(70, 10), tipo: .repeticiones, frenteA: RecordsEjercicio()
        )
        XCTAssertEqual(Set(batidos.map(\.tipo)), [.peso, .unRM])
    }

    func testUnaSerieSinCompletarNoBateNada() {
        let batidos = ServicioRecords.recordsBatidos(
            por: serie(200, 10, completada: false), tipo: .repeticiones, frenteA: RecordsEjercicio()
        )
        XCTAssertTrue(batidos.isEmpty)
    }

    func testUnaSerieDeCalentamientoNoBateNada() {
        let batidos = ServicioRecords.recordsBatidos(
            por: serie(200, 10, calentamiento: true), tipo: .repeticiones, frenteA: RecordsEjercicio()
        )
        XCTAssertTrue(batidos.isEmpty)
    }

    func testEnTiempoSoloSePuedeBatirElTiempo() {
        var previos = RecordsEjercicio()
        previos.mejorTiempo = 40
        let batidos = ServicioRecords.recordsBatidos(
            por: SerieValor(peso: 0, segundos: 50, completada: true),
            tipo: .tiempo,
            frenteA: previos
        )
        XCTAssertEqual(batidos.map(\.tipo), [.tiempo])
        XCTAssertEqual(batidos[0].valor, 50, accuracy: 0.0001)
    }

    func testElRecordDeVolumenSoloSaltaSiSupera() throws {
        var previos = RecordsEjercicio()
        previos.mejorVolumenSesion = 1500

        XCTAssertNil(ServicioRecords.recordDeVolumen(volumenSesion: 1400, frenteA: previos))
        XCTAssertNil(ServicioRecords.recordDeVolumen(volumenSesion: 1500, frenteA: previos))
        let batido = try XCTUnwrap(ServicioRecords.recordDeVolumen(volumenSesion: 1600, frenteA: previos))
        XCTAssertEqual(batido.valor, 1600, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(batido.anterior), 1500, accuracy: 0.0001)
    }

    func testElVolumenCeroNoEsRecord() {
        XCTAssertNil(ServicioRecords.recordDeVolumen(volumenSesion: 0, frenteA: RecordsEjercicio()))
    }

    // MARK: - Puntos de la gráfica

    func testLosPuntosVanOrdenadosPorFecha() {
        let sesiones = [
            SesionEjercicio(fecha: fecha(15), series: [serie(62.5, 10)]),
            SesionEjercicio(fecha: fecha(1), series: [serie(60, 10)]),
            SesionEjercicio(fecha: fecha(8), series: [serie(65, 8)]),
        ]
        let puntos = ServicioRecords.puntosGrafica(de: sesiones, tipo: .repeticiones)
        XCTAssertEqual(puntos.map(\.fecha), [fecha(1), fecha(8), fecha(15)])
    }

    func testLasSesionesSinSeriesEfectivasNoDanPunto() {
        let sesiones = [
            SesionEjercicio(fecha: fecha(1), series: [serie(60, 10, completada: false)]),
            SesionEjercicio(fecha: fecha(8), series: [serie(60, 10)]),
        ]
        let puntos = ServicioRecords.puntosGrafica(de: sesiones, tipo: .repeticiones)
        XCTAssertEqual(puntos.count, 1)
        XCTAssertEqual(puntos[0].fecha, fecha(8))
    }

    func testElPuntoLlevaPesoMaximoYUnRMDeLaSesion() throws {
        let sesiones = [SesionEjercicio(fecha: fecha(1), series: [serie(60, 10), serie(65, 6)])]
        let puntos = ServicioRecords.puntosGrafica(de: sesiones, tipo: .repeticiones)
        let punto = try XCTUnwrap(puntos.first)
        XCTAssertEqual(punto.pesoMaximo, 65, accuracy: 0.0001)
        // 60×10 → 80; 65×6 → 78. El mejor es 80.
        XCTAssertEqual(try XCTUnwrap(punto.unRMEstimado), 80, accuracy: 0.001)
        XCTAssertEqual(punto.volumen, 60 * 10 + 65 * 6, accuracy: 0.0001)
    }

    func testEnTiempoElPuntoNoLlevaUnRMPeroSiSegundos() {
        let sesiones = [
            SesionEjercicio(fecha: fecha(1), series: [
                SerieValor(peso: 0, segundos: 40, completada: true),
                SerieValor(peso: 0, segundos: 45, completada: true),
            ]),
        ]
        let puntos = ServicioRecords.puntosGrafica(de: sesiones, tipo: .tiempo)
        XCTAssertNil(puntos[0].unRMEstimado)
        XCTAssertEqual(puntos[0].segundosMaximo, 45)
    }
}

final class IncorporarRecordsTests: XCTestCase {

    private let ahora = Date(timeIntervalSince1970: 1_790_000_000)

    private func serie(_ peso: Double, _ reps: Int, completada: Bool = true) -> SerieValor {
        SerieValor(peso: peso, repeticiones: reps, completada: completada)
    }

    func testIncorporarSubeElPesoMaximo() throws {
        var previos = RecordsEjercicio()
        previos.pesoMaximo = 60
        let nuevos = ServicioRecords.incorporando(serie(65, 8), tipo: .repeticiones, en: previos, fecha: ahora)
        XCTAssertEqual(try XCTUnwrap(nuevos.pesoMaximo), 65, accuracy: 0.0001)
        XCTAssertEqual(nuevos.fechaPesoMaximo, ahora)
    }

    func testIncorporarNoBajaUnRecordExistente() throws {
        var previos = RecordsEjercicio()
        previos.pesoMaximo = 80
        let nuevos = ServicioRecords.incorporando(serie(60, 8), tipo: .repeticiones, en: previos, fecha: ahora)
        XCTAssertEqual(try XCTUnwrap(nuevos.pesoMaximo), 80, accuracy: 0.0001)
    }

    func testUnaSerieSinCompletarNoIncorporaNada() {
        let nuevos = ServicioRecords.incorporando(
            serie(200, 10, completada: false), tipo: .repeticiones, en: RecordsEjercicio(), fecha: ahora
        )
        XCTAssertTrue(nuevos.estaVacio)
    }

    func testTrasIncorporarElMismoRecordYaNoSeBate() {
        // Es lo que evita que el aviso de récord salte dos veces con la misma
        // serie durante el entreno.
        let primera = serie(65, 8)
        var records = RecordsEjercicio()
        records.pesoMaximo = 60
        records.mejorUnRM = 70

        let batidos = ServicioRecords.recordsBatidos(por: primera, tipo: .repeticiones, frenteA: records)
        XCTAssertFalse(batidos.isEmpty)

        records = ServicioRecords.incorporando(primera, tipo: .repeticiones, en: records, fecha: ahora)
        let segundaVez = ServicioRecords.recordsBatidos(por: primera, tipo: .repeticiones, frenteA: records)
        XCTAssertTrue(segundaVez.isEmpty, "llegaron \(segundaVez)")
    }

    func testIncorporarEnTiempoSoloTocaElTiempo() {
        let previos = RecordsEjercicio()
        let nuevos = ServicioRecords.incorporando(
            SerieValor(peso: 0, segundos: 50, completada: true),
            tipo: .tiempo, en: previos, fecha: ahora
        )
        XCTAssertEqual(nuevos.mejorTiempo, 50)
        XCTAssertNil(nuevos.mejorUnRM)
        XCTAssertNil(nuevos.pesoMaximo)
    }
}
