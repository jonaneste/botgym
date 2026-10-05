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

        // Un bookmark caducado se refresca en el sitio, para no perder el
        // permiso porque el archivo se moviera dentro de iCloud.
        if caducado, let nuevos = try? url.bookmarkData() {
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

        let concedido = carpeta.startAccessingSecurityScopedResource()
        defer { if concedido { carpeta.stopAccessingSecurityScopedResource() } }

        do {
            let exportacion = ServicioExportacion(contexto: contexto).construir()
            let datos = try SerializadorExportacion.json(exportacion)
            let destino = carpeta.appendingPathComponent(nombreArchivo)

            // Coordinada, porque el archivo puede estar en iCloud y haber otro
            // proceso sincronizándolo.
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

            if let errorCoordinacion { throw errorCoordinacion }
            if let errorEscritura { throw errorEscritura }

            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: claveUltima)
            return .escrito(destino)
        } catch {
            return .fallo(error.localizedDescription)
        }
    }

    /// Exporta solo si hay carpeta configurada. Es lo que se llama al terminar
    /// un entreno: si no está configurado, no hace nada y no molesta.
    func exportarSiProcede(contexto: ModelContext) {
        guard estaConfigurado else { return }
        if case .fallo(let detalle) = exportar(contexto: contexto) {
            print("Exportación automática fallida: \(detalle)")
        }
    }
}
