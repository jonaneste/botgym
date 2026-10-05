import Foundation
import SwiftData

/// Ajustes de la app. Hay una sola fila; `Ajustes.cargar(en:)` la crea si falta.
@Model
final class Ajustes {
    var idPublico: UUID = UUID()

    /// Incremento por defecto al subir peso en barra, en kg.
    var incrementoBarra: Double = 2.5
    /// Incremento por defecto en poleas y máquinas, en kg.
    var incrementoPolea: Double = 2.5
    var incrementoMaquina: Double = 2.5
    /// Incremento en segundos para los ejercicios isométricos.
    var incrementoTiempo: Int = 5

    /// Mancuernas disponibles en el gimnasio, en kg. La progresión salta al
    /// siguiente valor de esta lista en lugar de sumar una cantidad fija.
    var mancuernasDisponibles: [Double] = [
        2, 4, 6, 8, 10, 12, 14, 16, 18, 20,
        22.5, 25, 27.5, 30, 32.5, 35, 40, 45, 50,
    ]

    /// RIR objetivo por defecto, para los ejercicios donde la rutina no lo fija.
    var rirPorDefectoMin: Int = 1
    var rirPorDefectoMax: Int = 2

    var descansoPorDefecto: Int = 90

    /// Objetivo de series semanales por grupo muscular, como pares
    /// "grupo:series". Se guarda así porque SwiftData en iOS 17 no lleva bien
    /// los diccionarios con claves de tipo enum.
    var objetivosSemanalesRaw: [String] = []

    /// Avisar con una notificación local cuando acaba el descanso.
    var notificarFinDescanso: Bool = true
    /// Vibrar al terminar el descanso.
    var vibrarFinDescanso: Bool = true
    /// Arrancar el descanso solo al marcar una serie.
    var descansoAutomatico: Bool = true

    /// Interruptor de HealthKit. Apagado por defecto: con un Apple ID gratuito
    /// la capability no se puede activar, y la app tiene que funcionar igual.
    var healthKitActivado: Bool = false

    /// Escribir una estimación de calorías en los entrenos que van a Salud.
    ///
    /// Apagado por defecto. Si entrenas con el reloj puesto, el dato real lo
    /// escribe Zepp y no hace falta estimar nada.
    var estimarCalorias: Bool = false
    /// Peso corporal en kg, para la fórmula MET. 0 = sin dato, y entonces no
    /// se estima.
    var pesoCorporal: Double = 0
    /// MET del entrenamiento de fuerza. 4,5 es una sesión de hipertrofia
    /// normal con descansos.
    var metFuerza: Double = EstimadorEnergia.metPorDefecto

    /// No escribir en Salud si ya hay un entrenamiento de fuerza de otra app
    /// solapado, típicamente el que registra el reloj.
    var evitarDuplicadosEnSalud: Bool = true

    init() {
        self.idPublico = UUID()
    }

    // MARK: - Objetivos semanales

    var objetivosSemanales: [GrupoMuscular: Int] {
        get {
            var resultado: [GrupoMuscular: Int] = [:]
            for par in objetivosSemanalesRaw {
                let trozos = par.split(separator: ":", maxSplits: 1)
                guard trozos.count == 2,
                      let grupo = GrupoMuscular(rawValue: String(trozos[0])),
                      let series = Int(trozos[1]) else { continue }
                resultado[grupo] = series
            }
            return resultado
        }
        set {
            objetivosSemanalesRaw = newValue
                .map { "\($0.key.rawValue):\($0.value)" }
                .sorted()
        }
    }

    /// Reglas de incremento con las que alimentar la lógica de progresión.
    var reglasIncremento: ReglasIncremento {
        ReglasIncremento(
            incrementoBarra: incrementoBarra,
            incrementoPolea: incrementoPolea,
            incrementoMaquina: incrementoMaquina,
            incrementoTiempo: incrementoTiempo,
            mancuernasDisponibles: mancuernasDisponibles
        )
    }

    // MARK: - Carga

    /// Devuelve la fila de ajustes, creándola la primera vez.
    static func cargar(en contexto: ModelContext) -> Ajustes {
        let descriptor = FetchDescriptor<Ajustes>()
        if let existentes = try? contexto.fetch(descriptor), let primero = existentes.first {
            return primero
        }
        let nuevos = Ajustes()
        contexto.insert(nuevos)
        return nuevos
    }
}
