import Foundation
import SwiftData

/// Estado de un entreno.
enum EstadoEntreno: String, Codable, CaseIterable, Sendable {
    /// Hay un entreno abierto. Al arrancar la app se ofrece reanudarlo.
    case enCurso
    case finalizado
}

// Valores crudos del estado, para usarlos dentro de un `#Predicate`.
//
// `#Predicate` es un macro puramente sintáctico: no tiene información de
// tipos, así que convierte cualquier cadena de acceso a miembro en un key
// path del modelo. Escribir `EstadoEntreno.finalizado.rawValue` dentro del
// predicado se expande a `keyPath: \.finalizado` y no compila. Solo los
// identificadores simples se capturan como valor, de ahí estas constantes.
//
// Siguen derivando del enum, así que renombrar un caso rompe la compilación
// en lugar de dejar la consulta muda.
let rawEntrenoEnCurso = EstadoEntreno.enCurso.rawValue
let rawEntrenoFinalizado = EstadoEntreno.finalizado.rawValue

/// Una sesión de entrenamiento.
///
/// El entreno en curso es un `Entreno` con `estado == .enCurso` que se va
/// escribiendo en SwiftData serie a serie. Por eso no se pierde si la app se
/// cierra: no hay nada que "guardar al salir".
@Model
final class Entreno {
    var idPublico: UUID = UUID()
    var nombre: String = ""
    var notas: String = ""
    var fechaInicio: Date = Date()
    /// Se rellena al finalizar. Mientras es `nil`, el entreno sigue abierto.
    var fechaFin: Date?

    // Interno, no privado: los `#Predicate` del repositorio filtran por él.
    var estadoRaw: String = EstadoEntreno.enCurso.rawValue

    /// Nombre de la rutina de origen, copiado. Si luego borras la rutina, el
    /// historial sigue sabiendo de dónde salió este entreno.
    var nombreRutinaOrigen: String?
    var idRutinaOrigen: UUID?

    /// Molestia articular 0-10 anotada al terminar. `nil` = no anotada.
    var molestiaHombro: Int?
    var molestiaRodilla: Int?

    /// Momento en el que termina el descanso en curso. Se persiste para que el
    /// temporizador siga contando bien tras cerrar y reabrir la app.
    var descansoHasta: Date?
    var descansoDuracion: Int?

    /// UUID del entreno escrito en Apple Health, para no duplicarlo. Fase 3.
    var idHealthKit: String?

    @Relationship(deleteRule: .cascade, inverse: \EjercicioEntreno.entreno)
    var ejercicios: [EjercicioEntreno] = []

    init(
        nombre: String,
        fechaInicio: Date = Date(),
        nombreRutinaOrigen: String? = nil,
        idRutinaOrigen: UUID? = nil
    ) {
        self.idPublico = UUID()
        self.nombre = nombre
        self.fechaInicio = fechaInicio
        self.nombreRutinaOrigen = nombreRutinaOrigen
        self.idRutinaOrigen = idRutinaOrigen
        self.estadoRaw = EstadoEntreno.enCurso.rawValue
    }

    var estado: EstadoEntreno {
        get { EstadoEntreno(rawValue: estadoRaw) ?? .finalizado }
        set { estadoRaw = newValue.rawValue }
    }

    var ejerciciosOrdenados: [EjercicioEntreno] {
        ejercicios.sorted { $0.orden < $1.orden }
    }

    // MARK: - Derivados

    /// Duración del entreno. Si sigue en curso, cuenta hasta ahora.
    var duracion: TimeInterval {
        (fechaFin ?? Date()).timeIntervalSince(fechaInicio)
    }

    var duracionFinal: TimeInterval? {
        guard let fechaFin else { return nil }
        return fechaFin.timeIntervalSince(fechaInicio)
    }

    /// Volumen total en kg levantados: suma de peso × reps de las series
    /// completadas que no son calentamiento.
    var volumenTotal: Double {
        ejercicios.reduce(0) { $0 + $1.volumen }
    }

    var seriesCompletadas: Int {
        ejercicios.reduce(0) { $0 + $1.seriesCompletadas }
    }

    var seriesTotales: Int {
        ejercicios.reduce(0) { $0 + $1.series.count }
    }

    /// Todas las series completadas, para alimentar récords y volumen.
    var seriesEfectivas: [SerieRegistrada] {
        ejercicios.flatMap { $0.series }.filter(\.esEfectiva)
    }

    var estaEnCurso: Bool { estado == .enCurso }

    /// Hay un descanso corriendo ahora mismo.
    var descansoActivo: Bool {
        guard let descansoHasta else { return false }
        return descansoHasta > Date()
    }
}
