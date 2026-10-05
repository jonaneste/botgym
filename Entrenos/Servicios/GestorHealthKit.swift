import Foundation
import HealthKit

/// Lectura de carreras y escritura de entrenos de fuerza en Apple Health.
///
/// **HealthKit requiere el Apple Developer Program de pago**: el portal de
/// Apple no concede la capability a una cuenta gratuita. Por eso todo aquí
/// está detrás de `Ajustes.healthKitActivado`, apagado por defecto, y la app
/// funciona igual sin ello. Con cuenta gratuita, las carreras entran por el
/// importador del archivo de exportación de Salud.
@MainActor
final class GestorHealthKit {
    static let shared = GestorHealthKit()

    private let almacen = HKHealthStore()

    private init() {}

    /// `false` en el simulador y en dispositivos sin Salud.
    var disponible: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Permisos

    private var tiposALeer: Set<HKObjectType> {
        var tipos: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let distancia = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            tipos.insert(distancia)
        }
        if let pulso = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            tipos.insert(pulso)
        }
        if let energia = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            tipos.insert(energia)
        }
        return tipos
    }

    private var tiposAEscribir: Set<HKSampleType> {
        var tipos: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let energia = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            tipos.insert(energia)
        }
        return tipos
    }

    /// Pide permiso. Lanza si Salud no está disponible o el usuario lo deniega.
    func solicitarPermiso() async throws {
        guard disponible else {
            throw ErrorHealthKit.noDisponible
        }
        try await almacen.requestAuthorization(toShare: tiposAEscribir, read: tiposALeer)
    }

    // MARK: - Leer carreras

    /// Carreras registradas en Salud desde una fecha. Llegan desde Zepp.
    func carreras(desde: Date, hasta: Date = Date()) async throws -> [Carrera] {
        guard disponible else { throw ErrorHealthKit.noDisponible }

        let predicadoFecha = HKQuery.predicateForSamples(withStart: desde, end: hasta, options: [.strictStartDate])
        let predicadoTipo = HKQuery.predicateForWorkouts(with: .running)
        let predicado = NSCompoundPredicate(andPredicateWithSubpredicates: [predicadoFecha, predicadoTipo])
        let orden = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let muestras: [HKSample] = try await withCheckedThrowingContinuation { continuacion in
            let consulta = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicado,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [orden]
            ) { _, resultado, error in
                if let error {
                    continuacion.resume(throwing: error)
                } else {
                    continuacion.resume(returning: resultado ?? [])
                }
            }
            almacen.execute(consulta)
        }

        return muestras.compactMap { muestra in
            guard let entreno = muestra as? HKWorkout else { return nil }
            return carrera(de: entreno)
        }
    }

    private func carrera(de entreno: HKWorkout) -> Carrera {
        let metros = entreno.statistics(for: HKQuantityType(.distanceWalkingRunning))?
            .sumQuantity()?
            .doubleValue(for: .meter()) ?? 0

        let unidadPulso = HKUnit.count().unitDivided(by: .minute())
        let pulso = entreno.statistics(for: HKQuantityType(.heartRate))?
            .averageQuantity()?
            .doubleValue(for: unidadPulso)

        let calorias = entreno.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())

        return Carrera(
            id: entreno.uuid.uuidString,
            fechaInicio: entreno.startDate,
            duracion: entreno.duration,
            distanciaMetros: metros,
            pulsoMedio: pulso,
            calorias: calorias,
            origen: entreno.sourceRevision.source.name
        )
    }

    // MARK: - Escribir entrenos de fuerza

    /// Guarda un entreno de gimnasio en Salud como entrenamiento de fuerza.
    ///
    /// Devuelve el UUID, que se guarda en el `Entreno` para no escribirlo dos
    /// veces.
    func guardarEntrenoDeFuerza(
        inicio: Date,
        fin: Date,
        nombre: String,
        caloriasEstimadas: Double?
    ) async throws -> String {
        guard disponible else { throw ErrorHealthKit.noDisponible }
        guard fin > inicio else { throw ErrorHealthKit.fechasInvalidas }

        let configuracion = HKWorkoutConfiguration()
        configuracion.activityType = .traditionalStrengthTraining
        configuracion.locationType = .indoor

        let constructor = HKWorkoutBuilder(healthStore: almacen, configuration: configuracion, device: .local())
        try await constructor.beginCollection(at: inicio)

        if let caloriasEstimadas, caloriasEstimadas > 0,
           let tipoEnergia = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let cantidad = HKQuantity(unit: .kilocalorie(), doubleValue: caloriasEstimadas)
            let muestra = HKCumulativeQuantitySample(
                type: tipoEnergia,
                quantity: cantidad,
                start: inicio,
                end: fin
            )
            try await constructor.addSamples([muestra])
        }

        try await constructor.addMetadata([HKMetadataKeyWorkoutBrandName: nombre])
        try await constructor.endCollection(at: fin)

        guard let guardado = try await constructor.finishWorkout() else {
            throw ErrorHealthKit.noSePudoGuardar
        }
        return guardado.uuid.uuidString
    }
}

enum ErrorHealthKit: LocalizedError {
    case noDisponible
    case fechasInvalidas
    case noSePudoGuardar

    var errorDescription: String? {
        switch self {
        case .noDisponible:
            return "Salud no está disponible en este dispositivo."
        case .fechasInvalidas:
            return "El entreno no tiene una duración válida."
        case .noSePudoGuardar:
            return "Salud no devolvió el entreno guardado."
        }
    }
}
