import Foundation
import SwiftData

/// Consultas sobre el historial.
///
/// Todas las búsquedas van contra campos escalares denormalizados en lugar de
/// atravesar relaciones, porque en iOS 17 un `#Predicate` que navega una
/// relación puede petar en tiempo de ejecución.
struct RepositorioEntrenos {
    let contexto: ModelContext

    init(contexto: ModelContext) {
        self.contexto = contexto
    }

    // MARK: - Entreno en curso

    /// El entreno abierto, si hay alguno. Es lo que permite reanudar tras
    /// cerrar la app.
    func entrenoEnCurso() -> Entreno? {
        let enCurso = EstadoEntreno.enCurso.rawValue
        var descriptor = FetchDescriptor<Entreno>(
            predicate: #Predicate<Entreno> { $0.estadoRaw == enCurso },
            sortBy: [SortDescriptor(\.fechaInicio, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? contexto.fetch(descriptor).first
    }

    // MARK: - Última actuación

    /// Lo que se hizo la última vez en este ejercicio, para pintar
    /// "Anterior: 60 kg × 9" junto a cada serie.
    ///
    /// - Parameters:
    ///   - idEjercicio: identificador público del ejercicio.
    ///   - excluyendo: entreno a ignorar, normalmente el que está en curso.
    func ultimaActuacion(idEjercicio: UUID, excluyendo: UUID? = nil) -> EjercicioEntreno? {
        var descriptor = FetchDescriptor<EjercicioEntreno>(
            predicate: #Predicate<EjercicioEntreno> { $0.idEjercicio == idEjercicio && $0.entrenoFinalizado },
            sortBy: [SortDescriptor(\.fechaEntreno, order: .reverse)]
        )
        // Se piden unos pocos y se filtra en Swift: el entreno a excluir no se
        // puede expresar en el predicado sin tocar la relación.
        descriptor.fetchLimit = 8
        guard let candidatos = try? contexto.fetch(descriptor) else { return nil }
        return candidatos.first { candidato in
            guard let excluyendo else { return true }
            return candidato.entreno?.idPublico != excluyendo
        }
    }

    /// Historial completo de un ejercicio, de más reciente a más antiguo.
    /// Alimenta las gráficas y el cálculo de récords.
    func historial(idEjercicio: UUID, limite: Int? = nil) -> [EjercicioEntreno] {
        var descriptor = FetchDescriptor<EjercicioEntreno>(
            predicate: #Predicate<EjercicioEntreno> { $0.idEjercicio == idEjercicio && $0.entrenoFinalizado },
            sortBy: [SortDescriptor(\.fechaEntreno, order: .reverse)]
        )
        if let limite { descriptor.fetchLimit = limite }
        return (try? contexto.fetch(descriptor)) ?? []
    }

    // MARK: - Entrenos finalizados

    func entrenosFinalizados(limite: Int? = nil) -> [Entreno] {
        let finalizado = EstadoEntreno.finalizado.rawValue
        var descriptor = FetchDescriptor<Entreno>(
            predicate: #Predicate<Entreno> { $0.estadoRaw == finalizado },
            sortBy: [SortDescriptor(\.fechaInicio, order: .reverse)]
        )
        if let limite { descriptor.fetchLimit = limite }
        return (try? contexto.fetch(descriptor)) ?? []
    }

    /// Entrenos finalizados dentro de un intervalo, para los resúmenes
    /// semanales.
    func entrenosFinalizados(desde: Date, hasta: Date) -> [Entreno] {
        let finalizado = EstadoEntreno.finalizado.rawValue
        let descriptor = FetchDescriptor<Entreno>(
            predicate: #Predicate<Entreno> {
                $0.estadoRaw == finalizado && $0.fechaInicio >= desde && $0.fechaInicio < hasta
            },
            sortBy: [SortDescriptor(\.fechaInicio, order: .reverse)]
        )
        return (try? contexto.fetch(descriptor)) ?? []
    }

    // MARK: - Ejercicios

    func ejercicios() -> [Ejercicio] {
        let descriptor = FetchDescriptor<Ejercicio>(
            sortBy: [SortDescriptor(\.nombre, order: .forward)]
        )
        return (try? contexto.fetch(descriptor)) ?? []
    }

    func ejercicio(idPublico: UUID) -> Ejercicio? {
        var descriptor = FetchDescriptor<Ejercicio>(
            predicate: #Predicate<Ejercicio> { $0.idPublico == idPublico }
        )
        descriptor.fetchLimit = 1
        return try? contexto.fetch(descriptor).first
    }

    /// Busca un ejercicio por nombre, ignorando mayúsculas y acentos.
    /// Lo usa el importador de rutinas JSON.
    func ejercicio(nombreAproximado nombre: String) -> Ejercicio? {
        let buscado = Ejercicio.normalizar(nombre)
        return ejercicios().first { $0.nombreNormalizado == buscado }
    }

    // MARK: - Carpetas y rutinas

    func carpetas() -> [CarpetaRutinas] {
        let descriptor = FetchDescriptor<CarpetaRutinas>(
            sortBy: [SortDescriptor(\.orden, order: .forward)]
        )
        return (try? contexto.fetch(descriptor)) ?? []
    }

    func rutinasSueltas() -> [Rutina] {
        let descriptor = FetchDescriptor<Rutina>(
            sortBy: [SortDescriptor(\.orden, order: .forward)]
        )
        let todas = (try? contexto.fetch(descriptor)) ?? []
        return todas.filter { $0.carpeta == nil }
    }

    // MARK: - Recuento

    func hayDatos() -> Bool {
        let descriptor = FetchDescriptor<Ejercicio>()
        let cuenta = (try? contexto.fetchCount(descriptor)) ?? 0
        return cuenta > 0
    }
}
