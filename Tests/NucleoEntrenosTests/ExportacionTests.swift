import XCTest
@testable import NucleoEntrenos

final class GeneradorCSVTests: XCTestCase {

    private let fecha = Date(timeIntervalSince1970: 1_790_000_000)

    private func exportacionDePrueba(
        notasEntreno: String = "",
        notasEjercicio: String = "",
        peso: Double = 62.5,
        reps: Int = 8
    ) -> ExportacionCompleta {
        ExportacionCompleta(
            generado: fecha,
            ejercicios: [],
            carpetas: [],
            entrenos: [
                EntrenoExportado(
                    id: UUID(), nombre: "Lunes – Empuje", fechaInicio: fecha, fechaFin: nil,
                    rutinaOrigen: "Lunes – Empuje", notas: notasEntreno,
                    molestiaHombro: 3, molestiaRodilla: nil,
                    ejercicios: [
                        EjercicioEntrenoExportado(
                            nombre: "Press banca con barra", grupoPrincipal: "pecho",
                            tipoRegistro: "repeticiones", notas: notasEjercicio, superserie: nil,
                            series: [
                                SerieExportada(orden: 0, peso: peso, repeticiones: reps, segundos: nil, rir: 2, calentamiento: false),
                            ]
                        ),
                    ]
                ),
            ]
        )
    }

    func testLaCabeceraLlevaTodasLasColumnas() {
        let csv = GeneradorCSV.generar(exportacionDePrueba(), conBOM: false)
        let primera = csv.components(separatedBy: "\r\n")[0]
        XCTAssertEqual(primera, GeneradorCSV.columnas.joined(separator: ";"))
    }

    func testUnaFilaPorSerie() {
        let csv = GeneradorCSV.generar(exportacionDePrueba(), conBOM: false)
        let lineas = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        XCTAssertEqual(lineas.count, 2, "cabecera + una serie")
    }

    func testElBOMVaDelante() {
        XCTAssertTrue(GeneradorCSV.generar(exportacionDePrueba()).hasPrefix("\u{FEFF}"))
        XCTAssertFalse(GeneradorCSV.generar(exportacionDePrueba(), conBOM: false).hasPrefix("\u{FEFF}"))
    }

    func testLosDecimalesVanConComa() {
        XCTAssertEqual(GeneradorCSV.decimal(62.5), "62,5")
        XCTAssertEqual(GeneradorCSV.decimal(60), "60", "sin decimales sobrantes")
        XCTAssertEqual(GeneradorCSV.decimal(0), "0")
    }

    func testElVolumenSaleCalculado() {
        let csv = GeneradorCSV.generar(exportacionDePrueba(peso: 60, reps: 10), conBOM: false)
        let fila = csv.components(separatedBy: "\r\n")[1]
        let campos = fila.components(separatedBy: ";")
        let indiceVolumen = GeneradorCSV.columnas.firstIndex(of: "volumen_kg")!
        XCTAssertEqual(campos[indiceVolumen], "600")
    }

    func testUnCampoConPuntoYComaSeEntrecomilla() {
        let csv = GeneradorCSV.generar(
            exportacionDePrueba(notasEntreno: "Hombro raro; parar si duele"),
            conBOM: false
        )
        XCTAssertTrue(csv.contains("\"Hombro raro; parar si duele\""), csv)
    }

    func testLasComillasInternasSeDuplican() {
        XCTAssertEqual(GeneradorCSV.escapar("dijo \"vale\""), "\"dijo \"\"vale\"\"\"")
    }

    func testUnSaltoDeLineaEnLasNotasSeEntrecomilla() {
        let escapado = GeneradorCSV.escapar("primera\nsegunda")
        XCTAssertTrue(escapado.hasPrefix("\"") && escapado.hasSuffix("\""), escapado)
    }

    func testUnCampoNormalNoSeEntrecomilla() {
        XCTAssertEqual(GeneradorCSV.escapar("Press banca"), "Press banca")
    }

    func testLosCamposVaciosSalenVacios() {
        let csv = GeneradorCSV.generar(exportacionDePrueba(), conBOM: false)
        let campos = csv.components(separatedBy: "\r\n")[1].components(separatedBy: ";")
        let indiceRodilla = GeneradorCSV.columnas.firstIndex(of: "molestia_rodilla")!
        XCTAssertEqual(campos[indiceRodilla], "")
    }

    func testTodasLasFilasTienenElMismoNumeroDeCampos() {
        let csv = GeneradorCSV.generar(
            exportacionDePrueba(notasEntreno: "con; puntoycoma", notasEjercicio: "con \"comillas\""),
            conBOM: false
        )
        let lineas = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        // Se cuenta a mano respetando el entrecomillado, como haría un parser.
        for linea in lineas {
            XCTAssertEqual(contarCampos(linea), GeneradorCSV.columnas.count, linea)
        }
    }

    /// Cuenta campos respetando las comillas, igual que un lector de CSV.
    private func contarCampos(_ linea: String) -> Int {
        var campos = 1
        var dentroDeComillas = false
        var anterior: Character?
        for caracter in linea {
            if caracter == "\"" {
                // Una comilla duplicada es literal, no abre ni cierra.
                if anterior == "\"" && dentroDeComillas {
                    anterior = nil
                    continue
                }
                dentroDeComillas.toggle()
            } else if caracter == ";" && !dentroDeComillas {
                campos += 1
            }
            anterior = caracter
        }
        return campos
    }
}

final class SerializadorExportacionTests: XCTestCase {

    func testIdaYVueltaConservaElContenido() throws {
        let original = ExportacionCompleta(
            generado: Date(timeIntervalSince1970: 1_790_000_000),
            ejercicios: [
                EjercicioExportado(
                    id: UUID(), nombre: "Press banca", grupoPrincipal: "pecho",
                    gruposSecundarios: ["triceps"], material: "barra",
                    tipoRegistro: "repeticiones", esPersonalizado: false, notas: ""
                ),
            ],
            carpetas: [],
            entrenos: []
        )
        let datos = try SerializadorExportacion.json(original)
        let vuelta = try SerializadorExportacion.leerJSON(datos)
        XCTAssertEqual(vuelta, original)
    }

    func testDosExportacionesIgualesDanElMismoArchivo() throws {
        let exportacion = ExportacionCompleta(
            generado: Date(timeIntervalSince1970: 1_790_000_000),
            ejercicios: [], carpetas: [], entrenos: []
        )
        let primera = try SerializadorExportacion.json(exportacion)
        let segunda = try SerializadorExportacion.json(exportacion)
        XCTAssertEqual(primera, segunda, "las claves van ordenadas, así que el archivo es estable")
    }

    func testElTextoDeRepsCoincideConLoQueEsperaElImportador() throws {
        XCTAssertEqual(SerializadorExportacion.textoReps(min: 8, max: 10, esTiempo: false), "8-10")
        XCTAssertEqual(SerializadorExportacion.textoReps(min: 15, max: 15, esTiempo: false), "15")
        XCTAssertEqual(SerializadorExportacion.textoReps(min: 30, max: 45, esTiempo: true), "30-45s")
        XCTAssertNil(SerializadorExportacion.textoReps(min: nil, max: nil, esTiempo: false))

        // Y lo que se exporta, se vuelve a importar igual.
        let texto = try XCTUnwrap(SerializadorExportacion.textoReps(min: 30, max: 45, esTiempo: true))
        let leido = try LectorRutinasJSON.parsearRango(texto, ruta: "r")
        XCTAssertEqual(leido, .init(minimo: 30, maximo: 45, esTiempo: true))
    }

    func testElTextoDeRIRCoincideConLoQueEsperaElImportador() throws {
        XCTAssertEqual(SerializadorExportacion.textoRIR(min: 2, max: 3), "2-3")
        XCTAssertEqual(SerializadorExportacion.textoRIR(min: 2, max: 2), "2")
        XCTAssertNil(SerializadorExportacion.textoRIR(min: nil, max: nil))

        let texto = try XCTUnwrap(SerializadorExportacion.textoRIR(min: 2, max: 3))
        let leido = try LectorRutinasJSON.parsearRango(texto, ruta: "r", permitirSegundos: false, maximoPermitido: 10)
        XCTAssertEqual(leido.minimo, 2)
        XCTAssertEqual(leido.maximo, 3)
    }
}
