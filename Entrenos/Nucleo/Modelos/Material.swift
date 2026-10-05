import Foundation

/// Material con el que se ejecuta un ejercicio. Determina cómo sube la carga
/// cuando la doble progresión sugiere subir peso.
public enum Material: String, Codable, CaseIterable, Sendable {
    case barra
    case mancuerna
    case polea
    case maquina
    case pesoCorporal
    case otro

    public var nombre: String {
        switch self {
        case .barra: return "Barra"
        case .mancuerna: return "Mancuerna"
        case .polea: return "Polea"
        case .maquina: return "Máquina"
        case .pesoCorporal: return "Peso corporal"
        case .otro: return "Otro"
        }
    }

    /// Símbolo de SF Symbols asociado, para las listas de ejercicios.
    public var icono: String {
        switch self {
        case .barra: return "figure.strengthtraining.traditional"
        case .mancuerna: return "dumbbell"
        case .polea: return "cable.connector"
        case .maquina: return "gearshape.2"
        case .pesoCorporal: return "figure.gymnastics"
        case .otro: return "questionmark.circle"
        }
    }
}
