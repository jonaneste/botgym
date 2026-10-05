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
/// El parser va en streaming (`XMLParser` es SAX) porque ese XML puede pesar
/// cientos de megas: cargarlo en memoria de golpe tumbaría la app.
final class LectorExportHealth: NSObject {

    /// Carreras encontradas, de más reciente a más antigua.
    private(set) var carreras: [Carrera] = []

    private var registroActual: RegistroEntrenoHealth?
    private var entrenosVistos = 0

    /// Lee el XML y devuelve las carreras.
    func leer(urlArchivo: URL) throws -> [Carrera] {
        guard let parser = XMLParser(contentsOf: urlArchivo) else {
            throw ErrorImportacionSalud.noSePudoAbrir
        }
        return try ejecutar(parser)
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
