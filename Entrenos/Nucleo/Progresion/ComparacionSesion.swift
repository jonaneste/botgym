import Foundation

/// La sesión que acaba de cerrarse, frente a la última vez que se hizo la
/// misma rutina.
///
/// Existe para la pantalla de cierre. Cuatro cifras sueltas —duración, series,
/// volumen, ejercicios— no dicen si el entreno fue bueno: dicen que pasó.
/// «340 kg más que la última vez» sí, y es un dato, no un ánimo inventado.
public struct ComparacionSesion: Equatable, Sendable {
    public var seriesAhora: Int
    public var seriesAntes: Int
    public var volumenAhora: Double
    public var volumenAntes: Double
    /// Cuándo fue esa última vez, para poder decirlo.
    public var fechaAnterior: Date

    public init(
        seriesAhora: Int,
        seriesAntes: Int,
        volumenAhora: Double,
        volumenAntes: Double,
        fechaAnterior: Date
    ) {
        self.seriesAhora = seriesAhora
        self.seriesAntes = seriesAntes
        self.volumenAhora = volumenAhora
        self.volumenAntes = volumenAntes
        self.fechaAnterior = fechaAnterior
    }

    public var diferenciaSeries: Int { seriesAhora - seriesAntes }

    public var diferenciaVolumen: Double { volumenAhora - volumenAntes }

    /// Tanto por ciento de volumen respecto a la vez anterior. `nil` si la
    /// anterior fue de cero volumen, que es lo que pasa en una sesión a peso
    /// corporal: dividir daría infinito y de ahí a un `Int` se cierra la app.
    public var porcentajeVolumen: Double? {
        guard volumenAntes > 0 else { return nil }
        return (diferenciaVolumen / volumenAntes) * 100
    }

    /// Si hubo mejora en lo que se mide: más volumen, o las mismas series con
    /// más volumen. Un empate exacto no es mejora.
    public var esMejora: Bool {
        diferenciaVolumen > 0 || (diferenciaVolumen == 0 && diferenciaSeries > 0)
    }

    /// Si no se movió nada. Con el mismo peso y las mismas repeticiones sale
    /// el mismo volumen, y eso pasa de verdad.
    public var esIgual: Bool {
        diferenciaSeries == 0 && diferenciaVolumen == 0
    }
}

public enum ComparadorSesiones {

    /// Compara una sesión recién cerrada con la anterior de la misma rutina.
    ///
    /// Devuelve `nil` cuando no hay con qué comparar —primera vez con esa
    /// rutina—, porque «0 kg más que la última vez» sería mentira: no hubo
    /// última vez.
    ///
    /// También devuelve `nil` si la sesión anterior no tiene ninguna serie:
    /// comparar contra un entreno vacío daría una mejora del infinito por
    /// ciento, que no significa nada.
    public static func comparar(
        seriesAhora: Int,
        volumenAhora: Double,
        anterior: (fecha: Date, series: Int, volumen: Double)?
    ) -> ComparacionSesion? {
        guard let anterior, anterior.series > 0 else { return nil }
        guard volumenAhora.isFinite, anterior.volumen.isFinite else { return nil }
        return ComparacionSesion(
            seriesAhora: seriesAhora,
            seriesAntes: anterior.series,
            volumenAhora: volumenAhora,
            volumenAntes: anterior.volumen,
            fechaAnterior: anterior.fecha
        )
    }
}
