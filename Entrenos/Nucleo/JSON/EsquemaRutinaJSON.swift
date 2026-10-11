import Foundation

// MARK: - Resultado

/// Rutinas leídas de un JSON, ya validadas.
public struct RutinasImportadas: Equatable, Sendable {
    public var carpeta: String?
    public var rutinas: [RutinaImportada]

    public init(carpeta: String?, rutinas: [RutinaImportada]) {
        self.carpeta = carpeta
        self.rutinas = rutinas
    }

    /// Nombres de ejercicio distintos que aparecen, en orden de aparición.
    public var nombresDeEjercicio: [String] {
        var vistos: Set<String> = []
        var resultado: [String] = []
        for rutina in rutinas {
            for ejercicio in rutina.ejercicios {
                let clave = ejercicio.nombre.lowercased()
                if !vistos.contains(clave) {
                    vistos.insert(clave)
                    resultado.append(ejercicio.nombre)
                }
            }
        }
        return resultado
    }
}

public struct RutinaImportada: Equatable, Sendable {
    public var nombre: String
    public var notas: String
    public var ejercicios: [EjercicioImportado]

    public init(nombre: String, notas: String = "", ejercicios: [EjercicioImportado]) {
        self.nombre = nombre
        self.notas = notas
        self.ejercicios = ejercicios
    }
}

public struct EjercicioImportado: Equatable, Sendable {
    public var nombre: String
    public var series: Int
    /// Repeticiones o segundos, según `esTiempo`. `nil` = series libres.
    public var objetivoMin: Int?
    public var objetivoMax: Int?
    /// `true` si el rango venía con la `s` de segundos: "30-45s".
    public var esTiempo: Bool
    public var rirMin: Int?
    public var rirMax: Int?
    public var descansoSegundos: Int
    public var notas: String
    /// Etiqueta de agrupación. Los consecutivos con la misma forman superserie.
    public var etiquetaSuperserie: String?

    public init(
        nombre: String,
        series: Int,
        objetivoMin: Int? = nil,
        objetivoMax: Int? = nil,
        esTiempo: Bool = false,
        rirMin: Int? = nil,
        rirMax: Int? = nil,
        descansoSegundos: Int = 90,
        notas: String = "",
        etiquetaSuperserie: String? = nil
    ) {
        self.nombre = nombre
        self.series = series
        self.objetivoMin = objetivoMin
        self.objetivoMax = objetivoMax
        self.esTiempo = esTiempo
        self.rirMin = rirMin
        self.rirMax = rirMax
        self.descansoSegundos = descansoSegundos
        self.notas = notas
        self.etiquetaSuperserie = etiquetaSuperserie
    }
}

// MARK: - Errores

/// Error de importación con la ruta exacta del problema.
public struct ErrorImportacion: Error, Equatable, CustomStringConvertible {
    /// Dónde está el problema: `rutinas[0].ejercicios[2].reps`.
    public var ruta: String
    public var mensaje: String

    public init(ruta: String, mensaje: String) {
        self.ruta = ruta
        self.mensaje = mensaje
    }

    public var description: String {
        ruta.isEmpty ? mensaje : "\(ruta): \(mensaje)"
    }
}

// MARK: - Lector

/// Lee y valida el JSON de importación de rutinas.
///
/// Se parsea a mano desde `JSONSerialization` en lugar de con `Codable` a
/// propósito: `Codable` da errores como "keyNotFound(ejercicios)" sin decir en
/// qué rutina, y el usuario pidió errores claros. Aquí cada mensaje lleva su
/// ruta y dice qué se esperaba.
///
/// El formato está documentado en docs/ESQUEMA-RUTINA-JSON.md.
public enum LectorRutinasJSON {

    public static let versionSoportada = 1

    /// Límites de cordura, para que un JSON disparatado dé un error legible
    /// en lugar de crear 900 series.
    public static let maxSeries = 20
    public static let maxDescanso = 1800
    public static let maxObjetivo = 1000

    public static func leer(_ texto: String) throws -> RutinasImportadas {
        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else {
            throw ErrorImportacion(ruta: "", mensaje: "El texto está vacío.")
        }
        guard let datos = limpio.data(using: .utf8) else {
            throw ErrorImportacion(ruta: "", mensaje: "El texto no se pudo leer como UTF-8.")
        }
        return try leer(datos)
    }

    public static func leer(_ datos: Data) throws -> RutinasImportadas {
        let crudo: Any
        do {
            crudo = try JSONSerialization.jsonObject(with: datos, options: [])
        } catch {
            throw ErrorImportacion(
                ruta: "",
                mensaje: "No es un JSON válido. Revisa que no falte una coma o una llave. (\(error.localizedDescription))"
            )
        }

        guard let raiz = crudo as? [String: Any] else {
            throw ErrorImportacion(
                ruta: "",
                mensaje: "Se esperaba un objeto JSON con las claves «version» y «rutinas»."
            )
        }

        try validarVersion(raiz)

        let carpeta = (raiz["carpeta"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let rutinasCrudas = raiz["rutinas"] else {
            throw ErrorImportacion(ruta: "rutinas", mensaje: "Falta la lista de rutinas.")
        }
        guard let listaRutinas = rutinasCrudas as? [Any] else {
            throw ErrorImportacion(ruta: "rutinas", mensaje: "Tiene que ser una lista.")
        }
        guard !listaRutinas.isEmpty else {
            throw ErrorImportacion(ruta: "rutinas", mensaje: "La lista está vacía: hace falta al menos una rutina.")
        }

        let rutinas = try listaRutinas.enumerated().map { indice, elemento in
            try leerRutina(elemento, ruta: "rutinas[\(indice)]")
        }

        return RutinasImportadas(
            carpeta: (carpeta?.isEmpty ?? true) ? nil : carpeta,
            rutinas: rutinas
        )
    }

    // MARK: - Piezas

    private static func validarVersion(_ raiz: [String: Any]) throws {
        guard let version = raiz["version"] else {
            throw ErrorImportacion(
                ruta: "version",
                mensaje: "Falta. Pon \"version\": \(versionSoportada)."
            )
        }
        guard let numero = enteroDe(version) else {
            throw ErrorImportacion(ruta: "version", mensaje: "Tiene que ser un número entero.")
        }
        guard numero == versionSoportada else {
            throw ErrorImportacion(
                ruta: "version",
                mensaje: "Versión \(numero) no soportada. Esta app lee la versión \(versionSoportada)."
            )
        }
    }

    private static func leerRutina(_ crudo: Any, ruta: String) throws -> RutinaImportada {
        guard let objeto = crudo as? [String: Any] else {
            throw ErrorImportacion(ruta: ruta, mensaje: "Se esperaba un objeto con «nombre» y «ejercicios».")
        }

        guard let nombreCrudo = objeto["nombre"] as? String else {
            throw ErrorImportacion(ruta: "\(ruta).nombre", mensaje: "Falta el nombre de la rutina.")
        }
        let nombre = nombreCrudo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nombre.isEmpty else {
            throw ErrorImportacion(ruta: "\(ruta).nombre", mensaje: "El nombre está vacío.")
        }

        let notas = (objeto["notas"] as? String) ?? ""

        guard let ejerciciosCrudos = objeto["ejercicios"] else {
            throw ErrorImportacion(ruta: "\(ruta).ejercicios", mensaje: "Falta la lista de ejercicios.")
        }
        guard let lista = ejerciciosCrudos as? [Any] else {
            throw ErrorImportacion(ruta: "\(ruta).ejercicios", mensaje: "Tiene que ser una lista.")
        }
        guard !lista.isEmpty else {
            throw ErrorImportacion(
                ruta: "\(ruta).ejercicios",
                mensaje: "La rutina «\(nombre)» no tiene ejercicios."
            )
        }

        let ejercicios = try lista.enumerated().map { indice, elemento in
            try leerEjercicio(elemento, ruta: "\(ruta).ejercicios[\(indice)]")
        }

        return RutinaImportada(nombre: nombre, notas: notas, ejercicios: ejercicios)
    }

    private static func leerEjercicio(_ crudo: Any, ruta: String) throws -> EjercicioImportado {
        guard let objeto = crudo as? [String: Any] else {
            throw ErrorImportacion(ruta: ruta, mensaje: "Se esperaba un objeto con «nombre» y «series».")
        }

        guard let nombreCrudo = objeto["nombre"] as? String else {
            throw ErrorImportacion(ruta: "\(ruta).nombre", mensaje: "Falta el nombre del ejercicio.")
        }
        let nombre = nombreCrudo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nombre.isEmpty else {
            throw ErrorImportacion(ruta: "\(ruta).nombre", mensaje: "El nombre está vacío.")
        }

        guard let seriesCrudas = objeto["series"] else {
            throw ErrorImportacion(ruta: "\(ruta).series", mensaje: "Falta el número de series.")
        }
        guard let series = enteroDe(seriesCrudas) else {
            throw ErrorImportacion(ruta: "\(ruta).series", mensaje: "Tiene que ser un número entero.")
        }
        guard series >= 1, series <= maxSeries else {
            throw ErrorImportacion(
                ruta: "\(ruta).series",
                mensaje: "\(series) está fuera de rango. Tiene que estar entre 1 y \(maxSeries)."
            )
        }

        // Rango de repeticiones o segundos.
        var objetivoMin: Int?
        var objetivoMax: Int?
        var esTiempo = false
        if let repsCrudas = objeto["reps"] {
            guard let texto = repsCrudas as? String else {
                throw ErrorImportacion(
                    ruta: "\(ruta).reps",
                    mensaje: "Tiene que ser texto entre comillas, como \"8-10\" o \"30-45s\"."
                )
            }
            let rango = try parsearRango(texto, ruta: "\(ruta).reps")
            objetivoMin = rango.minimo
            objetivoMax = rango.maximo
            esTiempo = rango.esTiempo
        }

        // RIR objetivo.
        var rirMin: Int?
        var rirMax: Int?
        if let rirCrudo = objeto["rir"] {
            let texto: String
            if let comoTexto = rirCrudo as? String {
                texto = comoTexto
            } else if let comoNumero = enteroDe(rirCrudo) {
                texto = "\(comoNumero)"
            } else {
                throw ErrorImportacion(
                    ruta: "\(ruta).rir",
                    mensaje: "Tiene que ser texto como \"2\" o \"2-3\"."
                )
            }
            let rango = try parsearRango(texto, ruta: "\(ruta).rir", permitirSegundos: false, maximoPermitido: 10)
            rirMin = rango.minimo
            rirMax = rango.maximo
        }

        // Descanso.
        var descanso = 90
        if let descansoCrudo = objeto["descanso"] {
            guard let valor = enteroDe(descansoCrudo) else {
                throw ErrorImportacion(ruta: "\(ruta).descanso", mensaje: "Tiene que ser un número de segundos.")
            }
            guard valor >= 0, valor <= maxDescanso else {
                throw ErrorImportacion(
                    ruta: "\(ruta).descanso",
                    mensaje: "\(valor) s está fuera de rango. Tiene que estar entre 0 y \(maxDescanso)."
                )
            }
            descanso = valor
        }

        let notas = (objeto["notas"] as? String) ?? ""

        var superserie: String?
        if let superserieCruda = objeto["superserie"] {
            guard let texto = superserieCruda as? String else {
                throw ErrorImportacion(
                    ruta: "\(ruta).superserie",
                    mensaje: "Tiene que ser texto: una etiqueta como \"A\"."
                )
            }
            let limpia = texto.trimmingCharacters(in: .whitespacesAndNewlines)
            superserie = limpia.isEmpty ? nil : limpia
        }

        return EjercicioImportado(
            nombre: nombre,
            series: series,
            objetivoMin: objetivoMin,
            objetivoMax: objetivoMax,
            esTiempo: esTiempo,
            rirMin: rirMin,
            rirMax: rirMax,
            descansoSegundos: descanso,
            notas: notas,
            etiquetaSuperserie: superserie
        )
    }

    // MARK: - Rangos

    struct RangoLeido: Equatable {
        var minimo: Int
        var maximo: Int
        var esTiempo: Bool
    }

    /// Lee "8-10", "15", "30-45s" o "45s".
    static func parsearRango(
        _ texto: String,
        ruta: String,
        permitirSegundos: Bool = true,
        maximoPermitido: Int = LectorRutinasJSON.maxObjetivo
    ) throws -> RangoLeido {
        var limpio = texto
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        guard !limpio.isEmpty else {
            throw ErrorImportacion(ruta: ruta, mensaje: "Está vacío. Usa \"8-10\", \"15\" o \"30-45s\".")
        }

        var esTiempo = false
        if limpio.hasSuffix("s") {
            guard permitirSegundos else {
                throw ErrorImportacion(ruta: ruta, mensaje: "Aquí no se admiten segundos: usa \"2\" o \"2-3\".")
            }
            esTiempo = true
            limpio = String(limpio.dropLast())
        }

        // Se acepta el guion normal y los que meten los editores de texto.
        for separador in ["\u{2013}", "\u{2014}", "a"] {
            limpio = limpio.replacingOccurrences(of: separador, with: "-")
        }

        let trozos = limpio.split(separator: "-", omittingEmptySubsequences: false).map(String.init)

        func numero(_ cadena: String) throws -> Int {
            guard let valor = Int(cadena), valor >= 0, valor <= maximoPermitido else {
                throw ErrorImportacion(
                    ruta: ruta,
                    mensaje: "«\(texto)» no es un rango válido. Usa \"8-10\", \"15\" o \"30-45s\", con números entre 0 y \(maximoPermitido)."
                )
            }
            return valor
        }

        switch trozos.count {
        case 1:
            let valor = try numero(trozos[0])
            return RangoLeido(minimo: valor, maximo: valor, esTiempo: esTiempo)
        case 2:
            let minimo = try numero(trozos[0])
            let maximo = try numero(trozos[1])
            guard minimo <= maximo else {
                throw ErrorImportacion(
                    ruta: ruta,
                    mensaje: "«\(texto)» tiene el mínimo por encima del máximo."
                )
            }
            return RangoLeido(minimo: minimo, maximo: maximo, esTiempo: esTiempo)
        default:
            throw ErrorImportacion(
                ruta: ruta,
                mensaje: "«\(texto)» no es un rango válido. Usa \"8-10\", \"15\" o \"30-45s\"."
            )
        }
    }

    /// JSON no distingue entre 3 y 3.0, así que un entero puede llegar como
    /// `Double`. Un decimal de verdad se rechaza.
    ///
    /// El `Double` pasa por `LimitesEntrada`: `Int(unDouble)` atrapa y cierra
    /// la app cuando el valor no cabe en `Int64` o es infinito, y esto lee un
    /// archivo que escribe cualquiera. Recortado, el valor absurdo lo rechaza
    /// después la comprobación de rango, con un mensaje que se puede leer.
    static func enteroDe(_ valor: Any) -> Int? {
        if let entero = valor as? Int { return entero }
        if let numero = valor as? Double, numero == numero.rounded() {
            return LimitesEntrada.entero(numero)
        }
        if let texto = valor as? String { return Int(texto.trimmingCharacters(in: .whitespaces)) }
        return nil
    }
}
