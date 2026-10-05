import Foundation

/// Una serie ya ejecutada, como valor puro.
///
/// Es el tipo que consumen los servicios de progresión, récords y volumen.
/// Los modelos de SwiftData se convierten a esto antes de pasar por la lógica,
/// de forma que toda la lógica se puede testear sin base de datos.
public struct SerieValor: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    /// Carga en kilogramos. 0 en ejercicios a peso corporal sin lastre.
    public var peso: Double
    /// Repeticiones hechas. En ejercicios de tiempo se queda a 0.
    public var repeticiones: Int
    /// Segundos aguantados, solo en ejercicios de tipo `.tiempo`.
    public var segundos: Int?
    /// Repeticiones en reserva, si se anotaron.
    public var rir: Int?
    public var completada: Bool
    /// Las series de calentamiento no cuentan para progresión ni para récords.
    public var esCalentamiento: Bool

    public init(
        id: UUID = UUID(),
        peso: Double,
        repeticiones: Int = 0,
        segundos: Int? = nil,
        rir: Int? = nil,
        completada: Bool = false,
        esCalentamiento: Bool = false
    ) {
        self.id = id
        self.peso = peso
        self.repeticiones = repeticiones
        self.segundos = segundos
        self.rir = rir
        self.completada = completada
        self.esCalentamiento = esCalentamiento
    }

    /// Serie que cuenta para estadísticas: completada y no de calentamiento.
    public var esEfectiva: Bool { completada && !esCalentamiento }

    /// Volumen de la serie en kg levantados (kg × reps).
    public var volumen: Double { peso * Double(repeticiones) }

    /// El valor que se compara contra el rango objetivo, según el tipo de
    /// registro: segundos en los isométricos, repeticiones en todo lo demás.
    public func logro(tipo: TipoRegistro) -> Int {
        tipo.esTiempo ? (segundos ?? 0) : repeticiones
    }
}
