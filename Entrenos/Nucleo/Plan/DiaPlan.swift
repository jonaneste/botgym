import Foundation

/// Qué toca un día del plan.
public enum TipoDiaPlan: String, Codable, CaseIterable, Sendable {
    case gimnasio
    case gimnasioYCarrera
    case carrera
    case descanso
    /// Días de viaje: se mueve, pero no es entreno ni descanso del plan.
    case turismo
    /// El día de la carrera. Va aparte para que la cuenta atrás tenga a qué
    /// apuntar y para que no se confunda con una tirada larga más.
    case competicion

    public var nombre: String {
        switch self {
        case .gimnasio: return "Gimnasio"
        case .gimnasioYCarrera: return "Gimnasio y carrera"
        case .carrera: return "Carrera"
        case .descanso: return "Descanso"
        case .turismo: return "Turismo activo"
        case .competicion: return "Competición"
        }
    }

    /// Icono de SF Symbols. Vive aquí y no en la vista porque es parte de lo
    /// que significa el tipo, igual que el nombre.
    public var icono: String {
        switch self {
        case .gimnasio: return "dumbbell.fill"
        case .gimnasioYCarrera: return "figure.strengthtraining.traditional"
        case .carrera: return "figure.run"
        case .descanso: return "moon.zzz.fill"
        case .turismo: return "figure.walk"
        case .competicion: return "flag.checkered"
        }
    }

    /// Hay algo que hacer en el gimnasio.
    public var tieneGimnasio: Bool {
        self == .gimnasio || self == .gimnasioYCarrera
    }

    /// Hay kilómetros que correr.
    public var tieneCarrera: Bool {
        self == .carrera || self == .gimnasioYCarrera || self == .competicion
    }

    /// Un día sin nada que marcar. No se puede dar por hecho porque no hay
    /// nada que hacer: descansar no se «completa».
    public var esDescanso: Bool {
        self == .descanso
    }
}

/// Un día del plan, como valor puro.
public struct DiaPlanValor: Equatable, Sendable, Identifiable {
    public var id: Date { fecha }
    /// Medianoche del día, en el calendario de la app.
    public var fecha: Date
    public var tipo: TipoDiaPlan
    /// Lo que se lee en la fila: «Pierna y core», «Tirada larga 12 km».
    public var titulo: String
    public var notas: String
    /// Kilómetros previstos, si el día los lleva.
    public var kilometros: Double?
    /// Rutina de la app que cubre la parte de gimnasio, por nombre.
    ///
    /// Por nombre y no por identificador a propósito: el plan se escribe fuera
    /// de la app, donde los UUID de las rutinas no se conocen.
    public var nombreRutina: String?

    public init(
        fecha: Date,
        tipo: TipoDiaPlan,
        titulo: String,
        notas: String = "",
        kilometros: Double? = nil,
        nombreRutina: String? = nil
    ) {
        self.fecha = fecha
        self.tipo = tipo
        self.titulo = titulo
        self.notas = notas
        self.kilometros = kilometros
        self.nombreRutina = nombreRutina
    }
}

/// Cuentas del plan: lo que queda, lo que se ha cumplido y los kilómetros.
public enum ResumenPlan {

    /// Días que faltan hasta la competición, contando desde `hoy`.
    ///
    /// Se cuenta por días de calendario y no dividiendo segundos: con el
    /// cambio de hora de octubre, dividir por 86.400 daba un día de menos.
    public static func diasHasta(
        _ objetivo: Date,
        desde hoy: Date = Date(),
        calendario: Calendar = CalendarioEntrenos.es
    ) -> Int {
        let inicio = calendario.startOfDay(for: hoy)
        let fin = calendario.startOfDay(for: objetivo)
        return calendario.dateComponents([.day], from: inicio, to: fin).day ?? 0
    }

    /// Kilómetros previstos en un rango de días.
    public static func kilometrosPrevistos(_ dias: [DiaPlanValor]) -> Double {
        dias.compactMap(\.kilometros).reduce(0, +)
    }

    /// Los días de una semana concreta, de lunes a domingo.
    public static func semanaDe(
        _ fecha: Date,
        en dias: [DiaPlanValor],
        calendario: Calendar = CalendarioEntrenos.es
    ) -> [DiaPlanValor] {
        let inicio = CalendarioEntrenos.inicioDeSemana(de: fecha, calendario: calendario)
        let fin = CalendarioEntrenos.inicioDeSemanaSiguiente(de: fecha, calendario: calendario)
        return dias
            .filter { $0.fecha >= inicio && $0.fecha < fin }
            .sorted { $0.fecha < $1.fecha }
    }
}

/// Racha de días del plan cumplidos.
public struct RachaPlan: Equatable, Sendable {
    /// Días exigibles seguidos cumplidos, contando hacia atrás desde el último
    /// día que ya pasó.
    public var actual: Int
    /// La mejor racha de todo el plan.
    public var mejor: Int

    public init(actual: Int, mejor: Int) {
        self.actual = actual
        self.mejor = mejor
    }
}

extension ResumenPlan {

    /// Racha de días cumplidos.
    ///
    /// Los descansos y los días de turismo **no la rompen y no la suman**: no
    /// se pueden cumplir, así que contarlos como fallo apagaría la racha cada
    /// miércoles, y contarlos como acierto la regalaría. Se saltan.
    ///
    /// El día de hoy no cuenta todavía si no está marcado: aún se puede hacer,
    /// y una racha que se rompe a las 00:01 por lo que falta por hacer no es
    /// una racha.
    public static func racha(
        de dias: [(fecha: Date, esExigible: Bool, hecho: Bool)],
        hoy: Date = Date(),
        calendario: Calendar = CalendarioEntrenos.es
    ) -> RachaPlan {
        let inicioDeHoy = calendario.startOfDay(for: hoy)
        let ordenados = dias.sorted { $0.fecha < $1.fecha }

        // Mejor racha: sobre todo el plan, contando solo los exigibles.
        var mejor = 0
        var corriendo = 0
        for dia in ordenados where dia.esExigible {
            if dia.hecho {
                corriendo += 1
                mejor = max(mejor, corriendo)
            } else {
                corriendo = 0
            }
        }

        // Racha actual: hacia atrás desde hoy. El de hoy sin marcar se salta
        // en vez de romperla.
        var actual = 0
        for dia in ordenados.reversed() where dia.esExigible {
            let suDia = calendario.startOfDay(for: dia.fecha)
            if suDia > inicioDeHoy { continue }
            if suDia == inicioDeHoy, !dia.hecho { continue }
            if dia.hecho { actual += 1 } else { break }
        }

        return RachaPlan(actual: actual, mejor: mejor)
    }
}
