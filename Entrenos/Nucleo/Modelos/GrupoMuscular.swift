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
    /// El grupo que no es un grupo: un ejercicio que entró al importar una
    /// rutina y todavía no se ha completado.
    ///
    /// Existe para no tener que adivinarlo. Con cualquier grupo real, sus
    /// series se sumarían al recuento semanal de un músculo que no se ha
    /// entrenado, y eso no se ve: la cuenta sale igual de creíble. Así salen
    /// aparte, en su propia fila, hasta que se les ponga el grupo de verdad.
    case sinClasificar

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
        case .sinClasificar: return "Sin clasificar"
        }
    }

    /// Agrupación amplia, para resúmenes de alto nivel.
    ///
    /// `nil` en «sin clasificar», que no pertenece a ninguna región. Así queda
    /// fuera de los objetivos semanales y de cualquier resumen por región sin
    /// tener que acordarse de excluirlo en cada sitio.
    public var region: RegionCorporal? {
        switch self {
        case .pecho, .espalda, .dorsal, .trapecio, .lumbar, .core:
            return .torso
        case .hombroAnterior, .hombroLateral, .hombroPosterior:
            return .hombro
        case .biceps, .triceps, .antebrazo:
            return .brazo
        case .cuadriceps, .isquios, .gluteo, .gemelo:
            return .pierna
        case .sinClasificar:
            return nil
        }
    }

    /// Los grupos que se pueden elegir y a los que se les puede poner un
    /// objetivo. Es `allCases` sin «sin clasificar».
    public static let clasificados: [GrupoMuscular] = allCases.filter { $0 != .sinClasificar }
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
