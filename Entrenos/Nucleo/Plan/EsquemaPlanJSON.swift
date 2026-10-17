import Foundation

/// Un plan leído de un JSON, ya validado.
public struct PlanImportado: Equatable, Sendable {
    /// Nombre del plan: «Media maratón Vitoria-Gasteiz».
    public var nombre: String
    /// Día de la competición, si el plan tiene uno.
    public var objetivo: Date?
    public var dias: [DiaPlanValor]

    public init(nombre: String, objetivo: Date? = nil, dias: [DiaPlanValor]) {
        self.nombre = nombre
        self.objetivo = objetivo
        self.dias = dias
    }
}

/// Lee y valida el JSON de un plan de entrenamiento.
///
/// Es el hermano de `LectorRutinasJSON` y sigue sus mismas reglas: se parsea a
/// mano para poder decir en qué día está el problema, y cada error lleva su
/// ruta. El formato está documentado en docs/ESQUEMA-PLAN-JSON.md.
///
/// Un plan es una lista de días con fecha, tipo y título. No lleva series ni
/// pesos: la parte de gimnasio apunta a una rutina por nombre, porque los
/// pesos los decide la progresión con el historial y no un archivo escrito
/// hace dos meses.
public enum LectorPlanJSON {

    public static let versionSoportada = 1

    /// Un plan de más de dos años no es un plan, es un archivo mal hecho.
    public static let maxDias = 800
    /// Tope de cordura de una tirada: el récord del mundo de 24 h anda por 300.
    public static let maxKilometros: Double = 300

    public static func leer(_ texto: String) throws -> PlanImportado {
        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else {
            throw ErrorImportacion(ruta: "", mensaje: "El texto está vacío.")
        }
        guard let datos = limpio.data(using: .utf8) else {
            throw ErrorImportacion(ruta: "", mensaje: "El texto no se pudo leer como UTF-8.")
        }
        return try leer(datos)
    }

    public static func leer(_ datos: Data) throws -> PlanImportado {
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
                mensaje: "Se esperaba un objeto JSON con las claves «version» y «plan»."
            )
        }

        guard let version = raiz["version"] else {
            throw ErrorImportacion(ruta: "version", mensaje: "Falta. Pon \"version\": \(versionSoportada).")
        }
        guard let numeroVersion = LectorRutinasJSON.enteroDe(version) else {
            throw ErrorImportacion(ruta: "version", mensaje: "Tiene que ser un número entero.")
        }
        guard numeroVersion == versionSoportada else {
            throw ErrorImportacion(
                ruta: "version",
                mensaje: "Versión \(numeroVersion) no soportada. Esta app lee la versión \(versionSoportada)."
            )
        }

        guard let planCrudo = raiz["plan"] else {
            throw ErrorImportacion(ruta: "plan", mensaje: "Falta el objeto «plan».")
        }
        guard let plan = planCrudo as? [String: Any] else {
            throw ErrorImportacion(ruta: "plan", mensaje: "Tiene que ser un objeto con «nombre» y «dias».")
        }

        guard let nombreCrudo = plan["nombre"] as? String else {
            throw ErrorImportacion(ruta: "plan.nombre", mensaje: "Falta el nombre del plan.")
        }
        let nombre = nombreCrudo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nombre.isEmpty else {
            throw ErrorImportacion(ruta: "plan.nombre", mensaje: "El nombre está vacío.")
        }

        var objetivo: Date?
        if let objetivoCrudo = plan["objetivo"] {
            guard let texto = objetivoCrudo as? String else {
                throw ErrorImportacion(
                    ruta: "plan.objetivo",
                    mensaje: "Tiene que ser una fecha entre comillas, como \"2026-12-20\"."
                )
            }
            objetivo = try fecha(texto, ruta: "plan.objetivo")
        }

        guard let diasCrudos = plan["dias"] else {
            throw ErrorImportacion(ruta: "plan.dias", mensaje: "Falta la lista de días.")
        }
        guard let lista = diasCrudos as? [Any] else {
            throw ErrorImportacion(ruta: "plan.dias", mensaje: "Tiene que ser una lista.")
        }
        guard !lista.isEmpty else {
            throw ErrorImportacion(ruta: "plan.dias", mensaje: "La lista está vacía: hace falta al menos un día.")
        }
        guard lista.count <= maxDias else {
            throw ErrorImportacion(
                ruta: "plan.dias",
                mensaje: "\(lista.count) días son demasiados. El tope es \(maxDias)."
            )
        }

        let dias = try lista.enumerated().map { indice, elemento in
            try leerDia(elemento, ruta: "plan.dias[\(indice)]")
        }

        // Dos entradas para el mismo día dejarían el plan con dos cosas que
        // hacer y ninguna forma de elegir cuál, así que se rechaza nombrando
        // el día: es casi siempre un copiar y pegar.
        var vistas: Set<Date> = []
        for (indice, dia) in dias.enumerated() {
            guard !vistas.contains(dia.fecha) else {
                throw ErrorImportacion(
                    ruta: "plan.dias[\(indice)].fecha",
                    mensaje: "El día \(textoDe(dia.fecha)) está dos veces."
                )
            }
            vistas.insert(dia.fecha)
        }

        return PlanImportado(
            nombre: nombre,
            objetivo: objetivo,
            dias: dias.sorted { $0.fecha < $1.fecha }
        )
    }

    // MARK: - Piezas

    private static func leerDia(_ crudo: Any, ruta: String) throws -> DiaPlanValor {
        guard let objeto = crudo as? [String: Any] else {
            throw ErrorImportacion(ruta: ruta, mensaje: "Se esperaba un objeto con «fecha» y «tipo».")
        }

        guard let fechaCruda = objeto["fecha"] as? String else {
            throw ErrorImportacion(
                ruta: "\(ruta).fecha",
                mensaje: "Falta la fecha, entre comillas y como \"2026-12-20\"."
            )
        }
        let dia = try fecha(fechaCruda, ruta: "\(ruta).fecha")

        guard let tipoCrudo = objeto["tipo"] as? String else {
            throw ErrorImportacion(
                ruta: "\(ruta).tipo",
                mensaje: "Falta el tipo. Uno de: \(TipoDiaPlan.allCases.map(\.rawValue).joined(separator: ", "))."
            )
        }
        guard let tipo = TipoDiaPlan(rawValue: tipoCrudo.trimmingCharacters(in: .whitespaces)) else {
            throw ErrorImportacion(
                ruta: "\(ruta).tipo",
                mensaje: "«\(tipoCrudo)» no es un tipo. Usa uno de: \(TipoDiaPlan.allCases.map(\.rawValue).joined(separator: ", "))."
            )
        }

        let titulo = ((objeto["titulo"] as? String) ?? tipo.nombre)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let notas = ((objeto["notas"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var kilometros: Double?
        if let kmCrudo = objeto["km"] {
            guard let valor = decimalDe(kmCrudo) else {
                throw ErrorImportacion(ruta: "\(ruta).km", mensaje: "Tiene que ser un número de kilómetros.")
            }
            guard valor.isFinite, valor > 0, valor <= maxKilometros else {
                throw ErrorImportacion(
                    ruta: "\(ruta).km",
                    mensaje: "\(valor) km está fuera de rango. Tiene que estar entre 0 y \(Int(maxKilometros))."
                )
            }
            kilometros = valor
        }

        // Unos kilómetros en un día de descanso son casi siempre un tipo mal
        // puesto, y dejarlo pasar daría un día de descanso con una tirada
        // dentro que nada enseñaría.
        if kilometros != nil, !tipo.tieneCarrera {
            throw ErrorImportacion(
                ruta: "\(ruta).km",
                mensaje: "El tipo «\(tipo.rawValue)» no lleva kilómetros. Usa «carrera», «gimnasioYCarrera» o «competicion»."
            )
        }

        let rutina = (objeto["rutina"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        return DiaPlanValor(
            fecha: dia,
            tipo: tipo,
            titulo: titulo.isEmpty ? tipo.nombre : titulo,
            notas: notas,
            kilometros: kilometros,
            nombreRutina: (rutina?.isEmpty ?? true) ? nil : rutina
        )
    }

    /// Lee "2026-12-20" como la medianoche de ese día.
    ///
    /// Se construye con `DateComponents` y no con un `DateFormatter` con
    /// zona UTC: el plan se mira en la zona del teléfono, y una fecha fijada a
    /// medianoche UTC se convierte en «el día anterior a las 23:00» en España
    /// en verano, lo que movía el plan entero un día.
    static func fecha(_ texto: String, ruta: String) throws -> Date {
        let partes = texto.trimmingCharacters(in: .whitespaces).split(separator: "-")
        guard partes.count == 3,
              let año = Int(partes[0]), let mes = Int(partes[1]), let dia = Int(partes[2]),
              (1...12).contains(mes), (1...31).contains(dia), (2000...2100).contains(año)
        else {
            throw ErrorImportacion(ruta: ruta, mensaje: "«\(texto)» no es una fecha. Usa el formato \"2026-12-20\".")
        }
        var componentes = DateComponents()
        componentes.year = año
        componentes.month = mes
        componentes.day = dia
        guard let resultado = CalendarioEntrenos.es.date(from: componentes) else {
            throw ErrorImportacion(ruta: ruta, mensaje: "«\(texto)» no existe en el calendario.")
        }
        // Se comprueba la vuelta: el 31 de febrero se construye sin queja y
        // sale como 3 de marzo, que no es lo que decía el archivo.
        let vuelta = CalendarioEntrenos.es.dateComponents([.year, .month, .day], from: resultado)
        guard vuelta.year == año, vuelta.month == mes, vuelta.day == dia else {
            throw ErrorImportacion(ruta: ruta, mensaje: "«\(texto)» no existe: ese mes no tiene ese día.")
        }
        return resultado
    }

    /// "2026-12-20" a partir de una fecha, para los mensajes de error.
    static func textoDe(_ fecha: Date) -> String {
        let c = CalendarioEntrenos.es.dateComponents([.year, .month, .day], from: fecha)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func decimalDe(_ valor: Any) -> Double? {
        if let numero = valor as? Double { return numero }
        if let entero = valor as? Int { return Double(entero) }
        if let texto = valor as? String {
            return Double(texto.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }
}
