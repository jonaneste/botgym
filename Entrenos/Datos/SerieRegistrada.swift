import Foundation
import SwiftData

/// Una serie anotada dentro de un entreno.
@Model
final class SerieRegistrada {
    var idPublico: UUID = UUID()
    var orden: Int = 0

    /// Carga en kilogramos. 0 en peso corporal sin lastre.
    var peso: Double = 0
    /// Repeticiones hechas. 0 en ejercicios de tiempo.
    var repeticiones: Int = 0
    /// Segundos aguantados, solo en ejercicios de tipo tiempo.
    var segundos: Int?
    var rir: Int?
    var completada: Bool = false
    var esCalentamiento: Bool = false
    /// Momento en que se marcó como completada, para reconstruir el descanso.
    var fechaCompletada: Date?

    var ejercicioEntreno: EjercicioEntreno?

    init(
        orden: Int,
        peso: Double = 0,
        repeticiones: Int = 0,
        segundos: Int? = nil,
        rir: Int? = nil,
        completada: Bool = false,
        esCalentamiento: Bool = false
    ) {
        self.idPublico = UUID()
        self.orden = orden
        self.peso = peso
        self.repeticiones = repeticiones
        self.segundos = segundos
        self.rir = rir
        self.completada = completada
        self.esCalentamiento = esCalentamiento
    }

    /// Cuenta para estadísticas: completada y no de calentamiento.
    var esEfectiva: Bool { completada && !esCalentamiento }

    var volumen: Double { peso * Double(repeticiones) }

    /// Conversión al tipo valor del núcleo.
    var valor: SerieValor {
        SerieValor(
            id: idPublico,
            peso: peso,
            repeticiones: repeticiones,
            segundos: segundos,
            rir: rir,
            completada: completada,
            esCalentamiento: esCalentamiento
        )
    }
}
