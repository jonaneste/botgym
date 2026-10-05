import Foundation

/// Calendario único del proyecto: semana que empieza en lunes.
///
/// Vive en el núcleo y no en la capa de vistas porque el recuento de series
/// semanales depende de dónde empieza la semana, y eso tiene que ser testeable
/// sin arrastrar nada de Apple.
public enum CalendarioEntrenos {

    public static let locale = Locale(identifier: "es_ES")

    /// Calendario ISO 8601 con la semana empezando en lunes.
    public static var es: Calendar {
        var calendario = Calendar(identifier: .iso8601)
        calendario.locale = locale
        calendario.timeZone = .current
        calendario.firstWeekday = 2
        return calendario
    }

    /// Lunes a las 00:00 de la semana en que cae `fecha`.
    public static func inicioDeSemana(de fecha: Date, calendario: Calendar = CalendarioEntrenos.es) -> Date {
        let componentes = calendario.dateComponents([.yearForWeekOfYear, .weekOfYear], from: fecha)
        return calendario.date(from: componentes) ?? calendario.startOfDay(for: fecha)
    }

    /// Lunes a las 00:00 de la semana siguiente.
    public static func inicioDeSemanaSiguiente(de fecha: Date, calendario: Calendar = CalendarioEntrenos.es) -> Date {
        let inicio = inicioDeSemana(de: fecha, calendario: calendario)
        return calendario.date(byAdding: .weekOfYear, value: 1, to: inicio) ?? inicio
    }

    /// Las `cantidad` semanas que acaban en la de `fecha`, de más antigua a más
    /// reciente. Devuelve los lunes.
    public static func ultimasSemanas(
        _ cantidad: Int,
        hasta fecha: Date = Date(),
        calendario: Calendar = CalendarioEntrenos.es
    ) -> [Date] {
        guard cantidad > 0 else { return [] }
        let actual = inicioDeSemana(de: fecha, calendario: calendario)
        return (0..<cantidad).reversed().compactMap { atras in
            calendario.date(byAdding: .weekOfYear, value: -atras, to: actual)
        }
    }

    /// `true` si las dos fechas caen en la misma semana.
    public static func mismaSemana(
        _ a: Date,
        _ b: Date,
        calendario: Calendar = CalendarioEntrenos.es
    ) -> Bool {
        inicioDeSemana(de: a, calendario: calendario) == inicioDeSemana(de: b, calendario: calendario)
    }
}
