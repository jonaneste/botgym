import SwiftUI

/// Los temas de color que se pueden elegir.
///
/// Un tema cambia **solo el color de acento**: lo que se puede tocar, las
/// barras de progreso y los acentos de la interfaz. No toca los cuatro
/// colores de estado —verde hecho, naranja aviso, rojo por debajo, amarillo
/// récord— ni los de región, porque esos significan algo y un tema que los
/// cambiara convertiría «vas bien» en una preferencia estética.
///
/// Por eso ninguno de los temas es verde, naranja, rojo ni amarillo: el acento
/// no puede confundirse con un estado.
enum Tema: String, CaseIterable, Identifiable {
    case azul
    case indigo
    case turquesa
    case grafito
    case rosa

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .azul: return "Azul"
        case .indigo: return "Índigo"
        case .turquesa: return "Turquesa"
        case .grafito: return "Grafito"
        case .rosa: return "Rosa"
        }
    }

    /// Colores del sistema y no valores a mano: responden a «Aumentar
    /// contraste» y cambian entre claro y oscuro, que es justo lo que un
    /// color escrito a pelo no hace.
    var color: Color {
        switch self {
        case .azul: return Color(.systemBlue)
        case .indigo: return Color(.systemIndigo)
        case .turquesa: return Color(.systemTeal)
        case .grafito: return Color(.systemGray)
        case .rosa: return Color(.systemPink)
        }
    }

    static let porDefecto = Tema.azul
}

/// Claro, oscuro, o lo que diga el sistema.
enum AparienciaApp: String, CaseIterable, Identifiable {
    case sistema
    case claro
    case oscuro

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .sistema: return "Automático"
        case .claro: return "Claro"
        case .oscuro: return "Oscuro"
        }
    }

    /// `nil` deja mandar al sistema, que es lo que hay que hacer si no se
    /// elige nada: forzar claro a quien tiene el móvil en oscuro es deslumbrar
    /// a alguien en el gimnasio a las siete de la mañana.
    var esquema: ColorScheme? {
        switch self {
        case .sistema: return nil
        case .claro: return .light
        case .oscuro: return .dark
        }
    }
}
