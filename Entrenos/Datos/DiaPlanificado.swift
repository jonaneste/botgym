import Foundation
import SwiftData

/// Un día del plan, guardado.
///
/// El plan se escribe fuera de la app y entra por la misma carpeta de iCloud
/// que las rutinas. Lo que la app añade es lo único que no puede venir de un
/// archivo: si el día se hizo, y qué se hizo de verdad.
@Model
final class DiaPlanificado {
    /// Medianoche del día. Es la identidad: un día del calendario es un día.
    var fecha: Date = Date()

    /// Enum persistido como `String` crudo: en iOS 17 SwiftData no filtra ni
    /// ordena de forma fiable por propiedades de tipo enum.
    var tipoRaw: String = TipoDiaPlan.descanso.rawValue

    var titulo: String = ""
    var notas: String = ""

    /// Kilómetros previstos, si el día los lleva.
    var kilometros: Double?

    /// Rutina que cubre la parte de gimnasio, por nombre.
    var nombreRutina: String?

    /// Nombre del plan al que pertenece, para poder sustituirlo entero.
    var nombrePlan: String = ""

    // MARK: - Lo que pone el usuario

    /// Marcado a mano. Para el gimnasio es un atajo; para la carrera es la
    /// única forma de dejar constancia, porque la app no crea carreras: las
    /// lee de Salud, y con cuenta gratuita puede que no llegue ninguna.
    var hecho: Bool = false

    /// Kilómetros que se corrieron de verdad, si se anotaron.
    var kilometrosHechos: Double?

    init(
        fecha: Date,
        tipo: TipoDiaPlan,
        titulo: String,
        notas: String = "",
        kilometros: Double? = nil,
        nombreRutina: String? = nil,
        nombrePlan: String = ""
    ) {
        self.fecha = fecha
        self.tipoRaw = tipo.rawValue
        self.titulo = titulo
        self.notas = notas
        self.kilometros = kilometros
        self.nombreRutina = nombreRutina
        self.nombrePlan = nombrePlan
    }

    var tipo: TipoDiaPlan {
        get { TipoDiaPlan(rawValue: tipoRaw) ?? .descanso }
        set { tipoRaw = newValue.rawValue }
    }

    var valor: DiaPlanValor {
        DiaPlanValor(
            fecha: fecha,
            tipo: tipo,
            titulo: titulo,
            notas: notas,
            kilometros: kilometros,
            nombreRutina: nombreRutina
        )
    }

    /// Lo que se enseña de los kilómetros: los hechos manda sobre los
    /// previstos, porque una tirada de 12 que acabó en 9 fueron 9.
    var kilometrosAEnseñar: Double? {
        kilometrosHechos ?? kilometros
    }
}
