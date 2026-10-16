import Foundation

/// Un ejercicio que llega para la biblioteca, sin rutina de por medio.
public struct EjercicioSuelto: Equatable, Sendable {
    public var nombre: String
    /// Obligatorio, al contrario que en las rutinas: aquí no hay ningún
    /// ejercicio existente al que agarrarse, así que sin grupo el ejercicio
    /// nacería sin clasificar y no contaría en ningún recuento semanal.
    public var grupoPrincipal: String
    public var gruposSecundarios: [String]
    public var material: String?
    public var tipoRegistro: String?
    public var notas: String

    public init(
        nombre: String,
        grupoPrincipal: String,
        gruposSecundarios: [String] = [],
        material: String? = nil,
        tipoRegistro: String? = nil,
        notas: String = ""
    ) {
        self.nombre = nombre
        self.grupoPrincipal = grupoPrincipal
        self.gruposSecundarios = gruposSecundarios
        self.material = material
        self.tipoRegistro = tipoRegistro
        self.notas = notas
    }
}

/// Lee un JSON que solo trae ejercicios para la biblioteca.
///
/// El cuarto formato de la carpeta compartida, y el más simple: ampliar el
/// catálogo no debería obligar a inventarse una rutina que no se va a hacer,
/// que era la única forma que había de meter un ejercicio desde fuera.
///
/// El formato está documentado en docs/ESQUEMA-EJERCICIOS-JSON.md.
public enum LectorEjerciciosJSON {

    public static let versionSoportada = 1

    /// Tope por archivo. Un catálogo entero de golpe se lee de una vez, pero
    /// mil ejercicios no es un catálogo, es un error.
    public static let maxEjercicios = 300

    public static func leer(_ texto: String) throws -> [EjercicioSuelto] {
        guard let datos = texto.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) else {
            throw ErrorImportacion(ruta: "", mensaje: "El texto no se pudo leer como UTF-8.")
        }
        return try leer(datos)
    }

    public static func leer(_ datos: Data) throws -> [EjercicioSuelto] {
        let crudo: Any
        do {
            crudo = try JSONSerialization.jsonObject(with: datos, options: [])
        } catch {
            throw ErrorImportacion(
                ruta: "",
                mensaje: "No es un JSON válido. (\(error.localizedDescription))"
            )
        }
        guard let raiz = crudo as? [String: Any] else {
            throw ErrorImportacion(
                ruta: "",
                mensaje: "Se esperaba un objeto JSON con las claves «version» y «ejercicios»."
            )
        }

        guard let version = raiz["version"] else {
            throw ErrorImportacion(ruta: "version", mensaje: "Falta. Pon \"version\": \(versionSoportada).")
        }
        guard let numero = LectorRutinasJSON.enteroDe(version) else {
            throw ErrorImportacion(ruta: "version", mensaje: "Tiene que ser un número entero.")
        }
        guard numero == versionSoportada else {
            throw ErrorImportacion(
                ruta: "version",
                mensaje: "Versión \(numero) no soportada. Esta app lee la versión \(versionSoportada)."
            )
        }

        guard let lista = raiz["ejercicios"] as? [Any] else {
            throw ErrorImportacion(
                ruta: "ejercicios",
                mensaje: "Falta la lista de ejercicios, o no es una lista."
            )
        }
        guard !lista.isEmpty else {
            throw ErrorImportacion(ruta: "ejercicios", mensaje: "La lista está vacía.")
        }
        guard lista.count <= maxEjercicios else {
            throw ErrorImportacion(
                ruta: "ejercicios",
                mensaje: "\(lista.count) ejercicios son demasiados. El tope es \(maxEjercicios)."
            )
        }

        return try lista.enumerated().map { indice, elemento in
            try leerUno(elemento, ruta: "ejercicios[\(indice)]")
        }
    }

    private static func leerUno(_ crudo: Any, ruta: String) throws -> EjercicioSuelto {
        guard let objeto = crudo as? [String: Any] else {
            throw ErrorImportacion(ruta: ruta, mensaje: "Se esperaba un objeto con «nombre» y «grupo».")
        }

        let nombre = ((objeto["nombre"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nombre.isEmpty else {
            throw ErrorImportacion(ruta: "\(ruta).nombre", mensaje: "Falta el nombre.")
        }

        let grupo = ((objeto["grupo"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Aquí el grupo sí es obligatorio: un ejercicio de catálogo sin grupo
        // no suma en ningún recuento, así que entrar sin él es entrar roto.
        guard !grupo.isEmpty else {
            throw ErrorImportacion(
                ruta: "\(ruta).grupo",
                mensaje: "Falta el grupo muscular, y aquí es obligatorio: sin él el ejercicio no contaría en las series semanales."
            )
        }

        let secundarios = ((objeto["gruposSecundarios"] as? [Any]) ?? [])
            .compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let material = (objeto["material"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let tipo = (objeto["tipo"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notas = ((objeto["notas"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        return EjercicioSuelto(
            nombre: nombre,
            grupoPrincipal: grupo,
            gruposSecundarios: secundarios,
            material: (material?.isEmpty ?? true) ? nil : material,
            tipoRegistro: (tipo?.isEmpty ?? true) ? nil : tipo,
            notas: notas
        )
    }
}
