import Foundation
import SwiftData

/// Escribe el JSON completo en una carpeta que el usuario elige, cada vez que
/// termina un entreno.
///
/// Es la pieza que convierte la app en el almacén de datos del que Claude
/// puede leer: si la carpeta elegida está en iCloud Drive, el archivo aparece
/// solo en el Mac, y allí un servidor MCP lo lee.
///
/// **No necesita la capability de iCloud**, que es de pago. El acceso llega
/// por el selector de archivos del sistema: el usuario concede el permiso una
/// vez y se guarda un *security-scoped bookmark*, que la app resuelve después
/// para escribir sin volver a preguntar.
@MainActor
final class ExportadorAutomatico {
    static let compartido = ExportadorAutomatico()

    private let claveBookmark = "carpetaExportacionBookmark"
    private let claveUltima = "ultimaExportacionAutomatica"
    private let claveNombre = "nombreCarpetaExportacion"
    private let nombreArchivo = "entrenos.json"

    /// Subcarpeta donde el MCP deja las rutinas propuestas. El nombre está
    /// acordado con `mcp/servidor-entrenos.mjs`: si cambia aquí, cambia allí.
    static let carpetaPropuestas = "propuestas"

    private init() {}

    // MARK: - Carpeta elegida

    /// Nombre legible de la carpeta elegida, para pintarlo en Ajustes.
    var nombreCarpeta: String? {
        UserDefaults.standard.string(forKey: claveNombre)
    }

    var estaConfigurado: Bool {
        UserDefaults.standard.data(forKey: claveBookmark) != nil
    }

    var ultimaExportacion: Date? {
        let marca = UserDefaults.standard.double(forKey: claveUltima)
        return marca > 0 ? Date(timeIntervalSince1970: marca) : nil
    }

    /// Guarda la carpeta que el usuario acaba de elegir en el selector.
    func configurar(carpeta url: URL) throws {
        // `bookmarkData()` sobre una URL del selector tiene que ejecutarse
        // DENTRO del ámbito de seguridad, o falla con el error 257 (sin
        // permiso de lectura) y la carpeta no se puede configurar nunca.
        guard url.startAccessingSecurityScopedResource() else {
            throw ErrorExportadorAutomatico.sinPermiso
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // El bookmark es lo que permite volver a escribir más adelante sin
        // pasar otra vez por el selector.
        let datos = try url.bookmarkData()
        UserDefaults.standard.set(datos, forKey: claveBookmark)
        UserDefaults.standard.set(url.lastPathComponent, forKey: claveNombre)
    }

    func olvidarCarpeta() {
        UserDefaults.standard.removeObject(forKey: claveBookmark)
        UserDefaults.standard.removeObject(forKey: claveNombre)
        UserDefaults.standard.removeObject(forKey: claveUltima)
    }

    /// Resuelve el bookmark guardado. Devuelve `nil` si no hay carpeta o si el
    /// permiso ya no vale, por ejemplo porque el usuario la borró.
    private func resolverCarpeta() -> URL? {
        guard let datos = UserDefaults.standard.data(forKey: claveBookmark) else { return nil }
        var caducado = false
        guard let url = try? URL(
            resolvingBookmarkData: datos,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &caducado
        ) else { return nil }

        // Un bookmark caducado se refresca, para no perder el permiso porque
        // la carpeta se moviera dentro de iCloud. El refresco también tiene
        // que ir dentro del ámbito de seguridad, y si falla hay que olvidar la
        // carpeta: dejarla puesta haría que la interfaz dijera que está
        // configurada mientras ninguna escritura funciona.
        if caducado {
            guard url.startAccessingSecurityScopedResource() else {
                olvidarCarpeta()
                return nil
            }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let nuevos = try? url.bookmarkData() else {
                olvidarCarpeta()
                return nil
            }
            UserDefaults.standard.set(nuevos, forKey: claveBookmark)
        }
        return url
    }

    // MARK: - Escribir

    enum Resultado {
        case escrito(URL)
        case sinCarpeta
        case fallo(String)
    }

    /// Escribe el JSON en la carpeta elegida. Sobrescribe el archivo anterior:
    /// la idea es que haya siempre un único `entrenos.json` al día.
    @discardableResult
    func exportar(contexto: ModelContext) -> Resultado {
        guard let carpeta = resolverCarpeta() else { return .sinCarpeta }

        // El JSON se construye aquí porque ModelContext está atado al hilo
        // principal. Si no hay permiso de acceso se para: sin esta
        // comprobación la escritura fallaría más abajo con un error opaco.
        guard carpeta.startAccessingSecurityScopedResource() else {
            return .fallo("La carpeta elegida ya no concede permiso. Vuelve a elegirla.")
        }
        defer { carpeta.stopAccessingSecurityScopedResource() }

        let datos: Data
        do {
            datos = try SerializadorExportacion.json(
                ServicioExportacion(contexto: contexto).construir()
            )
        } catch {
            return .fallo(error.localizedDescription)
        }

        let destino = carpeta.appendingPathComponent(nombreArchivo)
        if let fallo = Self.escribirCoordinado(datos, en: destino) {
            return .fallo(fallo)
        }

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: claveUltima)
        return .escrito(destino)
    }

    // MARK: - Rutinas propuestas desde fuera

    /// Una rutina que alguien ha dejado en `propuestas/` dentro de la carpeta
    /// de Claude, esperando a que la revises.
    struct Propuesta: Identifiable, Hashable {
        let id: URL
        let nombreArchivo: String
        let fecha: Date
        let json: String
        /// Los nombres de las rutinas que trae, para enseñarlos sin tener que
        /// abrir el JSON.
        let rutinas: [String]
    }

    /// Lee las propuestas pendientes, de más reciente a más antigua.
    ///
    /// Es la otra mitad del puente con Claude: la app escribe `entrenos.json`
    /// para que lo lea, y Claude deja aquí las rutinas que propone. No se
    /// importa nada solo: esto únicamente las encuentra, y la pantalla de
    /// importar las enseña para que las aceptes. Una rutina que entrara sola
    /// podría cambiar tus objetivos sin que te enteres.
    func propuestasPendientes() -> [Propuesta] {
        guard let carpeta = resolverCarpeta() else { return [] }
        // Como todo lo que toca esa URL, dentro del ámbito de seguridad: sin
        // esto, listar el directorio falla con el error 257.
        guard carpeta.startAccessingSecurityScopedResource() else { return [] }
        defer { carpeta.stopAccessingSecurityScopedResource() }

        let directorio = carpeta.appendingPathComponent(Self.carpetaPropuestas, isDirectory: true)
        let contenido = (try? FileManager.default.contentsOfDirectory(
            at: directorio,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return contenido
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { url -> Propuesta? in
                guard let texto = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                let fecha = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                return Propuesta(
                    id: url,
                    nombreArchivo: url.lastPathComponent,
                    fecha: fecha,
                    json: texto,
                    rutinas: Self.nombresDeRutinas(en: texto)
                )
            }
            .sorted { $0.fecha > $1.fecha }
    }

    /// Saca los nombres de las rutinas sin validar el resto: aquí solo hace
    /// falta qué enseñar en la lista. De validarlo en serio ya se encarga el
    /// importador cuando la aceptas.
    private static func nombresDeRutinas(en texto: String) -> [String] {
        guard let datos = texto.data(using: .utf8),
              let raiz = try? JSONSerialization.jsonObject(with: datos) as? [String: Any],
              let rutinas = raiz["rutinas"] as? [[String: Any]]
        else { return [] }
        return rutinas.compactMap { $0["nombre"] as? String }
    }

    /// Quita una propuesta ya importada, para que no vuelva a aparecer.
    ///
    /// Se borra en lugar de marcarla: el archivo ya cumplió su función, y
    /// dejarlo obligaría a llevar una lista de "ya vistas" que se
    /// desincronizaría en cuanto se tocara la carpeta desde el Mac.
    func descartarPropuesta(_ propuesta: Propuesta) {
        guard let carpeta = resolverCarpeta() else { return }
        guard carpeta.startAccessingSecurityScopedResource() else { return }
        defer { carpeta.stopAccessingSecurityScopedResource() }
        try? FileManager.default.removeItem(at: propuesta.id)
    }

    /// Igual que `exportar(contexto:)`, pero la escritura coordinada sale del
    /// hilo principal.
    ///
    /// El JSON se tiene que construir aquí, porque `ModelContext` está atado al
    /// hilo principal, pero eso es rápido. Lo que no lo es es la escritura: va
    /// contra una carpeta de iCloud Drive y `NSFileCoordinator` espera a que el
    /// demonio de sincronización suelte el archivo, que pueden ser segundos.
    /// Haciéndolo en el hilo principal, la app se quedaba congelada justo al
    /// pulsar "Guardar entreno", y una espera suficientemente larga ahí es un
    /// cierre por watchdog.
    ///
    /// El ámbito de seguridad se mantiene abierto durante el `await`: el
    /// `defer` no se ejecuta hasta que la función vuelve de verdad.
    func exportarFueraDelPrincipal(contexto: ModelContext) async -> Resultado {
        guard let carpeta = resolverCarpeta() else { return .sinCarpeta }

        guard carpeta.startAccessingSecurityScopedResource() else {
            return .fallo("La carpeta elegida ya no concede permiso. Vuelve a elegirla.")
        }
        defer { carpeta.stopAccessingSecurityScopedResource() }

        let datos: Data
        do {
            datos = try SerializadorExportacion.json(
                ServicioExportacion(contexto: contexto).construir()
            )
        } catch {
            return .fallo(error.localizedDescription)
        }

        let destino = carpeta.appendingPathComponent(nombreArchivo)
        let fallo = await Task.detached(priority: .utility) {
            Self.escribirCoordinado(datos, en: destino)
        }.value
        if let fallo { return .fallo(fallo) }

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: claveUltima)
        return .escrito(destino)
    }

    /// Escritura coordinada, porque el archivo puede estar en iCloud y haber
    /// otro proceso sincronizándolo. Devuelve el mensaje de error, o `nil`.
    ///
    /// `nonisolated` a propósito: `@MainActor` en la clase alcanza también a
    /// sus miembros estáticos, así que sin esto llamarla desde una tarea aparte
    /// volvía al hilo principal y la tarea no servía de nada.
    nonisolated private static func escribirCoordinado(_ datos: Data, en destino: URL) -> String? {
        var errorCoordinacion: NSError?
        var errorEscritura: Error?
        NSFileCoordinator().coordinate(
            writingItemAt: destino,
            options: .forReplacing,
            error: &errorCoordinacion
        ) { url in
            do {
                try datos.write(to: url, options: .atomic)
            } catch {
                errorEscritura = error
            }
        }
        if let errorCoordinacion { return errorCoordinacion.localizedDescription }
        if let errorEscritura { return errorEscritura.localizedDescription }
        return nil
    }

    /// Exporta solo si hay carpeta configurada. Es lo que se llama al terminar
    /// un entreno: si no está configurado, no hace nada y no molesta.
    ///
    /// Usa la variante asíncrona para no bloquear el cierre del entreno: el
    /// usuario no tiene que esperar a que iCloud suelte el archivo para ver su
    /// resumen.
    func exportarSiProcede(contexto: ModelContext) {
        guard estaConfigurado else { return }
        Task { [weak self] in
            guard let self else { return }
            if case .fallo(let detalle) = await self.exportarFueraDelPrincipal(contexto: contexto) {
                print("Exportación automática fallida: \(detalle)")
            }
        }
    }
}


enum ErrorExportadorAutomatico: LocalizedError {
    case sinPermiso

    var errorDescription: String? {
        switch self {
        case .sinPermiso:
            return "El sistema no concedió acceso a esa carpeta. Prueba con otra."
        }
    }
}
