import Foundation
import UIKit

/// Vibraciones. Centralizadas aquí para poder silenciarlas desde Ajustes.
@MainActor
enum Haptica {

    /// Al marcar una serie como completada.
    static func serieCompletada() {
        let generador = UIImpactFeedbackGenerator(style: .medium)
        generador.prepare()
        generador.impactOccurred()
    }

    /// Al terminar el descanso. Doble golpe, para notarlo sin mirar.
    static func finDescanso() {
        let generador = UINotificationFeedbackGenerator()
        generador.prepare()
        generador.notificationOccurred(.success)
    }

    /// Al batir un récord personal.
    static func record() {
        let generador = UINotificationFeedbackGenerator()
        generador.prepare()
        generador.notificationOccurred(.warning)
    }

    static func ligera() {
        let generador = UIImpactFeedbackGenerator(style: .light)
        generador.prepare()
        generador.impactOccurred()
    }
}
