import Foundation

/// Lo que un archivo pide borrar.
///
/// Es la única forma de quitar cosas desde fuera de la app. El puente con
/// iCloud era aditivo a propósito —una rutina que llega no toca nada de lo que
/// ya hay—, pero eso dejaba la limpieza entera en manos del usuario: con dos
/// carpetas de rutinas viejas y nombres casi iguales, el plan podía arrancar
/// la rutina equivocada y nadie de fuera podía arreglarlo.
///
/// Por eso **solo borra lo que se nombra, uno a uno**. No hay comodines, no
/// hay «todo lo anterior a tal fecha» y no se puede vaciar el historial: un
/// archivo con una errata tiene que poder quitar como mucho lo que dice.
public struct BorradoImportado: Equatable, Sendable {
    /// Carpetas a borrar, por nombre. Con ellas se van sus rutinas.
    public var carpetas: [String]
    /// Rutinas a borrar, por nombre, estén en la carpeta que estén.
    public var rutinas: [String]
    /// Entrenos finalizados que no tienen ninguna serie con algo anotado.
    ///
    /// Es el único borrado de historial que se admite, y solo porque no borra
    /// nada: un entreno sin series es una fila con su hora y su duración y
    /// nada detrás.
    public var entrenosVacios: Bool
    /// Ejercicios repetidos en la biblioteca, de los que **sobran**.
    ///
    /// Solo se van los que no tienen ni un entreno detrás: borrar uno con
    /// historial partiría sus gráficas y sus récords, y cuál de los dos
    /// sobrevive no es algo que deba decidir un archivo.
    public var ejerciciosDuplicados: Bool

    public init(
        carpetas: [String] = [],
        rutinas: [String] = [],
        entrenosVacios: Bool = false,
        ejerciciosDuplicados: Bool = false
    ) {
        self.carpetas = carpetas
        self.rutinas = rutinas
        self.entrenosVacios = entrenosVacios
        self.ejerciciosDuplicados = ejerciciosDuplicados
    }

    public var estaVacio: Bool {
        carpetas.isEmpty && rutinas.isEmpty && !entrenosVacios && !ejerciciosDuplicados
    }
}

/// Lee y valida el JSON de borrado.
///
/// El formato está documentado en docs/ESQUEMA-BORRADO-JSON.md.
public enum LectorBorradoJSON {

    public static let versionSoportada = 1

    /// Tope de nombres por archivo. Un archivo que pide borrar cincuenta
    /// carpetas no es una limpieza, es un error.
    public static let maxNombres = 40

    public static func leer(_ texto: String) throws -> BorradoImportado {
        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else {
            throw ErrorImportacion(ruta: "", mensaje: "El texto está vacío.")
        }
        guard let datos = limpio.data(using: .utf8) else {
            throw ErrorImportacion(ruta: "", mensaje: "El texto no se pudo leer como UTF-8.")
        }
        return try leer(datos)
    }

    public static func leer(_ datos: Data) throws -> BorradoImportado {
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
                mensaje: "Se esperaba un objeto JSON con las claves «version» y «borrar»."
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

        guard let borrarCrudo = raiz["borrar"] else {
            throw ErrorImportacion(ruta: "borrar", mensaje: "Falta el objeto «borrar».")
        }
        guard let borrar = borrarCrudo as? [String: Any] else {
            throw ErrorImportacion(
                ruta: "borrar",
                mensaje: "Tiene que ser un objeto con «carpetas», «rutinas», «entrenosVacios» o «ejerciciosDuplicados»."
            )
        }

        let carpetas = try nombres(borrar["carpetas"], ruta: "borrar.carpetas")
        let rutinas = try nombres(borrar["rutinas"], ruta: "borrar.rutinas")

        let entrenosVacios = try booleano(borrar["entrenosVacios"], ruta: "borrar.entrenosVacios")
        let duplicados = try booleano(borrar["ejerciciosDuplicados"], ruta: "borrar.ejerciciosDuplicados")

        let resultado = BorradoImportado(
            carpetas: carpetas,
            rutinas: rutinas,
            entrenosVacios: entrenosVacios,
            ejerciciosDuplicados: duplicados
        )

        // Un archivo de borrado que no nombra nada se rechaza en vez de
        // aceptarse como «no hagas nada»: casi siempre es una clave mal
        // escrita, y aceptarlo en silencio lo borraría de la bandeja sin que
        // nadie se enterase de que no hizo lo que se le pidió.
        guard !resultado.estaVacio else {
            throw ErrorImportacion(
                ruta: "borrar",
                mensaje: "No nombra nada que borrar. Usa «carpetas», «rutinas», «entrenosVacios» o «ejerciciosDuplicados»."
            )
        }

        return resultado
    }

    private static func booleano(_ crudo: Any?, ruta: String) throws -> Bool {
        guard let crudo else { return false }
        guard let valor = crudo as? Bool else {
            throw ErrorImportacion(ruta: ruta, mensaje: "Tiene que ser true o false.")
        }
        return valor
    }

    private static func nombres(_ crudo: Any?, ruta: String) throws -> [String] {
        guard let crudo else { return [] }
        guard let lista = crudo as? [Any] else {
            throw ErrorImportacion(ruta: ruta, mensaje: "Tiene que ser una lista de nombres.")
        }
        guard lista.count <= maxNombres else {
            throw ErrorImportacion(
                ruta: ruta,
                mensaje: "\(lista.count) nombres son demasiados. El tope es \(maxNombres)."
            )
        }
        var resultado: [String] = []
        for (indice, elemento) in lista.enumerated() {
            guard let texto = elemento as? String else {
                throw ErrorImportacion(ruta: "\(ruta)[\(indice)]", mensaje: "Tiene que ser texto.")
            }
            let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
            // Un nombre vacío casaría con cualquier cosa según cómo se
            // compare, y eso en un borrado no se puede permitir.
            guard !limpio.isEmpty else {
                throw ErrorImportacion(ruta: "\(ruta)[\(indice)]", mensaje: "El nombre está vacío.")
            }
            resultado.append(limpio)
        }
        return resultado
    }
}
