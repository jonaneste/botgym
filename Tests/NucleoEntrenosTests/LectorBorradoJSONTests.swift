import XCTest
@testable import NucleoEntrenos

final class LectorBorradoJSONTests: XCTestCase {

    func testSeLeeUnBorradoCompleto() throws {
        let json = """
        { "version": 1, "borrar": {
            "carpetas": ["Media maratón"],
            "rutinas": ["Lunes – Empuje"],
            "entrenosVacios": true
        } }
        """
        let borrado = try LectorBorradoJSON.leer(json)
        XCTAssertEqual(borrado.carpetas, ["Media maratón"])
        XCTAssertEqual(borrado.rutinas, ["Lunes – Empuje"])
        XCTAssertTrue(borrado.entrenosVacios)
        XCTAssertFalse(borrado.estaVacio)
    }

    func testUnaSolaClaveBasta() throws {
        let json = "{ \"version\": 1, \"borrar\": { \"carpetas\": [\"Vieja\"] } }"
        let borrado = try LectorBorradoJSON.leer(json)
        XCTAssertEqual(borrado.carpetas, ["Vieja"])
        XCTAssertTrue(borrado.rutinas.isEmpty)
        XCTAssertFalse(borrado.entrenosVacios)
    }

    func testSeLimpianLosEspacios() throws {
        let json = "{ \"version\": 1, \"borrar\": { \"rutinas\": [\"  Lunes  \"] } }"
        XCTAssertEqual(try LectorBorradoJSON.leer(json).rutinas, ["Lunes"])
    }

    func testUnBorradoQueNoNombraNadaSeRechaza() {
        // Casi siempre es una clave mal escrita. Aceptarlo en silencio se
        // llevaría el archivo de la bandeja sin hacer lo que pedía.
        let json = "{ \"version\": 1, \"borrar\": {} }"
        XCTAssertThrowsError(try LectorBorradoJSON.leer(json)) { error in
            XCTAssertEqual((error as? ErrorImportacion)?.ruta, "borrar")
        }
    }

    func testUnNombreVacioSeRechaza() {
        // Un nombre vacío podría casar con cualquier cosa según cómo se
        // compare, y en un borrado eso no se puede permitir.
        let json = "{ \"version\": 1, \"borrar\": { \"carpetas\": [\"\"] } }"
        XCTAssertThrowsError(try LectorBorradoJSON.leer(json)) { error in
            XCTAssertEqual((error as? ErrorImportacion)?.ruta, "borrar.carpetas[0]")
        }
    }

    func testUnNombreQueNoEsTextoSeRechaza() {
        let json = "{ \"version\": 1, \"borrar\": { \"rutinas\": [3] } }"
        XCTAssertThrowsError(try LectorBorradoJSON.leer(json)) { error in
            XCTAssertEqual((error as? ErrorImportacion)?.ruta, "borrar.rutinas[0]")
        }
    }

    func testDemasiadosNombresSeRechazan() {
        let lista = (0..<60).map { "\"R\($0)\"" }.joined(separator: ",")
        let json = "{ \"version\": 1, \"borrar\": { \"rutinas\": [\(lista)] } }"
        XCTAssertThrowsError(try LectorBorradoJSON.leer(json))
    }

    func testEntrenosVaciosTieneQueSerBooleano() {
        let json = "{ \"version\": 1, \"borrar\": { \"entrenosVacios\": \"sí\" } }"
        XCTAssertThrowsError(try LectorBorradoJSON.leer(json)) { error in
            XCTAssertEqual((error as? ErrorImportacion)?.ruta, "borrar.entrenosVacios")
        }
    }

    func testEntrenosVaciosEnFalsoNoBastaPorSiSolo() {
        let json = "{ \"version\": 1, \"borrar\": { \"entrenosVacios\": false } }"
        XCTAssertThrowsError(try LectorBorradoJSON.leer(json))
    }

    func testUnaVersionDistintaSeRechaza() {
        let json = "{ \"version\": 2, \"borrar\": { \"carpetas\": [\"X\"] } }"
        XCTAssertThrowsError(try LectorBorradoJSON.leer(json)) { error in
            XCTAssertEqual((error as? ErrorImportacion)?.ruta, "version")
        }
    }

    // MARK: - Que no se confunda con los otros dos formatos

    func testUnJsonDeRutinasNoSeLeeComoBorrado() {
        let json = "{ \"version\": 1, \"rutinas\": [{ \"nombre\": \"R\", \"ejercicios\": [{ \"nombre\": \"E\", \"series\": 3 }] }] }"
        XCTAssertThrowsError(try LectorBorradoJSON.leer(json)) { error in
            XCTAssertEqual((error as? ErrorImportacion)?.ruta, "borrar")
        }
    }

    func testUnJsonDePlanNoSeLeeComoBorrado() {
        let json = "{ \"version\": 1, \"plan\": { \"nombre\": \"P\", \"dias\": [{ \"fecha\": \"2026-10-13\", \"tipo\": \"gimnasio\" }] } }"
        XCTAssertThrowsError(try LectorBorradoJSON.leer(json)) { error in
            XCTAssertEqual((error as? ErrorImportacion)?.ruta, "borrar")
        }
    }

    func testUnJsonDeBorradoNoSeLeeComoRutinasNiComoPlan() {
        // Los tres comparten carpeta: el que borra no se puede colar por los
        // otros dos lectores, ni al revés.
        let json = "{ \"version\": 1, \"borrar\": { \"carpetas\": [\"X\"] } }"
        XCTAssertThrowsError(try LectorRutinasJSON.leer(json))
        XCTAssertThrowsError(try LectorPlanJSON.leer(json))
    }
}
