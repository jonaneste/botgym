import Foundation
import SwiftData

/// Un hueco de ejercicio dentro de una rutina, con su objetivo.
///
/// Las superseries se modelan con `idSuperserie`: los elementos consecutivos
/// que comparten el mismo identificador forman un grupo. No hace falta una
/// entidad aparte.
@Model
final class ElementoRutina {
    var idPublico: UUID = UUID()
    var orden: Int = 0

    var ejercicio: Ejercicio?
    var rutina: Rutina?

    var seriesObjetivo: Int = 3
    /// Series de aproximación que la rutina pone antes de las de trabajo.
    ///
    /// Se crean marcadas como calentamiento, así que no cuentan para
    /// progresión, récords ni series semanales. Están aquí y no en el
    /// historial porque son parte del plan: "cuatro de banca, con dos de
    /// aproximación antes".
    var seriesCalentamiento: Int = 0
    /// Repeticiones o segundos, según el `tipoRegistro` del ejercicio.
    /// Ambos a `nil` significa series libres, sin rango.
    var objetivoMin: Int?
    var objetivoMax: Int?
    var rirMin: Int?
    var rirMax: Int?
    var descansoSegundos: Int = 90
    var notas: String = ""

    /// Identificador del grupo de superserie, o `nil` si el ejercicio va solo.
    var idSuperserie: UUID?

    init(
        ejercicio: Ejercicio?,
        orden: Int,
        seriesObjetivo: Int,
        seriesCalentamiento: Int = 0,
        objetivoMin: Int? = nil,
        objetivoMax: Int? = nil,
        rirMin: Int? = nil,
        rirMax: Int? = nil,
        descansoSegundos: Int = 90,
        notas: String = "",
        idSuperserie: UUID? = nil
    ) {
        self.idPublico = UUID()
        self.ejercicio = ejercicio
        self.orden = orden
        self.seriesObjetivo = seriesObjetivo
        self.seriesCalentamiento = seriesCalentamiento
        self.objetivoMin = objetivoMin
        self.objetivoMax = objetivoMax
        self.rirMin = rirMin
        self.rirMax = rirMax
        self.descansoSegundos = descansoSegundos
        self.notas = notas
        self.idSuperserie = idSuperserie
    }

    /// El objetivo como tipo valor, para pasárselo a la lógica del núcleo.
    var objetivo: ObjetivoEjercicio {
        ObjetivoEjercicio(
            series: seriesObjetivo,
            objetivoMin: objetivoMin,
            objetivoMax: objetivoMax,
            rirMin: rirMin,
            rirMax: rirMax,
            descansoSegundos: descansoSegundos
        )
    }

    var tipoRegistro: TipoRegistro {
        ejercicio?.tipoRegistro ?? .repeticiones
    }

    /// Resumen del objetivo: "4 × 8-10 · RIR 2-3".
    var resumenObjetivo: String {
        var partes: [String] = []
        if seriesCalentamiento > 0 { partes.append("\(seriesCalentamiento) cal.") }
        partes.append("\(seriesObjetivo) × \(objetivo.textoRango(tipo: tipoRegistro))")
        let rir = objetivo.textoRIR
        if !rir.isEmpty { partes.append(rir) }
        return partes.joined(separator: " · ")
    }
}
