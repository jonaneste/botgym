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
            .filter { entreno in
                entreno.idHealthKit == nil
                    && entreno.fechaFin != nil
                    && !EscriturasEnSalud.estaEnCurso(entreno.idPublico)
            }
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
                // Se guarda tras CADA entreno, no al final del bucle. El UUID
                // que devuelve Salud es la única llave de idempotencia que
                // tenemos: si la app se va a segundo plano y el sistema la
                // mata a mitad de una subida de sesenta entrenos, con un
                // guardado único al final se perdían las llaves de todos los
                // que ya estaban escritos, y la siguiente subida los duplicaba
                // en Salud sin forma de distinguir las copias.
                try? contexto.save()
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
        let volumen = LimitesEntrada.entero(entreno.volumenTotal)
        let cabecera = "\(entreno.seriesCompletadas) series · \(volumen) kg"
        guard !ejercicios.isEmpty else { return cabecera }
        return cabecera + " · " + ejercicios.joined(separator: ", ")
    }
}

/// Entrenos que ahora mismo se están escribiendo en Salud.
///
/// Hacen falta porque hay dos caminos que escriben: el cierre de un entreno
/// (`ControladorEntreno.escribirEnSalud`) y la subida manual del historial.
/// El primero lanza un `Task` y vuelve en seguida, así que el entreno queda
/// guardado con `idHealthKit == nil` durante los segundos que tarda Salud en
/// responder, que con el diálogo de permisos pueden ser bastantes. En esa
/// ventana la subida manual lo veía pendiente y lo escribía otra vez.
///
/// No lo salva la detección de duplicados: `existeEntrenoDeFuerzaDeOtraApp`
/// ignora a propósito las muestras de la propia app, que es lo que permite que
/// el entreno del reloj gane al nuestro.
@MainActor
enum EscriturasEnSalud {
    private static var enCurso: Set<UUID> = []

    /// Reserva el entreno. Devuelve `false` si ya lo estaba escribiendo otro.
    static func reservar(_ id: UUID) -> Bool {
        enCurso.insert(id).inserted
    }

    static func liberar(_ id: UUID) {
        enCurso.remove(id)
    }

    static func estaEnCurso(_ id: UUID) -> Bool {
        enCurso.contains(id)
    }
}
