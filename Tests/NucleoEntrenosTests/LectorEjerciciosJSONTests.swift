import XCTest
@testable import NucleoEntrenos

final class LectorEjerciciosJSONTests: XCTestCase {

    func testSeLeeUnCatalogo() throws {
        let json = """
        { "version": 1, "ejercicios": [
          { "nombre": "Remo en T", "grupo": "espalda", "gruposSecundarios": ["biceps"], "material": "barra", "notas": "Pecho apoyado." },
          { "nombre": "Plancha lateral", "grupo": "core", "tipo": "tiempo" }
        ] }
        """
        let leidos = try LectorEjerciciosJSON.leer(json)
        XCTAssertEqual(leidos.count, 2)
        XCTAssertEqual(leidos[0].nombre, "Remo en T")
        XCTAssertEqual(leidos[0].grupoPrincipal, "espalda")
        XCTAssertEqual(leidos[0].gruposSecundarios, ["biceps"])
        XCTAssertEqual(leidos[0].material, "barra")
        XCTAssertEqual(leidos[0].notas, "Pecho apoyado.")
        XCTAssertEqual(leidos[1].tipoRegistro, "tiempo")
        XCTAssertNil(leidos[1].material)
    }

    func testElGrupoEsObligatorio() {
        // Al contrario que en una rutina: allí el ejercicio puede existir ya,
        // aquí no hay a qué agarrarse y sin grupo entraría sin contar en nada.
        let json = "{ \"version\": 1, \"ejercicios\": [{ \"nombre\": \"X\" }] }"
        XCTAssertThrowsError(try LectorEjerciciosJSON.leer(json)) { error in
            let fallo = error as? ErrorImportacion
            XCTAssertEqual(fallo?.ruta, "ejercicios[0].grupo")
            XCTAssertTrue(fallo?.mensaje.contains("series semanales") ?? false, fallo?.mensaje ?? "")
        }
    }

    func testUnNombreVacioSeRechaza() {
        let json = "{ \"version\": 1, \"ejercicios\": [{ \"nombre\": \"  \", \"grupo\": \"pecho\" }] }"
        XCTAssertThrowsError(try LectorEjerciciosJSON.leer(json)) { error in
            XCTAssertEqual((error as? ErrorImportacion)?.ruta, "ejercicios[0].nombre")
        }
    }

    func testUnaListaVaciaSeRechaza() {
        XCTAssertThrowsError(try LectorEjerciciosJSON.leer("{ \"version\": 1, \"ejercicios\": [] }"))
    }

    func testDemasiadosSeRechazan() {
        let uno = "{ \"nombre\": \"X\", \"grupo\": \"pecho\" }"
        let lista = Array(repeating: uno, count: 400).joined(separator: ",")
        XCTAssertThrowsError(try LectorEjerciciosJSON.leer("{ \"version\": 1, \"ejercicios\": [\(lista)] }"))
    }

    func testUnaVersionDistintaSeRechaza() {
        let json = "{ \"version\": 9, \"ejercicios\": [{ \"nombre\": \"X\", \"grupo\": \"pecho\" }] }"
        XCTAssertThrowsError(try LectorEjerciciosJSON.leer(json)) { error in
            XCTAssertEqual((error as? ErrorImportacion)?.ruta, "version")
        }
    }

    // MARK: - Que no se confunda con los otros formatos

    func testLosOtrosTresFormatosNoSeLeenComoCatalogo() {
        let rutinas = "{ \"version\": 1, \"rutinas\": [{ \"nombre\": \"R\", \"ejercicios\": [{ \"nombre\": \"E\", \"series\": 3 }] }] }"
        let plan = "{ \"version\": 1, \"plan\": { \"nombre\": \"P\", \"dias\": [{ \"fecha\": \"2026-10-13\", \"tipo\": \"gimnasio\" }] } }"
        let borrado = "{ \"version\": 1, \"borrar\": { \"carpetas\": [\"X\"] } }"
        for json in [rutinas, plan, borrado] {
            XCTAssertThrowsError(try LectorEjerciciosJSON.leer(json))
        }
    }

    func testUnCatalogoNoSeLeeComoNingunOtroFormato() {
        let json = "{ \"version\": 1, \"ejercicios\": [{ \"nombre\": \"X\", \"grupo\": \"pecho\" }] }"
        XCTAssertThrowsError(try LectorPlanJSON.leer(json))
        XCTAssertThrowsError(try LectorBorradoJSON.leer(json))
        // El de rutinas también: su clave es «rutinas», no «ejercicios».
        XCTAssertThrowsError(try LectorRutinasJSON.leer(json))
    }
}
