import Foundation
import UserNotifications

/// Notificaciones locales para el fin del descanso.
///
/// Las notificaciones **locales** no necesitan ninguna capability de pago:
/// funcionan con un Apple ID gratuito. Solo las remotas (push) requieren
/// el Apple Developer Program.
@MainActor
final class GestorNotificaciones {
    static let shared = GestorNotificaciones()

    private let identificadorDescanso = "fin-descanso"
    private var permisoConcedido = false

    private init() {}

    /// Pide permiso la primera vez. Da igual llamarlo varias veces.
    func solicitarPermiso() async {
        let centro = UNUserNotificationCenter.current()
        do {
            permisoConcedido = try await centro.requestAuthorization(options: [.alert, .sound])
        } catch {
            permisoConcedido = false
        }
    }

    /// Programa el aviso de fin de descanso.
    func programarFinDescanso(en fecha: Date, nombreEjercicio: String) async {
        let centro = UNUserNotificationCenter.current()
        await cancelarFinDescanso()

        let segundos = fecha.timeIntervalSinceNow
        guard segundos > 0.5 else { return }

        let contenido = UNMutableNotificationContent()
        contenido.title = "Descanso terminado"
        contenido.body = nombreEjercicio.isEmpty
            ? "Toca la siguiente serie."
            : "Toca la siguiente serie de \(nombreEjercicio)."
        contenido.sound = .default
        contenido.interruptionLevel = .timeSensitive

        let disparador = UNTimeIntervalNotificationTrigger(timeInterval: segundos, repeats: false)
        let peticion = UNNotificationRequest(
            identifier: identificadorDescanso,
            content: contenido,
            trigger: disparador
        )
        try? await centro.add(peticion)
    }

    func cancelarFinDescanso() async {
        let centro = UNUserNotificationCenter.current()
        centro.removePendingNotificationRequests(withIdentifiers: [identificadorDescanso])
        centro.removeDeliveredNotifications(withIdentifiers: [identificadorDescanso])
    }
}
