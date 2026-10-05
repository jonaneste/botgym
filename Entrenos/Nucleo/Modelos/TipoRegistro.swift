import Foundation

/// Cómo se anota una serie de este ejercicio.
public enum TipoRegistro: String, Codable, CaseIterable, Sendable {
    /// Repeticiones normales: "10 reps".
    case repeticiones
    /// Tiempo bajo tensión en segundos: el isométrico de cuádriceps, planchas.
    case tiempo
    /// Repeticiones por cada lado: landmine press, remo unilateral.
    case repeticionesPorLado

    public var nombre: String {
        switch self {
        case .repeticiones: return "Repeticiones"
        case .tiempo: return "Tiempo"
        case .repeticionesPorLado: return "Repeticiones por lado"
        }
    }

    /// Unidad corta para pintar junto a un número: "10 reps", "30 s".
    public var unidadCorta: String {
        switch self {
        case .repeticiones: return "reps"
        case .tiempo: return "s"
        case .repeticionesPorLado: return "reps/lado"
        }
    }

    /// Indica si el objetivo se mide en segundos en lugar de repeticiones.
    public var esTiempo: Bool { self == .tiempo }
}
