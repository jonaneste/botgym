import Foundation
import SwiftData

/// Mete solas las rutinas que Claude deja en la carpeta compartida.
///
/// El paso manual sobraba. Claude escribe la rutina, iCloud la trae al
/// iPhone, y la app la importaba... solo si entrabas a una pantalla de
/// ajustes y la tocabas. Para algo pensado para que te lo monte otro, ese
/// paso era justo el que hacía que no lo usaras.
///
/// Se importa sin preguntar, pero **no en silencio**: la app enseña un aviso
/// diciendo qué ha entrado. La diferencia con los datos de salud, que sí se
/// piden a mano, es que una rutina es aditiva: aparece una rutina nueva en su
/// carpeta y no se toca ni un entreno del historial ni un objetivo. Si no la
/// quieres, la borras deslizando como cualquier otra.
@MainActor
enum ImportadorAutomatico {

    /// Lo que entró en esta pasada, para poder contarlo en el aviso.
    struct Resumen: Equatable {
        var rutinas: [String] = []
        var ejerciciosCreados: Int = 0
        var carpetas: Set<String> = []
        /// Nombre del plan que entró y cuántos días trae.
        var plan: String?
        var diasDePlan: Int = 0
        /// Lo que se borró, si algún archivo lo pedía.
        var borrado = BorradorRemoto.Resultado()
        /// Ejercicios que entraron sueltos, para la biblioteca.
        var ejerciciosDeCatalogo: Int = 0
        /// Archivos que no se pudieron leer. Se quedan donde están.
        var fallidos: [String] = []

        var huboAlgo: Bool {
            !rutinas.isEmpty || plan != nil || borrado.huboAlgo
                || ejerciciosDeCatalogo > 0 || !fallidos.isEmpty
        }
    }

    /// Revisa la carpeta e importa lo que haya. Devuelve `nil` si no había
    /// nada, para que la interfaz no tenga que distinguir vacío de error.
    @discardableResult
    static func revisar(contexto: ModelContext) -> Resumen? {
        let bandeja = ExportadorAutomatico.compartido.propuestasPendientes()
        guard !bandeja.listas.isEmpty else { return nil }

        var resumen = Resumen()
        let importador = ImportadorRutinas(contexto: contexto)

        let repositorioPlan = RepositorioPlan(contexto: contexto)

        for propuesta in bandeja.listas {
            // Los dos formatos comparten carpeta, así que se distinguen por lo
            // que traen dentro y no por el nombre del archivo: pedirle a quien
            // lo escribe que acierte con el nombre es una regla más que
            // recordar y un fallo más que no dice nada.
            // El borrado se mira antes que nada: es el único formato que
            // quita cosas, así que tiene que ser imposible que un archivo de
            // rutinas se cuele por aquí o al revés. Los tres se distinguen por
            // su clave: «borrar», «plan» o «rutinas».
            if let borrado = try? LectorBorradoJSON.leer(propuesta.json) {
                let hecho = BorradorRemoto(contexto: contexto).aplicar(borrado)
                resumen.borrado.carpetas += hecho.carpetas
                resumen.borrado.rutinas += hecho.rutinas
                resumen.borrado.entrenos += hecho.entrenos
                ExportadorAutomatico.compartido.descartarPropuesta(propuesta)
                continue
            }

            if let sueltos = try? LectorEjerciciosJSON.leer(propuesta.json) {
                resumen.ejerciciosDeCatalogo += importador.importarCatalogo(sueltos)
                ExportadorAutomatico.compartido.descartarPropuesta(propuesta)
                continue
            }

            if let plan = try? LectorPlanJSON.leer(propuesta.json) {
                let dias = repositorioPlan.guardar(plan)
                resumen.plan = plan.nombre
                resumen.diasDePlan += dias
                ExportadorAutomatico.compartido.descartarPropuesta(propuesta)
                continue
            }

            guard let leidas = try? LectorRutinasJSON.leer(propuesta.json) else {
                // Un archivo que no se entiende NO se borra: dejarlo es la
                // única pista de que algo llegó mal, y borrarlo perdería una
                // rutina que quizá solo tiene una coma de más.
                resumen.fallidos.append(propuesta.nombreArchivo)
                continue
            }

            // Sin mapeo: los ejercicios que no existan se crean, con el grupo
            // y el material que venga declarado en el archivo.
            let resultado = importador.importar(leidas, mapeo: [:])
            resumen.rutinas.append(contentsOf: leidas.rutinas.map(\.nombre))
            resumen.ejerciciosCreados += resultado.ejerciciosCreados
            if let carpeta = resultado.carpeta { resumen.carpetas.insert(carpeta) }

            ExportadorAutomatico.compartido.descartarPropuesta(propuesta)
        }

        return resumen.huboAlgo ? resumen : nil
    }
}
