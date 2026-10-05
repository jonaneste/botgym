import Foundation

/// Grupos musculares usados para contar series semanales.
///
/// El hombro va dividido en tres porque en esta rutina hay mucho volumen de
/// elevaciones laterales, face pull y pájaros, y contarlos como un solo
/// "hombro" escondería el desequilibrio.
public enum GrupoMuscular: String, Codable, CaseIterable, Sendable {
    case pecho
    case espalda
    case dorsal
    case trapecio
    case hombroAnterior
    case hombroLateral
    case hombroPosterior
    case biceps
    case triceps
    case antebrazo
    case cuadriceps
    case isquios
    case gluteo
    case gemelo
    case core
    case lumbar

    public var nombre: String {
        switch self {
        case .pecho: return "Pecho"
        case .espalda: return "Espalda"
        case .dorsal: return "Dorsal"
        case .trapecio: return "Trapecio"
        case .hombroAnterior: return "Hombro anterior"
        case .hombroLateral: return "Hombro lateral"
        case .hombroPosterior: return "Hombro posterior"
        case .biceps: return "Bíceps"
        case .triceps: return "Tríceps"
        case .antebrazo: return "Antebrazo"
        case .cuadriceps: return "Cuádriceps"
        case .isquios: return "Isquiosurales"
        case .gluteo: return "Glúteo"
        case .gemelo: return "Gemelo"
        case .core: return "Core"
        case .lumbar: return "Lumbar"
        }
    }

    /// Agrupación amplia, para resúmenes de alto nivel.
    public var region: RegionCorporal {
        switch self {
        case .pecho, .espalda, .dorsal, .trapecio, .lumbar, .core:
            return .torso
        case .hombroAnterior, .hombroLateral, .hombroPosterior:
            return .hombro
        case .biceps, .triceps, .antebrazo:
            return .brazo
        case .cuadriceps, .isquios, .gluteo, .gemelo:
            return .pierna
        }
    }
}

public enum RegionCorporal: String, Codable, CaseIterable, Sendable {
    case torso
    case hombro
    case brazo
    case pierna

    public var nombre: String {
        switch self {
        case .torso: return "Torso"
        case .hombro: return "Hombro"
        case .brazo: return "Brazo"
        case .pierna: return "Pierna"
        }
    }
}
