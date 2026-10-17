import XCTest
@testable import NucleoEntrenos

final class LectorPlanJSONTests: XCTestCase {

    private let minimo = """
    {
      "version": 1,
      "plan": {
        "nombre": "Media maratón",
        "objetivo": "2026-12-20",
        "dias": [
          { "fecha": "2026-10-13", "tipo": "gimnasioYCarrera", "titulo": "Pecho y tríceps", "km": 4, "rutina": "Martes – Pecho y tríceps", "notas": "18:30h" },
          { "fecha": "2026-10-14", "tipo": "descanso" },
          { "fecha": "2026-10-18", "tipo": "carrera", "titulo": "Tirada larga", "km": 6 },
          { "fecha": "2026-12-20", "tipo": "competicion", "titulo": "Media maratón Vitoria-Gasteiz", "km": 21.1 }
        ]
      }
    }
    """

    func testSeLeeUnPlanCompleto() throws {
        let plan = try LectorPlanJSON.leer(minimo)
        XCTAssertEqual(plan.nombre, "Media maratón")
        XCTAssertEqual(plan.dias.count, 4)
        XCTAssertEqual(plan.dias[0].titulo, "Pecho y tríceps")
        XCTAssertEqual(plan.dias[0].tipo, .gimnasioYCarrera)
        XCTAssertEqual(plan.dias[0].kilometros, 4)
        XCTAssertEqual(plan.dias[0].nombreRutina, "Martes – Pecho y tríceps")
        XCTAssertEqual(plan.dias[0].notas, "18:30h")
    }

    func testLosDiasSalenOrdenadosPorFecha() throws {
        let json = """
        { "version": 1, "plan": { "nombre": "P", "dias": [
          { "fecha": "2026-10-20", "tipo": "descanso" },
          { "fecha": "2026-10-13", "tipo": "gimnasio" }
        ] } }
        """
        let plan = try LectorPlanJSON.leer(json)
        XCTAssertEqual(plan.dias.map { LectorPlanJSON.textoDe($0.fecha) }, ["2026-10-13", "2026-10-20"])
    }

    func testSinTituloSeUsaElNombreDelTipo() throws {
        let plan = try LectorPlanJSON.leer(minimo)
        XCTAssertEqual(plan.dias[1].tipo, .descanso)
        XCTAssertEqual(plan.dias[1].titulo, "Descanso")
    }

    func testElObjetivoEsOpcional() throws {
        let json = "{ \"version\": 1, \"plan\": { \"nombre\": \"P\", \"dias\": [{ \"fecha\": \"2026-10-13\", \"tipo\": \"gimnasio\" }] } }"
        XCTAssertNil(try LectorPlanJSON.leer(json).objetivo)
    }

    // MARK: - Fechas

    func testLaFechaEsLaMedianocheDelDiaEnLaZonaDelTelefono() throws {
        // Lo que falla si se usa un formateador en UTC: en España la medianoche
        // UTC del 20 es el 19 a las 23:00 en invierno, y el plan entero se
        // corría un día.
        let plan = try LectorPlanJSON.leer(minimo)
        let componentes = CalendarioEntrenos.es.dateComponents(
            [.year, .month, .day, .hour], from: plan.dias[3].fecha
        )
        XCTAssertEqual(componentes.year, 2026)
        XCTAssertEqual(componentes.month, 12)
        XCTAssertEqual(componentes.day, 20)
        XCTAssertEqual(componentes.hour, 0)
    }

    func testUnaFechaQueNoExisteSeRechaza() {
        let json = "{ \"version\": 1, \"plan\": { \"nombre\": \"P\", \"dias\": [{ \"fecha\": \"2026-02-31\", \"tipo\": \"gimnasio\" }] } }"
        XCTAssertThrowsError(try LectorPlanJSON.leer(json)) { error in
            XCTAssertEqual((error as? ErrorImportacion)?.ruta, "plan.dias[0].fecha")
        }
    }

    func testUnaFechaConOtroFormatoSeRechaza() {
        let json = "{ \"version\": 1, \"plan\": { \"nombre\": \"P\", \"dias\": [{ \"fecha\": \"20/12/2026\", \"tipo\": \"gimnasio\" }] } }"
        XCTAssertThrowsError(try LectorPlanJSON.leer(json))
    }

    func testDosEntradasParaElMismoDiaSeRechazan() {
        let json = """
        { "version": 1, "plan": { "nombre": "P", "dias": [
          { "fecha": "2026-10-13", "tipo": "gimnasio" },
          { "fecha": "2026-10-13", "tipo": "descanso" }
        ] } }
        """
        XCTAssertThrowsError(try LectorPlanJSON.leer(json)) { error in
            let fallo = error as? ErrorImportacion
            XCTAssertTrue(fallo?.mensaje.contains("2026-10-13") ?? false, fallo?.mensaje ?? "")
        }
    }

    // MARK: - Tipos y kilómetros

    func testUnTipoDesconocidoDiceCualesValen() {
        let json = "{ \"version\": 1, \"plan\": { \"nombre\": \"P\", \"dias\": [{ \"fecha\": \"2026-10-13\", \"tipo\": \"yoga\" }] } }"
        XCTAssertThrowsError(try LectorPlanJSON.leer(json)) { error in
            let fallo = error as? ErrorImportacion
            XCTAssertEqual(fallo?.ruta, "plan.dias[0].tipo")
            XCTAssertTrue(fallo?.mensaje.contains("gimnasioYCarrera") ?? false, fallo?.mensaje ?? "")
        }
    }

    func testUnosKilometrosEnUnDiaDeDescansoSeRechazan() {
        let json = "{ \"version\": 1, \"plan\": { \"nombre\": \"P\", \"dias\": [{ \"fecha\": \"2026-10-13\", \"tipo\": \"descanso\", \"km\": 10 }] } }"
        XCTAssertThrowsError(try LectorPlanJSON.leer(json)) { error in
            XCTAssertEqual((error as? ErrorImportacion)?.ruta, "plan.dias[0].km")
        }
    }

    func testUnosKilometrosDisparatadosSeRechazan() {
        let json = "{ \"version\": 1, \"plan\": { \"nombre\": \"P\", \"dias\": [{ \"fecha\": \"2026-10-13\", \"tipo\": \"carrera\", \"km\": 5000 }] } }"
        XCTAssertThrowsError(try LectorPlanJSON.leer(json))
    }

    func testLosKilometrosAdmitenComaDecimal() throws {
        let json = "{ \"version\": 1, \"plan\": { \"nombre\": \"P\", \"dias\": [{ \"fecha\": \"2026-10-13\", \"tipo\": \"carrera\", \"km\": \"21,1\" }] } }"
        XCTAssertEqual(try LectorPlanJSON.leer(json).dias[0].kilometros, 21.1)
    }

    func testUnPlanSinDiasSeRechaza() {
        let json = "{ \"version\": 1, \"plan\": { \"nombre\": \"P\", \"dias\": [] } }"
        XCTAssertThrowsError(try LectorPlanJSON.leer(json)) { error in
            XCTAssertEqual((error as? ErrorImportacion)?.ruta, "plan.dias")
        }
    }

    func testUnaVersionDistintaSeRechaza() {
        let json = "{ \"version\": 2, \"plan\": { \"nombre\": \"P\", \"dias\": [{ \"fecha\": \"2026-10-13\", \"tipo\": \"gimnasio\" }] } }"
        XCTAssertThrowsError(try LectorPlanJSON.leer(json)) { error in
            XCTAssertEqual((error as? ErrorImportacion)?.ruta, "version")
        }
    }

    func testUnJsonDeRutinasNoSeLeeComoPlan() {
        // Los dos formatos entran por la misma carpeta, así que el lector tiene
        // que rechazar lo que no es suyo en vez de inventarse un plan vacío.
        let json = "{ \"version\": 1, \"rutinas\": [{ \"nombre\": \"R\", \"ejercicios\": [{ \"nombre\": \"E\", \"series\": 3 }] }] }"
        XCTAssertThrowsError(try LectorPlanJSON.leer(json)) { error in
            XCTAssertEqual((error as? ErrorImportacion)?.ruta, "plan")
        }
    }

    // MARK: - Cuentas

    func testDiasHastaElObjetivoCuentaPorCalendario() {
        // Del 13 de octubre al 20 de diciembre de 2026 hay 68 días, y en medio
        // está el cambio de hora: dividir segundos por 86.400 da 67.
        let hoy = try! LectorPlanJSON.fecha("2026-10-13", ruta: "")
        let objetivo = try! LectorPlanJSON.fecha("2026-12-20", ruta: "")
        XCTAssertEqual(ResumenPlan.diasHasta(objetivo, desde: hoy), 68)
    }

    func testDiasHastaEsCeroElDiaDeLaCarrera() {
        let dia = try! LectorPlanJSON.fecha("2026-12-20", ruta: "")
        XCTAssertEqual(ResumenPlan.diasHasta(dia, desde: dia), 0)
    }

    func testKilometrosPrevistosSumaSoloLosQueLosLlevan() throws {
        let plan = try LectorPlanJSON.leer(minimo)
        XCTAssertEqual(ResumenPlan.kilometrosPrevistos(plan.dias), 4 + 6 + 21.1, accuracy: 0.001)
    }

    func testLaSemanaDeUnDiaVaDeLunesADomingo() throws {
        let plan = try LectorPlanJSON.leer(minimo)
        // El 13 de octubre de 2026 es martes; su semana acaba el domingo 18.
        let semana = ResumenPlan.semanaDe(plan.dias[0].fecha, en: plan.dias)
        XCTAssertEqual(
            semana.map { LectorPlanJSON.textoDe($0.fecha) },
            ["2026-10-13", "2026-10-14", "2026-10-18"]
        )
    }

    // MARK: - Tipos

    func testQueTieneCadaTipo() {
        XCTAssertTrue(TipoDiaPlan.gimnasioYCarrera.tieneGimnasio)
        XCTAssertTrue(TipoDiaPlan.gimnasioYCarrera.tieneCarrera)
        XCTAssertTrue(TipoDiaPlan.competicion.tieneCarrera)
        XCTAssertFalse(TipoDiaPlan.competicion.tieneGimnasio)
        XCTAssertFalse(TipoDiaPlan.descanso.tieneCarrera)
        XCTAssertTrue(TipoDiaPlan.descanso.esDescanso)
        XCTAssertFalse(TipoDiaPlan.turismo.esDescanso)
    }
}
