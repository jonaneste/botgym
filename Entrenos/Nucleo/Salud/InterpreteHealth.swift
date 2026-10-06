import Foundation

/// Un `<Workout>` del archivo de exportación de Apple Health, ya troceado en
/// atributos y estadísticas.
///
/// El recorrido del XML se hace en la capa de la app, con un parser en
/// streaming: el export de Salud puede pesar cientos de megas. Aquí solo vive
/// la interpretación, que es lo que tiene reglas y merece tests.
public struct RegistroEntrenoHealth: Equatable, Sendable {
    public var atributos: [String: String]
    /// Los `<WorkoutStatistics>` hijos, cada uno con sus atributos.
    public var estadisticas: [[String: String]]

    public init(atributos: [String: String], estadisticas: [[String: String]] = []) {
        self.atributos = atributos
        self.estadisticas = estadisticas
    }
}

/// Convierte registros del export de Salud en carreras.
public enum InterpreteHealth {

    public static let tipoCarrera = "HKWorkoutActivityTypeRunning"

    /// Formatos de fecha que usa el export de Salud. El primero es el habitual.
    static let formatosFecha = [
        "yyyy-MM-dd HH:mm:ss Z",
        "yyyy-MM-dd HH:mm:ss ZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ssZ",
    ]

    /// `true` si este registro es una carrera.
    public static func esCarrera(_ registro: RegistroEntrenoHealth) -> Bool {
        registro.atributos["workoutActivityType"] == tipoCarrera
    }

    /// Interpreta un registro como carrera. Devuelve `nil` si no es una
    /// carrera o si le faltan los datos mínimos (fecha y duración).
    public static func carrera(de registro: RegistroEntrenoHealth) -> Carrera? {
        guard esCarrera(registro) else { return nil }
        let atributos = registro.atributos

        guard let textoInicio = atributos["startDate"],
              let inicio = fecha(de: textoInicio) else { return nil }

        guard let duracion = duracionSegundos(
            valor: atributos["duration"],
            unidad: atributos["durationUnit"]
        ) else { return nil }

        let distancia = distanciaMetros(registro: registro, atributos: atributos)
        let pulso = estadistica(registro, tipo: "HKQuantityTypeIdentifierHeartRate", clave: "average")
        let calorias = estadistica(registro, tipo: "HKQuantityTypeIdentifierActiveEnergyBurned", clave: "sum")

        // El export no trae UUID, así que se compone uno estable a partir de la
        // fecha: releer el mismo archivo no duplica la carrera.
        let identificador = atributos["uuid"] ?? "\(FusionCarreras.prefijoExport)\(textoInicio)"

        return Carrera(
            id: identificador,
            fechaInicio: inicio,
            duracion: duracion,
            distanciaMetros: distancia,
            pulsoMedio: pulso,
            calorias: calorias,
            origen: atributos["sourceName"]
        )
    }

    // MARK: - Piezas

    /// Formateadores creados una vez y no por elemento del XML.
    ///
    /// Construir un `DateFormatter` no es gratis y aquí se llamaba hasta tres
    /// veces por cada `<Workout>` de un archivo que puede tener miles.
    ///
    /// Compartirlos es seguro: `DateFormatter` admite `date(from:)` desde
    /// varios hilos, y aquí nadie los reconfigura después de crearlos.
    private static let formateadores: [DateFormatter] = formatosFecha.map { formato in
        let formateador = DateFormatter()
        formateador.locale = Locale(identifier: "en_US_POSIX")
        formateador.dateFormat = formato
        return formateador
    }

    private static let formateadorISO = ISO8601DateFormatter()

    static func fecha(de texto: String) -> Date? {
        for formateador in formateadores {
            if let fecha = formateador.date(from: texto) { return fecha }
        }
        return formateadorISO.date(from: texto)
    }

    /// Duración en segundos. El export la da casi siempre en minutos.
    static func duracionSegundos(valor: String?, unidad: String?) -> TimeInterval? {
        guard let valor, let numero = Double(valor), numero >= 0 else { return nil }
        switch (unidad ?? "min").lowercased() {
        case "s", "sec", "second", "seconds": return numero
        case "h", "hr", "hour", "hours": return numero * 3600
        default: return numero * 60   // min
        }
    }

    /// Distancia en metros, mirando primero las estadísticas y luego los
    /// atributos antiguos `totalDistance`.
    static func distanciaMetros(registro: RegistroEntrenoHealth, atributos: [String: String]) -> Double {
        for estadistica in registro.estadisticas {
            guard estadistica["type"] == "HKQuantityTypeIdentifierDistanceWalkingRunning" else { continue }
            if let suma = estadistica["sum"], let numero = Double(suma) {
                return enMetros(numero, unidad: estadistica["unit"])
            }
        }
        if let total = atributos["totalDistance"], let numero = Double(total) {
            return enMetros(numero, unidad: atributos["totalDistanceUnit"])
        }
        return 0
    }

    static func enMetros(_ valor: Double, unidad: String?) -> Double {
        switch (unidad ?? "km").lowercased() {
        case "m", "metros", "meter", "meters": return valor
        case "mi", "mile", "miles": return valor * 1609.344
        case "yd", "yard", "yards": return valor * 0.9144
        default: return valor * 1000   // km
        }
    }

    static func estadistica(_ registro: RegistroEntrenoHealth, tipo: String, clave: String) -> Double? {
        for estadistica in registro.estadisticas where estadistica["type"] == tipo {
            if let valor = estadistica[clave], let numero = Double(valor) {
                return numero
            }
        }
        return nil
    }
}
