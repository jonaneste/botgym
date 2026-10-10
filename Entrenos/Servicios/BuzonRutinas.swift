import Foundation

/// El buzón de ida de la carpeta compartida: lo que Claude deja ahí para que
/// la app lo importe.
///
/// La carpeta que se elige en Datos ya llevaba los datos en una dirección —la
/// app escribe `entrenos.json` y el servidor MCP de `mcp/` lo lee—. Esto usa
/// la misma carpeta en la otra dirección: Claude escribe un JSON de rutinas en
/// `rutinas-de-claude/` y aquí sale listo para añadirse de un toque, sin pegar
/// texto ni pasar por el selector de archivos.
///
/// Todo ocurre dentro del ámbito de seguridad del bookmark, igual que la
/// escritura: fuera de él falla incluso listar la carpeta, con un error 257
/// que no menciona el permiso por ningún lado.
@MainActor
final class BuzonRutinas {
    static let compartido = BuzonRutinas()

    /// Subcarpeta donde escribe el servidor MCP. El nombre está acordado con
    /// `mcp/servidor-entrenos.mjs`: cambiarlo aquí lo rompe allí.
    static let nombreSubcarpeta = "rutinas-de-claude"

    /// Donde van las propuestas ya importadas, en lugar de borrarlas.
    static let nombreImportadas = "importadas"

    private init() {}

    /// Una propuesta pendiente de importar.
    struct Propuesta: Identifiable, Equatable {
        /// El nombre del archivo, único dentro de la carpeta.
        var id: String
        /// Los nombres de las rutinas que trae, para poder decir qué es sin
        /// abrirla.
        var rutinas: [String]
        var carpetaDestino: String?

        var resumen: String {
            rutinas.isEmpty ? id : rutinas.joined(separator: ", ")
        }

        var detalle: String {
            let cuantas = rutinas.count == 1 ? "1 rutina" : "\(rutinas.count) rutinas"
            guard let carpetaDestino else { return cuantas }
            return "\(cuantas) · carpeta «\(carpetaDestino)»"
        }
    }

    // MARK: - Listar

    /// Lo que hay esperando. Devuelve vacío si no hay carpeta elegida, si no
    /// existe la subcarpeta o si el permiso ya no vale: ninguno de los tres es
    /// un error que merezca interrumpir la pantalla de Datos.
    ///
    /// El recorrido sale del hilo principal porque la carpeta es de iCloud
    /// Drive: abrir un archivo que todavía no está en el teléfono puede
    /// esperar a la descarga, y eso en el hilo principal congela la pantalla.
    /// El ámbito de seguridad se mantiene abierto durante el `await`, porque
    /// el `defer` no corre hasta que la función vuelve de verdad.
    func pendientes() async -> [Propuesta] {
        guard let carpeta = ExportadorAutomatico.compartido.resolverCarpeta() else { return [] }
        guard carpeta.startAccessingSecurityScopedResource() else { return [] }
        defer { carpeta.stopAccessingSecurityScopedResource() }

        let buzon = carpeta.appendingPathComponent(Self.nombreSubcarpeta, isDirectory: true)
        return await Task.detached(priority: .userInitiated) {
            Self.listar(en: buzon)
        }.value
    }

    nonisolated private static func listar(en buzon: URL) -> [Propuesta] {
        let contenido = (try? FileManager.default.contentsOfDirectory(
            at: buzon,
            includingPropertiesForKeys: nil,
            options: []
        )) ?? []

        var propuestas: [Propuesta] = []
        var vistos: Set<String> = []
        for url in contenido {
            guard let nombre = nombreVisible(url.lastPathComponent) else { continue }
            guard vistos.insert(nombre).inserted else { continue }
            propuestas.append(describir(nombre: nombre, en: buzon))
        }
        return propuestas.sorted { $0.id < $1.id }
    }

    /// El nombre real de un archivo que iCloud todavía no ha descargado se
    /// presenta como «.rutina.json.icloud». Se normaliza para que la propuesta
    /// se llame igual antes y después de bajarse, y devuelve `nil` para todo
    /// lo que no sea un JSON, incluida la subcarpeta de importadas.
    nonisolated static func nombreVisible(_ nombreEnDisco: String) -> String? {
        var nombre = nombreEnDisco
        if nombre.hasSuffix(".icloud") {
            nombre = String(nombre.dropLast(".icloud".count))
            if nombre.hasPrefix(".") { nombre = String(nombre.dropFirst()) }
        }
        guard nombre.lowercased().hasSuffix(".json") else { return nil }
        return nombre
    }

    /// Mira dentro del archivo para poder decir qué rutinas trae sin abrirla.
    /// Si no se puede leer —porque iCloud no lo ha bajado todavía—, la
    /// propuesta sale con el nombre del archivo y nada más, en lugar de
    /// desaparecer de la lista.
    nonisolated private static func describir(nombre: String, en buzon: URL) -> Propuesta {
        let url = buzon.appendingPathComponent(nombre)
        guard
            let datos = try? Data(contentsOf: url),
            let raiz = (try? JSONSerialization.jsonObject(with: datos)) as? [String: Any]
        else {
            return Propuesta(id: nombre, rutinas: [], carpetaDestino: nil)
        }
        let rutinas = (raiz["rutinas"] as? [Any] ?? []).compactMap { elemento in
            (elemento as? [String: Any])?["nombre"] as? String
        }
        return Propuesta(
            id: nombre,
            rutinas: rutinas,
            carpetaDestino: raiz["carpeta"] as? String
        )
    }

    // MARK: - Leer

    /// El JSON de una propuesta, ya descargado de iCloud.
    ///
    /// La lectura sale del hilo principal porque va contra una carpeta de
    /// iCloud Drive: `NSFileCoordinator` espera a que el demonio de
    /// sincronización suelte el archivo, y eso son segundos. En el hilo
    /// principal, una espera así es un cierre por watchdog.
    func textoDe(_ propuesta: Propuesta) async throws -> String {
        guard let carpeta = ExportadorAutomatico.compartido.resolverCarpeta() else {
            throw ErrorBuzon.sinCarpeta
        }
        guard carpeta.startAccessingSecurityScopedResource() else {
            throw ErrorBuzon.sinPermiso
        }
        defer { carpeta.stopAccessingSecurityScopedResource() }

        let destino = carpeta
            .appendingPathComponent(Self.nombreSubcarpeta, isDirectory: true)
            .appendingPathComponent(propuesta.id)

        return try await Task.detached(priority: .userInitiated) {
            try Self.leerCoordinado(destino)
        }.value
    }

    /// `nonisolated` a propósito: `@MainActor` en la clase alcanza también a
    /// sus miembros estáticos, así que sin esto la tarea aparte volvería al
    /// hilo principal y no serviría de nada.
    nonisolated private static func leerCoordinado(_ destino: URL) throws -> String {
        // El archivo lo escribió el Mac, así que en el teléfono puede ser
        // todavía un hueco sin descargar. Esto pide la descarga, y la lectura
        // coordinada de abajo es la que espera a que termine.
        try? FileManager.default.startDownloadingUbiquitousItem(at: destino)

        var errorCoordinacion: NSError?
        var leido: String?
        var errorLectura: Error?
        NSFileCoordinator().coordinate(
            readingItemAt: destino,
            options: [],
            error: &errorCoordinacion
        ) { url in
            do {
                leido = try String(contentsOf: url, encoding: .utf8)
            } catch {
                errorLectura = error
            }
        }
        if let errorCoordinacion { throw errorCoordinacion }
        if let errorLectura { throw errorLectura }
        guard let leido else { throw ErrorBuzon.sinContenido }
        return leido
    }

    // MARK: - Apartar

    /// Aparta una propuesta ya importada a `importadas/` en vez de borrarla:
    /// deja de salir en la lista y el original sigue estando, que es lo que
    /// uno quiere la primera vez que importa algo sin querer.
    func apartar(_ propuesta: Propuesta) {
        guard let carpeta = ExportadorAutomatico.compartido.resolverCarpeta() else { return }
        guard carpeta.startAccessingSecurityScopedResource() else { return }
        defer { carpeta.stopAccessingSecurityScopedResource() }

        let buzon = carpeta.appendingPathComponent(Self.nombreSubcarpeta, isDirectory: true)
        let origen = buzon.appendingPathComponent(propuesta.id)
        let archivadas = buzon.appendingPathComponent(Self.nombreImportadas, isDirectory: true)
        try? FileManager.default.createDirectory(at: archivadas, withIntermediateDirectories: true)

        let destino = archivadas.appendingPathComponent("\(Self.marcaDeTiempo())-\(propuesta.id)")
        do {
            try FileManager.default.moveItem(at: origen, to: destino)
        } catch {
            // Si no se puede mover, se borra: el contenido ya está dentro de
            // la app como rutinas, y dejarlo ahí lo volvería a ofrecer para
            // importar y crearía duplicados.
            try? FileManager.default.removeItem(at: origen)
        }
    }

    private static func marcaDeTiempo() -> String {
        let formateador = DateFormatter()
        formateador.locale = Locale(identifier: "en_US_POSIX")
        formateador.dateFormat = "yyyy-MM-dd-HHmm"
        return formateador.string(from: Date())
    }
}

enum ErrorBuzon: LocalizedError {
    case sinCarpeta
    case sinPermiso
    case sinContenido

    var errorDescription: String? {
        switch self {
        case .sinCarpeta:
            return "No hay carpeta para Claude elegida. Elígela arriba, en «Carpeta para Claude»."
        case .sinPermiso:
            return "La carpeta elegida ya no concede permiso. Vuelve a elegirla."
        case .sinContenido:
            return "El archivo está en la carpeta pero no se pudo leer. Puede que iCloud no lo haya bajado todavía: prueba otra vez en un momento."
        }
    }
}
