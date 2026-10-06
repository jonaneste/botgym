import Foundation

/// Lee las carreras del archivo de exportación de Apple Health.
///
/// Es el camino para quien no tenga el Apple Developer Program: HealthKit
/// necesita una capability que Apple no concede a cuentas gratuitas, pero el
/// archivo que exporta la app de Salud se puede leer sin permiso alguno.
///
/// En Salud: foto de perfil → Exportar todos los datos de salud. Sale un
/// `exportar.zip` con `exportar.xml` dentro. Hay que descomprimirlo e importar
/// el XML.
///
/// El parser va en streaming de verdad: `XMLParser(stream:)` sobre un
/// `InputStream` del archivo, y no `XMLParser(contentsOf:)`, que pese a ser SAX
/// empieza por leerse el archivo entero en memoria. Con un export de un giga
/// eso era un cierre por consumo de memoria antes de interpretar nada.
///
/// Y se lee fuera del hilo principal, con `leerFueraDelPrincipal(urlArchivo:)`:
/// recorrer ese archivo son decenas de segundos, y hacerlo en el hilo principal
/// congelaba la interfaz hasta el punto de que el indicador de "Procesando…" no
/// llegaba ni a pintarse antes de que el sistema matase la app por no responder.
final class LectorExportHealth: NSObject {

    /// Carreras encontradas, de más reciente a más antigua.
    private(set) var carreras: [Carrera] = []

    private var registroActual: RegistroEntrenoHealth?
    private var entrenosVistos = 0

    /// Lee el XML y devuelve las carreras.
    ///
    /// Bloquea el hilo desde el que se llame durante todo el recorrido. Desde
    /// la interfaz hay que usar `leerFueraDelPrincipal(urlArchivo:)`.
    func leer(urlArchivo: URL) throws -> [Carrera] {
        guard let flujo = InputStream(url: urlArchivo) else {
            throw ErrorImportacionSalud.noSePudoAbrir
        }
        return try ejecutar(XMLParser(stream: flujo))
    }

    /// Lee el XML en una tarea aparte y devuelve las carreras al terminar.
    ///
    /// El permiso de lectura del archivo lo tiene que haber pedido quien llama,
    /// con `startAccessingSecurityScopedResource()`, y mantenerlo abierto hasta
    /// que esto vuelva: el ámbito de seguridad es del proceso y no del hilo, así
    /// que vale igual desde aquí.
    static func leerFueraDelPrincipal(urlArchivo: URL) async throws -> [Carrera] {
        try await Task.detached(priority: .userInitiated) {
            try LectorExportHealth().leer(urlArchivo: urlArchivo)
        }.value
    }

    func leer(datos: Data) throws -> [Carrera] {
        try ejecutar(XMLParser(data: datos))
    }

    private func ejecutar(_ parser: XMLParser) throws -> [Carrera] {
        carreras = []
        registroActual = nil
        entrenosVistos = 0

        parser.delegate = self
        parser.shouldProcessNamespaces = false

        guard parser.parse() else {
            if let error = parser.parserError {
                throw ErrorImportacionSalud.xmlInvalido(error.localizedDescription)
            }
            throw ErrorImportacionSalud.xmlInvalido("formato no reconocido")
        }

        guard entrenosVistos > 0 else {
            throw ErrorImportacionSalud.sinEntrenos
        }

        carreras.sort { $0.fechaInicio > $1.fechaInicio }
        return carreras
    }
}

extension LectorExportHealth: XMLParserDelegate {

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "Workout":
            entrenosVistos += 1
            registroActual = RegistroEntrenoHealth(atributos: attributeDict)
        case "WorkoutStatistics":
            registroActual?.estadisticas.append(attributeDict)
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard elementName == "Workout", let registro = registroActual else { return }
        registroActual = nil
        // La interpretación vive en el núcleo, donde hay tests.
        if let carrera = InterpreteHealth.carrera(de: registro) {
            carreras.append(carrera)
        }
    }
}

enum ErrorImportacionSalud: LocalizedError {
    case noSePudoAbrir
    case xmlInvalido(String)
    case sinEntrenos

    var errorDescription: String? {
        switch self {
        case .noSePudoAbrir:
            return "No se pudo abrir el archivo."
        case .xmlInvalido(let detalle):
            return "El archivo no es un XML válido de Salud (\(detalle))."
        case .sinEntrenos:
            return "El archivo no contiene ningún entrenamiento. ¿Seguro que es el exportar.xml de Salud y no otro archivo del zip?"
        }
    }
}
