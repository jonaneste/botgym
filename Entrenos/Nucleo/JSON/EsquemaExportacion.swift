import Foundation

// MARK: - Modelo de exportación

/// El historial completo, listo para serializar.
///
/// Son tipos `Codable` aparte de los modelos de SwiftData a propósito: el
/// formato del archivo que te llevas no debe cambiar solo porque se refactorice
/// la base de datos.
public struct ExportacionCompleta: Codable, Equatable, Sendable {
    public var version: Int
    public var generado: Date
    public var app: String
    public var ejercicios: [EjercicioExportado]
    public var carpetas: [CarpetaExportada]
    public var entrenos: [EntrenoExportado]
    /// Carreras importadas de Apple Salud. Van en el mismo archivo para que un
    /// solo JSON contenga todo el entrenamiento, gimnasio y carrera.
    public var carreras: [CarreraExportada]
    /// Lo que la app sabe y quien lee el archivo no podía deducir: contra qué
    /// objetivo se cuentan las series de cada grupo, y con qué saltos de carga
    /// se progresa. Sin esto, un consejo como «sube a 22,5» es una suposición:
    /// depende de qué mancuernas hay en el gimnasio.
    public var ajustes: AjustesExportados?

    public init(
        version: Int = ExportacionCompleta.versionActual,
        generado: Date = Date(),
        app: String = "Entrenos",
        ejercicios: [EjercicioExportado],
        carpetas: [CarpetaExportada],
        entrenos: [EntrenoExportado],
        carreras: [CarreraExportada] = [],
        ajustes: AjustesExportados? = nil
    ) {
        self.version = version
        self.generado = generado
        self.app = app
        self.ejercicios = ejercicios
        self.carpetas = carpetas
        self.entrenos = entrenos
        self.carreras = carreras
        self.ajustes = ajustes
    }

    public static let versionActual = 1

    /// Las carreras se añadieron después, así que un archivo de la versión 1
    /// sin ellas sigue siendo válido.
    enum CodingKeys: String, CodingKey {
        case version, generado, app, ejercicios, carpetas, entrenos, carreras, ajustes
    }

    public init(from decodificador: Decoder) throws {
        let contenedor = try decodificador.container(keyedBy: CodingKeys.self)
        version = try contenedor.decode(Int.self, forKey: .version)
        generado = try contenedor.decode(Date.self, forKey: .generado)
        app = try contenedor.decode(String.self, forKey: .app)
        ejercicios = try contenedor.decode([EjercicioExportado].self, forKey: .ejercicios)
        carpetas = try contenedor.decode([CarpetaExportada].self, forKey: .carpetas)
        entrenos = try contenedor.decode([EntrenoExportado].self, forKey: .entrenos)
        carreras = try contenedor.decodeIfPresent([CarreraExportada].self, forKey: .carreras) ?? []
        ajustes = try contenedor.decodeIfPresent(AjustesExportados.self, forKey: .ajustes)
    }
}

/// Una carrera en el archivo de exportación.
/// Los ajustes que hacen falta para interpretar los datos y para aconsejar
/// con ellos.
///
/// No va todo lo de la pantalla de ajustes: las preferencias de vibración o
/// de notificación no le dicen nada a quien lee el archivo. Van las que
/// cambian la lectura —cuál es el objetivo semanal de cada grupo— y las que
/// condicionan un consejo: con qué saltos sube la carga en cada material y
/// qué mancuernas existen de verdad en el gimnasio.
public struct AjustesExportados: Codable, Equatable, Sendable {
    /// Series objetivo por semana, con el grupo muscular como clave.
    public var objetivosSemanales: [String: Int]
    public var incrementoBarra: Double
    public var incrementoPolea: Double
    public var incrementoMaquina: Double
    public var incrementoTiempo: Int
    /// Pesos de mancuerna disponibles, en kg y ordenados.
    public var mancuernasDisponibles: [Double]
    public var rirPorDefectoMin: Int
    public var rirPorDefectoMax: Int
    public var descansoPorDefectoSegundos: Int
    /// En kg. Cero significa que no se ha puesto, no que pese cero.
    public var pesoCorporal: Double?

    public init(
        objetivosSemanales: [String: Int],
        incrementoBarra: Double,
        incrementoPolea: Double,
        incrementoMaquina: Double,
        incrementoTiempo: Int,
        mancuernasDisponibles: [Double],
        rirPorDefectoMin: Int,
        rirPorDefectoMax: Int,
        descansoPorDefectoSegundos: Int,
        pesoCorporal: Double?
    ) {
        self.objetivosSemanales = objetivosSemanales
        self.incrementoBarra = incrementoBarra
        self.incrementoPolea = incrementoPolea
        self.incrementoMaquina = incrementoMaquina
        self.incrementoTiempo = incrementoTiempo
        self.mancuernasDisponibles = mancuernasDisponibles.sorted()
        self.rirPorDefectoMin = rirPorDefectoMin
        self.rirPorDefectoMax = rirPorDefectoMax
        self.descansoPorDefectoSegundos = descansoPorDefectoSegundos
        self.pesoCorporal = pesoCorporal
    }
}

public struct CarreraExportada: Codable, Equatable, Sendable {
    public var id: String
    public var fecha: Date
    public var duracionSegundos: Double
    public var distanciaKm: Double
    public var ritmoSegundosPorKm: Double?
    public var pulsoMedio: Double?
    public var calorias: Double?
    public var origen: String?

    public init(de carrera: Carrera) {
        self.id = carrera.id
        self.fecha = carrera.fechaInicio
        self.duracionSegundos = carrera.duracion
        self.distanciaKm = carrera.distanciaKm
        self.ritmoSegundosPorKm = carrera.ritmoSegundosPorKm
        self.pulsoMedio = carrera.pulsoMedio
        self.calorias = carrera.calorias
        self.origen = carrera.origen
    }
}

public struct EjercicioExportado: Codable, Equatable, Sendable {
    public var id: UUID
    public var nombre: String
    public var grupoPrincipal: String
    public var gruposSecundarios: [String]
    public var material: String
    public var tipoRegistro: String
    public var esPersonalizado: Bool
    public var notas: String

    public init(
        id: UUID, nombre: String, grupoPrincipal: String, gruposSecundarios: [String],
        material: String, tipoRegistro: String, esPersonalizado: Bool, notas: String
    ) {
        self.id = id
        self.nombre = nombre
        self.grupoPrincipal = grupoPrincipal
        self.gruposSecundarios = gruposSecundarios
        self.material = material
        self.tipoRegistro = tipoRegistro
        self.esPersonalizado = esPersonalizado
        self.notas = notas
    }
}

public struct CarpetaExportada: Codable, Equatable, Sendable {
    public var nombre: String
    public var rutinas: [RutinaExportada]

    public init(nombre: String, rutinas: [RutinaExportada]) {
        self.nombre = nombre
        self.rutinas = rutinas
    }
}

public struct RutinaExportada: Codable, Equatable, Sendable {
    public var nombre: String
    public var notas: String
    public var ejercicios: [ElementoExportado]

    public init(nombre: String, notas: String, ejercicios: [ElementoExportado]) {
        self.nombre = nombre
        self.notas = notas
        self.ejercicios = ejercicios
    }
}

public struct ElementoExportado: Codable, Equatable, Sendable {
    public var nombre: String
    public var series: Int
    /// Mismo formato que el importador: "8-10", "15", "30-45s".
    public var reps: String?
    public var rir: String?
    public var descanso: Int
    public var notas: String
    public var superserie: String?

    public init(
        nombre: String, series: Int, reps: String?, rir: String?,
        descanso: Int, notas: String, superserie: String?
    ) {
        self.nombre = nombre
        self.series = series
        self.reps = reps
        self.rir = rir
        self.descanso = descanso
        self.notas = notas
        self.superserie = superserie
    }
}

public struct EntrenoExportado: Codable, Equatable, Sendable {
    public var id: UUID
    public var nombre: String
    public var fechaInicio: Date
    public var fechaFin: Date?
    public var rutinaOrigen: String?
    public var notas: String
    public var molestiaHombro: Int?
    public var molestiaRodilla: Int?
    public var ejercicios: [EjercicioEntrenoExportado]

    public init(
        id: UUID, nombre: String, fechaInicio: Date, fechaFin: Date?, rutinaOrigen: String?,
        notas: String, molestiaHombro: Int?, molestiaRodilla: Int?,
        ejercicios: [EjercicioEntrenoExportado]
    ) {
        self.id = id
        self.nombre = nombre
        self.fechaInicio = fechaInicio
        self.fechaFin = fechaFin
        self.rutinaOrigen = rutinaOrigen
        self.notas = notas
        self.molestiaHombro = molestiaHombro
        self.molestiaRodilla = molestiaRodilla
        self.ejercicios = ejercicios
    }
}

public struct EjercicioEntrenoExportado: Codable, Equatable, Sendable {
    public var nombre: String
    public var grupoPrincipal: String?
    /// Se incluyen aquí, y no solo en la biblioteca, para que quien lea el
    /// archivo pueda contar series por grupo sin cruzar dos listas.
    public var gruposSecundarios: [String]
    public var tipoRegistro: String
    public var notas: String
    public var superserie: String?
    public var series: [SerieExportada]

    public init(
        nombre: String, grupoPrincipal: String?, gruposSecundarios: [String] = [],
        tipoRegistro: String, notas: String, superserie: String?, series: [SerieExportada]
    ) {
        self.nombre = nombre
        self.grupoPrincipal = grupoPrincipal
        self.gruposSecundarios = gruposSecundarios
        self.tipoRegistro = tipoRegistro
        self.notas = notas
        self.superserie = superserie
        self.series = series
    }

    enum CodingKeys: String, CodingKey {
        case nombre, grupoPrincipal, gruposSecundarios, tipoRegistro, notas, superserie, series
    }

    public init(from decodificador: Decoder) throws {
        let c = try decodificador.container(keyedBy: CodingKeys.self)
        nombre = try c.decode(String.self, forKey: .nombre)
        grupoPrincipal = try c.decodeIfPresent(String.self, forKey: .grupoPrincipal)
        gruposSecundarios = try c.decodeIfPresent([String].self, forKey: .gruposSecundarios) ?? []
        tipoRegistro = try c.decode(String.self, forKey: .tipoRegistro)
        notas = try c.decode(String.self, forKey: .notas)
        superserie = try c.decodeIfPresent(String.self, forKey: .superserie)
        series = try c.decode([SerieExportada].self, forKey: .series)
    }
}

public struct SerieExportada: Codable, Equatable, Sendable {
    public var orden: Int
    public var peso: Double
    public var repeticiones: Int
    public var segundos: Int?
    public var rir: Int?
    public var calentamiento: Bool

    public init(orden: Int, peso: Double, repeticiones: Int, segundos: Int?, rir: Int?, calentamiento: Bool) {
        self.orden = orden
        self.peso = peso
        self.repeticiones = repeticiones
        self.segundos = segundos
        self.rir = rir
        self.calentamiento = calentamiento
    }
}

// MARK: - Serialización

public enum SerializadorExportacion {

    /// JSON legible, con las fechas en ISO 8601 y las claves ordenadas, para
    /// que dos exportaciones del mismo historial den archivos idénticos.
    public static func json(_ exportacion: ExportacionCompleta) throws -> Data {
        let codificador = JSONEncoder()
        codificador.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        codificador.dateEncodingStrategy = .iso8601
        return try codificador.encode(exportacion)
    }

    public static func leerJSON(_ datos: Data) throws -> ExportacionCompleta {
        let decodificador = JSONDecoder()
        decodificador.dateDecodingStrategy = .iso8601
        return try decodificador.decode(ExportacionCompleta.self, from: datos)
    }

    /// Texto del rango en el formato que entiende el importador.
    public static func textoReps(min: Int?, max: Int?, esTiempo: Bool) -> String? {
        guard let min else { return nil }
        let sufijo = esTiempo ? "s" : ""
        if let max, max != min {
            return "\(min)-\(max)\(sufijo)"
        }
        return "\(min)\(sufijo)"
    }

    public static func textoRIR(min: Int?, max: Int?) -> String? {
        guard let min else { return nil }
        if let max, max != min { return "\(min)-\(max)" }
        return "\(min)"
    }
}
