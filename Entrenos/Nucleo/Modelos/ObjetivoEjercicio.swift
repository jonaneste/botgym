import Foundation

/// Lo que la rutina pide para un ejercicio: series, rango y descanso.
///
/// `objetivoMin` y `objetivoMax` son deliberadamente neutros: son repeticiones
/// en la mayoría de ejercicios y segundos en los de tipo `.tiempo`. Quien los
/// interpreta es el `TipoRegistro` del ejercicio. Ambos a `nil` significan
/// series libres, sin rango (por ejemplo la rueda abdominal).
public struct ObjetivoEjercicio: Codable, Hashable, Sendable {
    public var series: Int
    public var objetivoMin: Int?
    public var objetivoMax: Int?
    public var rirMin: Int?
    public var rirMax: Int?
    public var descansoSegundos: Int

    public init(
        series: Int,
        objetivoMin: Int? = nil,
        objetivoMax: Int? = nil,
        rirMin: Int? = nil,
        rirMax: Int? = nil,
        descansoSegundos: Int = 90
    ) {
        self.series = series
        self.objetivoMin = objetivoMin
        self.objetivoMax = objetivoMax
        self.rirMin = rirMin
        self.rirMax = rirMax
        self.descansoSegundos = descansoSegundos
    }

    /// Series libres: sin rango objetivo definido.
    public var sinRango: Bool { objetivoMin == nil && objetivoMax == nil }

    /// Tope del rango, que es el umbral de la doble progresión.
    public var tope: Int? { objetivoMax ?? objetivoMin }

    /// Suelo del rango.
    public var suelo: Int? { objetivoMin ?? objetivoMax }

    /// Texto del rango tal y como se pinta en la app: "8-10", "15", "30-45 s".
    public func textoRango(tipo: TipoRegistro) -> String {
        guard let suelo else { return "libre" }
        let unidad = tipo.esTiempo ? " s" : ""
        if let tope, tope != suelo {
            return "\(suelo)-\(tope)\(unidad)"
        }
        return "\(suelo)\(unidad)"
    }

    /// Texto del RIR objetivo: "RIR 2-3", "RIR 2" o cadena vacía si no hay.
    public var textoRIR: String {
        guard let rirMin else { return "" }
        if let rirMax, rirMax != rirMin {
            return "RIR \(rirMin)-\(rirMax)"
        }
        return "RIR \(rirMin)"
    }
}
