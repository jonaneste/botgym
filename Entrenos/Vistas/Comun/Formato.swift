import Foundation

/// Formateo de números, pesos, duraciones y fechas.
///
/// Todo va forzado a `es_ES`: coma decimal y fechas en español,
/// independientemente del idioma que tenga puesto el iPhone.
enum Formato {

    static let localeES = CalendarioEntrenos.locale

    // MARK: - Pesos

    /// Peso sin decimales innecesarios: "60 kg", "22,5 kg".
    static func peso(_ kg: Double, conUnidad: Bool = true) -> String {
        let numero = numeroCorto(kg)
        return conUnidad ? "\(numero) kg" : numero
    }

    /// Número con hasta un decimal, y sin el ",0" cuando es redondo.
    static func numeroCorto(_ valor: Double) -> String {
        let formateador = NumberFormatter()
        formateador.locale = localeES
        formateador.numberStyle = .decimal
        formateador.minimumFractionDigits = 0
        formateador.maximumFractionDigits = valor == valor.rounded() ? 0 : 1
        formateador.usesGroupingSeparator = false
        return formateador.string(from: NSNumber(value: valor)) ?? "\(valor)"
    }

    /// Volumen total, con separador de miles: "12.450 kg".
    static func volumen(_ kg: Double) -> String {
        let formateador = NumberFormatter()
        formateador.locale = localeES
        formateador.numberStyle = .decimal
        formateador.maximumFractionDigits = 0
        formateador.usesGroupingSeparator = true
        let numero = formateador.string(from: NSNumber(value: kg)) ?? "0"
        return "\(numero) kg"
    }

    // MARK: - Duraciones

    /// Cronómetro del entreno: "1:23:45" o "12:05".
    static func cronometro(_ segundos: TimeInterval) -> String {
        let total = Int(max(0, segundos.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// Cuenta atrás del descanso: "1:30".
    static func cuentaAtras(_ segundos: TimeInterval) -> String {
        let total = Int(max(0, segundos.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Duración en prosa para el historial: "1 h 12 min", "48 min".
    static func duracionLarga(_ segundos: TimeInterval) -> String {
        let total = Int(max(0, segundos.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 && m > 0 { return "\(h) h \(m) min" }
        if h > 0 { return "\(h) h" }
        if m > 0 { return "\(m) min" }
        return "\(total) s"
    }

    /// Descanso configurado: "2:30" si pasa del minuto, "45 s" si no.
    static func descanso(_ segundos: Int) -> String {
        if segundos < 60 { return "\(segundos) s" }
        let m = segundos / 60
        let s = segundos % 60
        return s == 0 ? "\(m) min" : String(format: "%d:%02d", m, s)
    }

    // MARK: - Fechas

    /// "lunes, 5 de octubre", capitalizado.
    static func fechaLarga(_ fecha: Date) -> String {
        let formateador = DateFormatter()
        formateador.locale = localeES
        formateador.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return capitalizarPrimera(formateador.string(from: fecha))
    }

    /// "5 oct 2026".
    static func fechaCorta(_ fecha: Date) -> String {
        let formateador = DateFormatter()
        formateador.locale = localeES
        formateador.setLocalizedDateFormatFromTemplate("d MMM y")
        return formateador.string(from: fecha)
    }

    /// "18:30".
    static func hora(_ fecha: Date) -> String {
        let formateador = DateFormatter()
        formateador.locale = localeES
        formateador.setLocalizedDateFormatFromTemplate("HH:mm")
        return formateador.string(from: fecha)
    }

    /// Fecha relativa para el historial: "Hoy", "Ayer" o la fecha larga.
    static func fechaRelativa(_ fecha: Date, ahora: Date = Date()) -> String {
        let calendario = calendarioES
        if calendario.isDateInToday(fecha) { return "Hoy" }
        if calendario.isDateInYesterday(fecha) { return "Ayer" }
        let dias = calendario.dateComponents([.day], from: calendario.startOfDay(for: fecha), to: calendario.startOfDay(for: ahora)).day ?? 0
        if dias > 1 && dias < 7 {
            return capitalizarPrimera(nombreDiaSemana(fecha))
        }
        return fechaCorta(fecha)
    }

    /// "5 oct", para los ejes de las gráficas.
    static func diaYMes(_ fecha: Date) -> String {
        let formateador = DateFormatter()
        formateador.locale = localeES
        formateador.setLocalizedDateFormatFromTemplate("d MMM")
        return formateador.string(from: fecha)
    }

    static func nombreDiaSemana(_ fecha: Date) -> String {
        let formateador = DateFormatter()
        formateador.locale = localeES
        formateador.setLocalizedDateFormatFromTemplate("EEEE")
        return formateador.string(from: fecha)
    }

    /// Calendario español: la semana empieza en lunes.
    ///
    /// Delega en el núcleo: el recuento de series semanales depende de dónde
    /// empieza la semana, así que solo puede haber una definición.
    static var calendarioES: Calendar { CalendarioEntrenos.es }

    // MARK: - Utilidades

    static func capitalizarPrimera(_ texto: String) -> String {
        guard let primera = texto.first else { return texto }
        return String(primera).uppercased(with: localeES) + String(texto.dropFirst())
    }

    /// Lo que se hizo en una serie: "60 kg × 9", "40 s", "× 12".
    static func resumenSerie(peso: Double, repeticiones: Int, segundos: Int?, tipo: TipoRegistro) -> String {
        if tipo.esTiempo {
            let tiempo = "\(segundos ?? 0) s"
            return peso > 0 ? "\(Formato.peso(peso)) × \(tiempo)" : tiempo
        }
        if peso > 0 {
            return "\(Formato.peso(peso)) × \(repeticiones)"
        }
        return "× \(repeticiones)"
    }
}
