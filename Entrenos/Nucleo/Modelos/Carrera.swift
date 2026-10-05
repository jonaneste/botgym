import Foundation

/// Una carrera leída de Apple Health.
///
/// Llegan desde Zepp, que las escribe en Salud. La app no las crea nunca: solo
/// las lee, así que esto no se persiste en SwiftData y Salud sigue siendo la
/// única fuente de verdad.
public struct Carrera: Equatable, Sendable, Identifiable {
    /// UUID del entrenamiento en Salud, para no duplicarlo al releer.
    public var id: String
    public var fechaInicio: Date
    public var duracion: TimeInterval
    public var distanciaMetros: Double
    public var pulsoMedio: Double?
    public var calorias: Double?
    /// De dónde salió: la app de Salud o un archivo de exportación.
    public var origen: String?

    public init(
        id: String,
        fechaInicio: Date,
        duracion: TimeInterval,
        distanciaMetros: Double,
        pulsoMedio: Double? = nil,
        calorias: Double? = nil,
        origen: String? = nil
    ) {
        self.id = id
        self.fechaInicio = fechaInicio
        self.duracion = duracion
        self.distanciaMetros = distanciaMetros
        self.pulsoMedio = pulsoMedio
        self.calorias = calorias
        self.origen = origen
    }

    public var distanciaKm: Double { distanciaMetros / 1000 }

    /// Ritmo en segundos por kilómetro. `nil` si no hay distancia.
    public var ritmoSegundosPorKm: Double? {
        guard distanciaMetros > 0, duracion > 0 else { return nil }
        return duracion / distanciaKm
    }

    /// Ritmo como "5:12 /km".
    public var ritmoTexto: String? {
        guard let ritmo = ritmoSegundosPorKm else { return nil }
        let total = Int(ritmo.rounded())
        return String(format: "%d:%02d /km", total / 60, total % 60)
    }

    /// Velocidad media en km/h.
    public var velocidadKmH: Double? {
        guard duracion > 0, distanciaMetros > 0 else { return nil }
        return distanciaKm / (duracion / 3600)
    }
}

/// Resumen semanal de carreras.
public struct ResumenCarreras: Equatable, Sendable {
    public var inicioSemana: Date
    public var carreras: Int
    public var kilometros: Double
    public var duracion: TimeInterval

    public init(inicioSemana: Date, carreras: Int, kilometros: Double, duracion: TimeInterval) {
        self.inicioSemana = inicioSemana
        self.carreras = carreras
        self.kilometros = kilometros
        self.duracion = duracion
    }

    /// Ritmo medio de la semana, en segundos por km.
    public var ritmoMedioSegundosPorKm: Double? {
        guard kilometros > 0, duracion > 0 else { return nil }
        return duracion / kilometros
    }
}

/// Agregados de carreras.
public enum ServicioCarreras {

    /// Resumen de la semana en que cae `fecha`.
    public static func resumenSemanal(
        _ carreras: [Carrera],
        semanaDe fecha: Date,
        calendario: Calendar = CalendarioEntrenos.es
    ) -> ResumenCarreras {
        let inicio = CalendarioEntrenos.inicioDeSemana(de: fecha, calendario: calendario)
        let fin = CalendarioEntrenos.inicioDeSemanaSiguiente(de: fecha, calendario: calendario)
        let deLaSemana = carreras.filter { $0.fechaInicio >= inicio && $0.fechaInicio < fin }

        return ResumenCarreras(
            inicioSemana: inicio,
            carreras: deLaSemana.count,
            kilometros: deLaSemana.reduce(0) { $0 + $1.distanciaKm },
            duracion: deLaSemana.reduce(0) { $0 + $1.duracion }
        )
    }

    /// Kilómetros por semana, de más antigua a más reciente, incluidas las
    /// semanas sin correr.
    public static func kilometrosPorSemana(
        _ carreras: [Carrera],
        semanas: Int,
        hasta fecha: Date = Date(),
        calendario: Calendar = CalendarioEntrenos.es
    ) -> [ResumenCarreras] {
        CalendarioEntrenos.ultimasSemanas(semanas, hasta: fecha, calendario: calendario)
            .map { resumenSemanal(carreras, semanaDe: $0, calendario: calendario) }
    }
}
