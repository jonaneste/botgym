import Foundation

/// Guarda las carreras leídas, vengan de Salud o de un archivo.
///
/// No van a SwiftData a propósito: las carreras las escribe Zepp en Salud, que
/// es la fuente de verdad. Esto es solo una copia para poder pintarlas en el
/// historial sin consultar Salud en cada redibujado, y para que las importadas
/// desde archivo sobrevivan al cierre de la app.
@MainActor
final class CacheCarreras {
    static let compartida = CacheCarreras()

    private(set) var carreras: [Carrera] = []
    private var cargado = false

    private init() {}

    private var url: URL? {
        guard let soporte = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        try? FileManager.default.createDirectory(at: soporte, withIntermediateDirectories: true)
        return soporte.appendingPathComponent("carreras.json")
    }

    /// Carga del disco la primera vez que se pide.
    func cargarSiHaceFalta() {
        guard !cargado else { return }
        cargado = true
        guard let url, let datos = try? Data(contentsOf: url) else { return }
        let decodificador = JSONDecoder()
        decodificador.dateDecodingStrategy = .iso8601
        carreras = (try? decodificador.decode([Carrera].self, from: datos)) ?? []
    }

    /// Fusiona las carreras nuevas con las que ya había, por identificador.
    ///
    /// Reimportar el mismo archivo no duplica nada, y las de Salud y las de
    /// archivo pueden convivir.
    func guardar(_ nuevas: [Carrera]) {
        cargarSiHaceFalta()
        var porId = Dictionary(carreras.map { ($0.id, $0) }, uniquingKeysWith: { _, ultima in ultima })
        for carrera in nuevas {
            porId[carrera.id] = carrera
        }
        carreras = porId.values.sorted { $0.fechaInicio > $1.fechaInicio }
        escribir()
    }

    func vaciar() {
        carreras = []
        escribir()
    }

    /// Carreras de los últimos `dias` días.
    func recientes(dias: Int = 120) -> [Carrera] {
        cargarSiHaceFalta()
        let limite = Date().addingTimeInterval(-Double(dias) * 86_400)
        return carreras.filter { $0.fechaInicio >= limite }
    }

    private func escribir() {
        guard let url else { return }
        let codificador = JSONEncoder()
        codificador.dateEncodingStrategy = .iso8601
        guard let datos = try? codificador.encode(carreras) else { return }
        try? datos.write(to: url, options: .atomic)
    }
}
