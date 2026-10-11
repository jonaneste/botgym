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
    ///
    /// El archivo lo escribe otra app y lo elige el usuario, así que aquí
    /// entra cualquier cosa: `Double("1e400")` y `Double("inf")` se
    /// interpretan sin queja y `numero >= 0` es **cierto** para el infinito.
    /// Un infinito no se queda en un dato raro: el historial lo formatea, la
    /// conversión a `Int` de ahí atrapa y la app se cierra al abrir la
    /// pestaña, una y otra vez.
    static func duracionSegundos(valor: String?, unidad: String?) -> TimeInterval? {
        guard let valor, let numero = Double(valor), numero.isFinite, numero >= 0 else { return nil }
        let segundos: TimeInterval
        switch (unidad ?? "min").lowercased() {
        case "s", "sec", "second", "seconds": segundos = numero
        case "h", "hr", "hour", "hours": segundos = numero * 3600
        default: segundos = numero * 60   // min
        }
        // Y se vuelve a comprobar: el producto desborda a infinito aunque el
        // número de partida fuese finito.
        guard segundos.isFinite else { return nil }
        return segundos
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
        let metros: Double
        switch (unidad ?? "km").lowercased() {
        case "m", "metros", "meter", "meters": metros = valor
        case "mi", "mile", "miles": metros = valor * 1609.344
        case "yd", "yard", "yards": metros = valor * 0.9144
        default: metros = valor * 1000   // km
        }
        // Una distancia que no es finita, o negativa, se trata como «no hay
        // distancia», que es lo que ya significa el cero. Dejarla pasar daba
        // un ritmo infinito, y una distancia diminuta —un milímetro— también.
        guard metros.isFinite, metros >= 0 else { return 0 }
        return metros
    }

    /// Una estadística del registro, como el pulso medio o las calorías.
    ///
    /// Se descarta lo que no sea finito por lo mismo que la duración: el pulso
    /// se pinta con una conversión a `Int`, y las calorías viajan al JSON de
    /// exportación, que `JSONEncoder` rechaza si no son finitas.
    static func estadistica(_ registro: RegistroEntrenoHealth, tipo: String, clave: String) -> Double? {
        for estadistica in registro.estadisticas where estadistica["type"] == tipo {
            if let valor = estadistica[clave], let numero = Double(valor), numero.isFinite {
                return numero
            }
        }
        return nil
    }
}
