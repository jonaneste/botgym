import Foundation
import Observation

/// Temporizador de descanso entre series.
///
/// El estado que importa (`fechaFin`) vive en el `Entreno` de SwiftData, no
/// aquí: así el descanso sigue contando bien aunque la app se cierre y se
/// vuelva a abrir a los dos minutos. Esta clase solo se encarga de avisar
/// cuando llega el momento mientras la app está en primer plano.
@MainActor
@Observable
final class TemporizadorDescanso {

    /// Momento en que acaba el descanso. `nil` si no hay descanso corriendo.
    private(set) var fechaFin: Date?
    /// Duración total programada, para pintar la barra de progreso.
    private(set) var duracionTotal: TimeInterval = 0
    private(set) var nombreEjercicio: String = ""

    /// Se dispara al llegar a cero estando en primer plano.
    var alTerminar: (() -> Void)?

    private var tarea: Task<Void, Never>?

    var activo: Bool {
        guard let fechaFin else { return false }
        return fechaFin > Date()
    }

    /// Segundos que quedan, nunca negativos.
    var restante: TimeInterval {
        guard let fechaFin else { return 0 }
        return max(0, fechaFin.timeIntervalSinceNow)
    }

    /// Progreso de 0 a 1, para la barra.
    var progreso: Double {
        guard duracionTotal > 0 else { return 0 }
        return min(1, max(0, (duracionTotal - restante) / duracionTotal))
    }

    // MARK: - Control

    func empezar(segundos: Int, nombreEjercicio: String) {
        let fin = Date().addingTimeInterval(TimeInterval(segundos))
        reanudar(hasta: fin, duracionTotal: TimeInterval(segundos), nombreEjercicio: nombreEjercicio)
    }

    /// Retoma un descanso que ya estaba corriendo, al volver a abrir la app.
    func reanudar(hasta fin: Date, duracionTotal total: TimeInterval, nombreEjercicio nombre: String) {
        guard fin > Date() else {
            parar()
            return
        }
        fechaFin = fin
        duracionTotal = total
        nombreEjercicio = nombre
        programarAviso()
    }

    func parar() {
        tarea?.cancel()
        tarea = nil
        fechaFin = nil
        duracionTotal = 0
        nombreEjercicio = ""
    }

    /// Añade o quita segundos al descanso en curso.
    func ajustar(segundos: Int) {
        guard let actual = fechaFin else { return }
        let nuevo = actual.addingTimeInterval(TimeInterval(segundos))
        guard nuevo > Date() else {
            parar()
            return
        }
        fechaFin = nuevo
        duracionTotal = max(duracionTotal + TimeInterval(segundos), 1)
        programarAviso()
    }

    // MARK: - Aviso en primer plano

    private func programarAviso() {
        tarea?.cancel()
        guard let fechaFin else { return }
        let espera = fechaFin.timeIntervalSinceNow
        guard espera > 0 else { return }

        tarea = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(espera * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            self.fechaFin = nil
            self.duracionTotal = 0
            self.alTerminar?()
        }
    }
}
