import XCTest
@testable import NucleoEntrenos

final class LectorRutinasJSONTests: XCTestCase {

    // MARK: - Camino bueno

    private let jsonValido = """
    {
      "version": 1,
      "carpeta": "Bloque otoño",
      "rutinas": [
        {
          "nombre": "Lunes – Empuje",
          "notas": "Primera sesión del bloque",
          "ejercicios": [
            { "nombre": "Press banca con barra", "series": 4, "reps": "8-10", "rir": "2-3", "descanso": 150 },
            { "nombre": "Elevaciones laterales", "series": 4, "reps": "12-15", "descanso": 60 }
          ]
        }
      ]
    }
    """

    func testLeeUnJSONCompleto() throws {
        let resultado = try LectorRutinasJSON.leer(jsonValido)
        XCTAssertEqual(resultado.carpeta, "Bloque otoño")
        XCTAssertEqual(resultado.rutinas.count, 1)

        let rutina = resultado.rutinas[0]
        XCTAssertEqual(rutina.nombre, "Lunes – Empuje")
        XCTAssertEqual(rutina.notas, "Primera sesión del bloque")
        XCTAssertEqual(rutina.ejercicios.count, 2)

        let press = rutina.ejercicios[0]
        XCTAssertEqual(press.nombre, "Press banca con barra")
        XCTAssertEqual(press.series, 4)
        XCTAssertEqual(press.objetivoMin, 8)
        XCTAssertEqual(press.objetivoMax, 10)
        XCTAssertEqual(press.rirMin, 2)
        XCTAssertEqual(press.rirMax, 3)
        XCTAssertEqual(press.descansoSegundos, 150)
        XCTAssertFalse(press.esTiempo)
    }

    func testLosCamposOpcionalesTienenValoresPorDefecto() throws {
        let json = """
        { "version": 1, "rutinas": [ { "nombre": "R", "ejercicios": [ { "nombre": "E", "series": 3 } ] } ] }
        """
        let resultado = try LectorRutinasJSON.leer(json)
        XCTAssertNil(resultado.carpeta)
        let ejercicio = resultado.rutinas[0].ejercicios[0]
        XCTAssertNil(ejercicio.objetivoMin, "sin reps son series libres")
        XCTAssertNil(ejercicio.rirMin)
        XCTAssertEqual(ejercicio.descansoSegundos, 90)
        XCTAssertEqual(ejercicio.notas, "")
        XCTAssertNil(ejercicio.etiquetaSuperserie)
    }

    func testLaCarpetaVaciaSeTrataComoAusente() throws {
        let json = """
        { "version": 1, "carpeta": "   ", "rutinas": [ { "nombre": "R", "ejercicios": [ { "nombre": "E", "series": 3 } ] } ] }
        """
        XCTAssertNil(try LectorRutinasJSON.leer(json).carpeta)
    }

    func testLeeLasSuperseries() throws {
        let json = """
        {
          "version": 1,
          "rutinas": [{ "nombre": "Viernes", "ejercicios": [
            { "nombre": "Curl inclinado", "series": 3, "reps": "10-12", "superserie": "A" },
            { "nombre": "Extensión de tríceps", "series": 3, "reps": "10-12", "superserie": "A" },
            { "nombre": "Curl predicador", "series": 3, "reps": "10-12", "superserie": "B" }
          ]}]
        }
        """
        let ejercicios = try LectorRutinasJSON.leer(json).rutinas[0].ejercicios
        XCTAssertEqual(ejercicios.map(\.etiquetaSuperserie), ["A", "A", "B"])
    }

    func testLosNombresDeEjercicioSalenSinRepetir() throws {
        let json = """
        {
          "version": 1,
          "rutinas": [
            { "nombre": "A", "ejercicios": [{ "nombre": "Press banca", "series": 3 }, { "nombre": "Fondos", "series": 3 }] },
            { "nombre": "B", "ejercicios": [{ "nombre": "press banca", "series": 3 }] }
          ]
        }
        """
        let nombres = try LectorRutinasJSON.leer(json).nombresDeEjercicio
        XCTAssertEqual(nombres, ["Press banca", "Fondos"])
    }

    // MARK: - Rangos

    func testRangoNormal() throws {
        let rango = try LectorRutinasJSON.parsearRango("8-10", ruta: "r")
        XCTAssertEqual(rango, .init(minimo: 8, maximo: 10, esTiempo: false))
    }

    func testRangoDeUnSoloNumero() throws {
        let rango = try LectorRutinasJSON.parsearRango("15", ruta: "r")
        XCTAssertEqual(rango, .init(minimo: 15, maximo: 15, esTiempo: false))
    }

    func testRangoEnSegundos() throws {
        let rango = try LectorRutinasJSON.parsearRango("30-45s", ruta: "r")
        XCTAssertEqual(rango, .init(minimo: 30, maximo: 45, esTiempo: true))
    }

    func testSegundosDeUnSoloValor() throws {
        let rango = try LectorRutinasJSON.parsearRango("45s", ruta: "r")
        XCTAssertEqual(rango, .init(minimo: 45, maximo: 45, esTiempo: true))
    }

    func testElRangoAdmiteGuionLargoYLaPalabraA() throws {
        // Lo que mete un editor de texto o una IA escribiendo en prosa.
        XCTAssertEqual(try LectorRutinasJSON.parsearRango("8\u{2013}10", ruta: "r").maximo, 10)
        XCTAssertEqual(try LectorRutinasJSON.parsearRango("8 a 10", ruta: "r").maximo, 10)
    }

    func testElRangoAlRevesEsError() throws {
        XCTAssertThrowsError(try LectorRutinasJSON.parsearRango("10-8", ruta: "r")) { error in
            let fallo = error as? ErrorImportacion
            XCTAssertTrue(fallo?.mensaje.contains("mínimo por encima del máximo") ?? false, "\(error)")
        }
    }

    func testUnRangoBasuraEsError() throws {
        for malo in ["ocho", "8-10-12", "", "-"] {
            XCTAssertThrowsError(
                try LectorRutinasJSON.parsearRango(malo, ruta: "r"),
                "«\(malo)» debería fallar"
            )
        }
    }

    func testElRIRNoAdmiteSegundos() throws {
        XCTAssertThrowsError(
            try LectorRutinasJSON.parsearRango("30s", ruta: "r", permitirSegundos: false)
        ) { error in
            let fallo = error as? ErrorImportacion
            XCTAssertTrue(fallo?.mensaje.contains("no se admiten segundos") ?? false, "\(error)")
        }
    }

    // MARK: - Errores con ruta

    private func errorAlLeer(_ json: String) -> ErrorImportacion? {
        do {
            _ = try LectorRutinasJSON.leer(json)
            return nil
        } catch let fallo as ErrorImportacion {
            return fallo
        } catch {
            return nil
        }
    }

    func testTextoVacio() throws {
        let fallo = try XCTUnwrap(errorAlLeer("   "))
        XCTAssertTrue(fallo.mensaje.contains("vacío"), fallo.description)
    }

    func testJSONRoto() throws {
        let fallo = try XCTUnwrap(errorAlLeer("{ \"version\": 1, "))
        XCTAssertTrue(fallo.mensaje.contains("no es un JSON válido")
                      || fallo.mensaje.contains("No es un JSON válido"), fallo.description)
    }

    func testFaltaLaVersion() throws {
        let fallo = try XCTUnwrap(errorAlLeer("{ \"rutinas\": [] }"))
        XCTAssertEqual(fallo.ruta, "version")
    }

    func testVersionNoSoportada() throws {
        let fallo = try XCTUnwrap(errorAlLeer("{ \"version\": 99, \"rutinas\": [] }"))
        XCTAssertEqual(fallo.ruta, "version")
        XCTAssertTrue(fallo.mensaje.contains("99"), fallo.description)
    }

    func testFaltanLasRutinas() throws {
        let fallo = try XCTUnwrap(errorAlLeer("{ \"version\": 1 }"))
        XCTAssertEqual(fallo.ruta, "rutinas")
    }

    func testListaDeRutinasVacia() throws {
        let fallo = try XCTUnwrap(errorAlLeer("{ \"version\": 1, \"rutinas\": [] }"))
        XCTAssertEqual(fallo.ruta, "rutinas")
        XCTAssertTrue(fallo.mensaje.contains("vacía"), fallo.description)
    }

    func testLaRutaSeñalaLaRutinaYElEjercicioExactos() throws {
        let json = """
        {
          "version": 1,
          "rutinas": [
            { "nombre": "A", "ejercicios": [{ "nombre": "E", "series": 3 }] },
            { "nombre": "B", "ejercicios": [
                { "nombre": "E1", "series": 3 },
                { "nombre": "E2", "series": 3 },
                { "nombre": "E3", "series": 3, "reps": "8 hasta 10" }
            ]}
          ]
        }
        """
        let fallo = try XCTUnwrap(errorAlLeer(json))
        XCTAssertEqual(fallo.ruta, "rutinas[1].ejercicios[2].reps", fallo.description)
    }

    func testFaltaElNombreDeLaRutina() throws {
        let fallo = try XCTUnwrap(errorAlLeer("{ \"version\": 1, \"rutinas\": [{ \"ejercicios\": [] }] }"))
        XCTAssertEqual(fallo.ruta, "rutinas[0].nombre")
    }

    func testRutinaSinEjercicios() throws {
        let json = "{ \"version\": 1, \"rutinas\": [{ \"nombre\": \"Vacía\", \"ejercicios\": [] }] }"
        let fallo = try XCTUnwrap(errorAlLeer(json))
        XCTAssertEqual(fallo.ruta, "rutinas[0].ejercicios")
        XCTAssertTrue(fallo.mensaje.contains("Vacía"), "el mensaje debería nombrar la rutina: \(fallo.description)")
    }

    func testFaltanLasSeries() throws {
        let json = "{ \"version\": 1, \"rutinas\": [{ \"nombre\": \"R\", \"ejercicios\": [{ \"nombre\": \"E\" }] }] }"
        let fallo = try XCTUnwrap(errorAlLeer(json))
        XCTAssertEqual(fallo.ruta, "rutinas[0].ejercicios[0].series")
    }

    func testSeriesFueraDeRango() throws {
        let json = "{ \"version\": 1, \"rutinas\": [{ \"nombre\": \"R\", \"ejercicios\": [{ \"nombre\": \"E\", \"series\": 99 }] }] }"
        let fallo = try XCTUnwrap(errorAlLeer(json))
        XCTAssertEqual(fallo.ruta, "rutinas[0].ejercicios[0].series")
        XCTAssertTrue(fallo.mensaje.contains("99"), fallo.description)
    }

    func testDescansoFueraDeRango() throws {
        let json = "{ \"version\": 1, \"rutinas\": [{ \"nombre\": \"R\", \"ejercicios\": [{ \"nombre\": \"E\", \"series\": 3, \"descanso\": 99999 }] }] }"
        let fallo = try XCTUnwrap(errorAlLeer(json))
        XCTAssertEqual(fallo.ruta, "rutinas[0].ejercicios[0].descanso")
    }

    func testRepsComoNumeroEnLugarDeTextoDaUnErrorQueLoExplica() throws {
        let json = "{ \"version\": 1, \"rutinas\": [{ \"nombre\": \"R\", \"ejercicios\": [{ \"nombre\": \"E\", \"series\": 3, \"reps\": 10 }] }] }"
        let fallo = try XCTUnwrap(errorAlLeer(json))
        XCTAssertEqual(fallo.ruta, "rutinas[0].ejercicios[0].reps")
        XCTAssertTrue(fallo.mensaje.contains("entre comillas"), fallo.description)
    }

    func testLaRaizTieneQueSerUnObjeto() throws {
        let fallo = try XCTUnwrap(errorAlLeer("[1, 2, 3]"))
        XCTAssertTrue(fallo.mensaje.contains("objeto JSON"), fallo.description)
    }

    // MARK: - Tolerancias

    func testElRIRSeAdmiteComoNumero() throws {
        let json = "{ \"version\": 1, \"rutinas\": [{ \"nombre\": \"R\", \"ejercicios\": [{ \"nombre\": \"E\", \"series\": 3, \"rir\": 2 }] }] }"
        let ejercicio = try LectorRutinasJSON.leer(json).rutinas[0].ejercicios[0]
        XCTAssertEqual(ejercicio.rirMin, 2)
        XCTAssertEqual(ejercicio.rirMax, 2)
    }

    func testUnEnteroQueLlegaComoDecimalRedondoSeAcepta() {
        // JSON no distingue 3 de 3.0.
        XCTAssertEqual(LectorRutinasJSON.enteroDe(3.0), 3)
        XCTAssertNil(LectorRutinasJSON.enteroDe(3.5), "un decimal de verdad se rechaza")
    }

    func testUnNumeroDisparatadoNoCierraLaApp() throws {
        // `Int(1e300)` atrapa, y eso no se puede capturar: cierra la app. El
        // archivo lo escribe cualquiera, así que el valor llega hasta aquí.
        XCTAssertEqual(LectorRutinasJSON.enteroDe(1e300), 1_000_000_000_000_000)
        XCTAssertEqual(LectorRutinasJSON.enteroDe(Double.infinity), 0)
        XCTAssertNil(LectorRutinasJSON.enteroDe(Double.nan))

        // Y recortado, lo rechaza la comprobación de rango con su mensaje.
        let json = "{ \"version\": 1, \"rutinas\": [{ \"nombre\": \"R\", \"ejercicios\": [{ \"nombre\": \"E\", \"series\": 1e300 }] }] }"
        XCTAssertThrowsError(try LectorRutinasJSON.leer(json)) { error in
            let fallo = error as? ErrorImportacion
            XCTAssertEqual(fallo?.ruta, "rutinas[0].ejercicios[0].series")
        }
    }

    func testSeLimpianLosEspaciosDeLosNombres() throws {
        let json = "{ \"version\": 1, \"rutinas\": [{ \"nombre\": \"  R  \", \"ejercicios\": [{ \"nombre\": \"  E  \", \"series\": 3 }] }] }"
        let rutina = try LectorRutinasJSON.leer(json).rutinas[0]
        XCTAssertEqual(rutina.nombre, "R")
        XCTAssertEqual(rutina.ejercicios[0].nombre, "E")
    }
}
