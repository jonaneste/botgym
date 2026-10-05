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

    public init(
        version: Int = ExportacionCompleta.versionActual,
        generado: Date = Date(),
        app: String = "Entrenos",
        ejercicios: [EjercicioExportado],
        carpetas: [CarpetaExportada],
        entrenos: [EntrenoExportado]
    ) {
        self.version = version
        self.generado = generado
        self.app = app
        self.ejercicios = ejercicios
        self.carpetas = carpetas
        self.entrenos = entrenos
    }

    public static let versionActual = 1
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
    public var tipoRegistro: String
    public var notas: String
    public var superserie: String?
    public var series: [SerieExportada]

    public init(
        nombre: String, grupoPrincipal: String?, tipoRegistro: String,
        notas: String, superserie: String?, series: [SerieExportada]
    ) {
        self.nombre = nombre
        self.grupoPrincipal = grupoPrincipal
        self.tipoRegistro = tipoRegistro
        self.notas = notas
        self.superserie = superserie
        self.series = series
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
