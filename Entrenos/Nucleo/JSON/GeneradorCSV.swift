import Foundation

/// Genera el CSV del historial: una fila por serie.
///
/// Se usa punto y coma como separador y coma decimal, que es lo que espera
/// Excel en español. Con coma de separador, un Excel con configuración
/// española mete todo en una sola columna. Para leerlo con herramientas
/// anglosajonas está la exportación JSON, que no tiene esta ambigüedad.
public enum GeneradorCSV {

    public static let separador = ";"

    public static let columnas = [
        "fecha", "hora", "entreno", "rutina",
        "ejercicio", "grupo", "tipo",
        "serie", "calentamiento",
        "peso_kg", "repeticiones", "segundos", "rir", "volumen_kg",
        "notas_ejercicio", "notas_entreno",
        "molestia_hombro", "molestia_rodilla",
    ]

    /// CSV completo. El BOM inicial hace que Excel detecte UTF-8 y no destroce
    /// los acentos.
    public static func generar(_ exportacion: ExportacionCompleta, conBOM: Bool = true) -> String {
        var lineas = [columnas.joined(separator: separador)]

        for entreno in exportacion.entrenos.sorted(by: { $0.fechaInicio < $1.fechaInicio }) {
            for ejercicio in entreno.ejercicios {
                for serie in ejercicio.series.sorted(by: { $0.orden < $1.orden }) {
                    lineas.append(fila(entreno: entreno, ejercicio: ejercicio, serie: serie))
                }
            }
        }

        let cuerpo = lineas.joined(separator: "\r\n") + "\r\n"
        return conBOM ? "\u{FEFF}" + cuerpo : cuerpo
    }

    private static func fila(
        entreno: EntrenoExportado,
        ejercicio: EjercicioEntrenoExportado,
        serie: SerieExportada
    ) -> String {
        let campos: [String] = [
            fechaISO(entreno.fechaInicio),
            hora(entreno.fechaInicio),
            entreno.nombre,
            entreno.rutinaOrigen ?? "",
            ejercicio.nombre,
            ejercicio.grupoPrincipal ?? "",
            ejercicio.tipoRegistro,
            "\(serie.orden + 1)",
            serie.calentamiento ? "sí" : "no",
            decimal(serie.peso),
            "\(serie.repeticiones)",
            serie.segundos.map(String.init) ?? "",
            serie.rir.map(String.init) ?? "",
            decimal(serie.peso * Double(serie.repeticiones)),
            ejercicio.notas,
            entreno.notas,
            entreno.molestiaHombro.map(String.init) ?? "",
            entreno.molestiaRodilla.map(String.init) ?? "",
        ]
        return campos.map(escapar).joined(separator: separador)
    }

    // MARK: - Formato

    /// Entre comillas si lleva separador, comillas o saltos de línea, y las
    /// comillas internas se duplican, como manda el RFC 4180.
    static func escapar(_ campo: String) -> String {
        let necesitaComillas = campo.contains(separador)
            || campo.contains("\"")
            || campo.contains("\n")
            || campo.contains("\r")
        guard necesitaComillas else { return campo }
        return "\"" + campo.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Coma decimal, sin separador de miles.
    static func decimal(_ valor: Double) -> String {
        if valor == valor.rounded() {
            return "\(Int(valor))"
        }
        return String(format: "%.2f", valor).replacingOccurrences(of: ".", with: ",")
    }

    static func fechaISO(_ fecha: Date) -> String {
        let formateador = DateFormatter()
        formateador.locale = Locale(identifier: "en_US_POSIX")
        formateador.dateFormat = "yyyy-MM-dd"
        formateador.timeZone = .current
        return formateador.string(from: fecha)
    }

    static func hora(_ fecha: Date) -> String {
        let formateador = DateFormatter()
        formateador.locale = Locale(identifier: "en_US_POSIX")
        formateador.dateFormat = "HH:mm"
        formateador.timeZone = .current
        return formateador.string(from: fecha)
    }
}
