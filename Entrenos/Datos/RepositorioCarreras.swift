import Foundation
import SwiftData

/// Las carreras de las tres procedencias, en una sola lista.
///
/// Único sitio donde se juntan. Antes cada vista leía `CacheCarreras` por su
/// cuenta, y con las escritas a mano eso habría dejado el historial contando
/// unas y la exportación otras.
@MainActor
struct RepositorioCarreras {
    let contexto: ModelContext

    init(contexto: ModelContext) {
        self.contexto = contexto
    }

    /// Las escritas a mano, de más reciente a más antigua.
    func manuales() -> [CarreraManual] {
        let descriptor = FetchDescriptor<CarreraManual>(
            sortBy: [SortDescriptor(\.fechaInicio, order: .reverse)]
        )
        return (try? contexto.fetch(descriptor)) ?? []
    }

    /// Todas, fusionadas: las medidas tapan a las escritas a mano de la misma
    /// hora, pero **no las borran** — siguen en su lista por si hay que
    /// revisarlas. Por eso se fusiona al leer y no al guardar.
    func todas() -> [Carrera] {
        CacheCarreras.compartida.cargarSiHaceFalta()
        return FusionCarreras.fusionar(
            CacheCarreras.compartida.carreras,
            con: manuales().map(\.valor)
        )
    }

    func recientes(dias: Int = 120) -> [Carrera] {
        let limite = Date().addingTimeInterval(-Double(dias) * 86_400)
        return todas().filter { $0.fechaInicio >= limite }
    }

    @discardableResult
    func anotar(
        fecha: Date,
        kilometros: Double,
        minutos: Double,
        pulsoMedio: Double? = nil,
        notas: String = ""
    ) -> CarreraManual? {
        // Recortado aquí: estos números los escribe el usuario, y un valor no
        // finito guardado una vez rompe el ritmo, las gráficas y el JSON de
        // exportación para siempre.
        guard kilometros.isFinite, minutos.isFinite, kilometros > 0 else { return nil }
        let metros = min(max(kilometros, 0), LectorPlanJSON.maxKilometros) * 1_000
        let segundos = min(max(minutos, 0), 24 * 60) * 60

        let carrera = CarreraManual(
            fechaInicio: fecha,
            distanciaMetros: metros,
            duracion: segundos,
            pulsoMedio: pulsoMedio.flatMap { $0.isFinite && $0 > 0 ? min($0, 250) : nil },
            notas: notas
        )
        contexto.insert(carrera)
        try? contexto.save()
        return carrera
    }

    func borrar(_ carrera: CarreraManual) {
        contexto.delete(carrera)
        try? contexto.save()
    }
}
