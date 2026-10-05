import Foundation
import SwiftData

/// Lleva a Apple Salud los entrenos de fuerza que todavía no están allí.
///
/// Hace falta porque activar Salud no reescribe el pasado: sin esto, solo los
/// entrenos posteriores al interruptor acabarían en Salud, y Salud no serviría
/// como centro de los datos. Es idempotente: cada `Entreno` guarda el UUID que
/// le devolvió Salud, así que un entreno ya subido no se repite.
@MainActor
struct SincronizadorSalud {
    let contexto: ModelContext

    init(contexto: ModelContext) {
        self.contexto = contexto
    }

    struct Resultado: Equatable {
        var subidos: Int = 0
        /// Omitidos porque ya había un entrenamiento de otra app solapado,
        /// normalmente el que registra el reloj.
        var omitidosPorDuplicado: Int = 0
        /// Omitidos porque ya estaban en Salud.
        var yaEstaban: Int = 0
        var fallidos: Int = 0
        var primerError: String?

        var total: Int { subidos + omitidosPorDuplicado + yaEstaban + fallidos }
    }

    /// Entrenos finalizados que aún no están en Salud.
    func pendientes() -> [Entreno] {
        RepositorioEntrenos(contexto: contexto)
            .entrenosFinalizados()
            .filter { $0.idHealthKit == nil && $0.fechaFin != nil }
    }

    /// Sube los pendientes.
    ///
    /// - Parameter alAvanzar: se llama con (hechos, total) tras cada entreno,
    ///   para poder pintar una barra de progreso.
    func sincronizar(
        ajustes: Ajustes,
        alAvanzar: ((Int, Int) -> Void)? = nil
    ) async -> Resultado {
        var resultado = Resultado()
        let lista = pendientes()
        let total = lista.count

        for (indice, entreno) in lista.enumerated() {
            defer { alAvanzar?(indice + 1, total) }

            guard entreno.idHealthKit == nil else {
                resultado.yaEstaban += 1
                continue
            }
            guard let fin = entreno.fechaFin else {
                resultado.fallidos += 1
                continue
            }

            if ajustes.evitarDuplicadosEnSalud,
               await GestorHealthKit.shared.existeEntrenoDeFuerzaDeOtraApp(
                   inicio: entreno.fechaInicio,
                   fin: fin
               ) {
                resultado.omitidosPorDuplicado += 1
                continue
            }

            do {
                let uuid = try await GestorHealthKit.shared.guardarEntrenoDeFuerza(
                    inicio: entreno.fechaInicio,
                    fin: fin,
                    nombre: entreno.nombre,
                    caloriasEstimadas: Self.calorias(de: entreno, ajustes: ajustes),
                    resumen: Self.resumen(de: entreno)
                )
                entreno.idHealthKit = uuid
                resultado.subidos += 1
            } catch {
                resultado.fallidos += 1
                if resultado.primerError == nil {
                    resultado.primerError = error.localizedDescription
                }
            }
        }

        try? contexto.save()
        return resultado
    }

    /// Calorías a escribir, o `nil` si no se estiman.
    static func calorias(de entreno: Entreno, ajustes: Ajustes) -> Double? {
        guard ajustes.estimarCalorias else { return nil }
        guard let duracion = entreno.duracionFinal else { return nil }
        return EstimadorEnergia.kilocalorias(
            duracion: duracion,
            pesoCorporal: ajustes.pesoCorporal,
            met: EstimadorEnergia.metValido(ajustes.metFuerza)
        )
    }

    /// Resumen de lo hecho, para los metadatos del entrenamiento en Salud.
    ///
    /// Salud muestra los metadatos personalizados en el detalle, así que esto
    /// es lo que verás al abrir el entreno allí.
    static func resumen(de entreno: Entreno) -> String {
        let ejercicios = entreno.ejerciciosOrdenados
            .filter { !$0.seriesEfectivas.isEmpty }
            .map { "\($0.nombreEjercicio) \($0.seriesEfectivas.count)×" }
        let volumen = Int(entreno.volumenTotal.rounded())
        let cabecera = "\(entreno.seriesCompletadas) series · \(volumen) kg"
        guard !ejercicios.isEmpty else { return cabecera }
        return cabecera + " · " + ejercicios.joined(separator: ", ")
    }
}
