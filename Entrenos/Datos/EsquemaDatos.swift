import Foundation
import SwiftData

/// Punto único donde se declara el esquema de SwiftData.
enum EsquemaDatos {

    static let modelos: [any PersistentModel.Type] = [
        Ejercicio.self,
        CarpetaRutinas.self,
        Rutina.self,
        ElementoRutina.self,
        Entreno.self,
        EjercicioEntreno.self,
        SerieRegistrada.self,
        Ajustes.self,
    ]

    static var esquema: Schema {
        Schema(modelos)
    }

    /// Contenedor de producción, con la base de datos en disco.
    static func contenedor() throws -> ModelContainer {
        let configuracion = ModelConfiguration(schema: esquema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: esquema, configurations: [configuracion])
    }

    /// Contenedor en memoria, para las vistas previas de Xcode.
    static func contenedorEnMemoria() throws -> ModelContainer {
        let configuracion = ModelConfiguration(schema: esquema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: esquema, configurations: [configuracion])
    }
}
