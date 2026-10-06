import Foundation
import SwiftData

/// Puente entre SwiftData y la lógica del núcleo.
///
/// Convierte los modelos a tipos valor antes de pasarlos a los servicios de
/// progresión, récords y volumen. Toda la aritmética vive en el núcleo; aquí
/// solo se consulta y se traduce.
struct RepositorioProgreso {
    let contexto: ModelContext
    private let repositorio: RepositorioEntrenos

    init(contexto: ModelContext) {
        self.contexto = contexto
        self.repositorio = RepositorioEntrenos(contexto: contexto)
    }

    // MARK: - Sesiones de un ejercicio

    /// Historial de un ejercicio como sesiones de valores puros.
    func sesiones(idEjercicio: UUID, limite: Int? = nil) -> [SesionEjercicio] {
        repositorio.historial(idEjercicio: idEjercicio, limite: limite)
            .map {
                // La identidad es la de la fila, no la fecha: todos los
                // ejercicios de un entreno comparten `fechaEntreno`, así que
                // el mismo ejercicio repetido en una sesión daba dos sesiones
                // con fecha idéntica y una de las dos desaparecía de la lista
                // y de la gráfica.
                SesionEjercicio(id: $0.idPublico, fecha: $0.fechaEntreno, series: $0.seriesValor)
            }
    }

    // MARK: - Récords

    func records(idEjercicio: UUID, tipo: TipoRegistro) -> RecordsEjercicio {
        ServicioRecords.records(de: sesiones(idEjercicio: idEjercicio), tipo: tipo)
    }

    /// Récords de un ejercicio excluyendo un entreno concreto, normalmente el
    /// que está en curso. Es lo que hay que comparar para avisar de un récord
    /// nuevo: si incluyéramos el entreno de hoy, la serie que acaba de batirlo
    /// ya estaría dentro y nunca saltaría el aviso.
    func recordsPrevios(idEjercicio: UUID, tipo: TipoRegistro, excluyendoEntreno: UUID?) -> RecordsEjercicio {
        let historial = repositorio.historial(idEjercicio: idEjercicio)
            .filter { ejercicio in
                guard let excluyendoEntreno else { return true }
                return ejercicio.entreno?.idPublico != excluyendoEntreno
            }
            .map { SesionEjercicio(id: $0.idPublico, fecha: $0.fechaEntreno, series: $0.seriesValor) }
        return ServicioRecords.records(de: historial, tipo: tipo)
    }

    func puntosGrafica(idEjercicio: UUID, tipo: TipoRegistro) -> [PuntoGrafica] {
        ServicioRecords.puntosGrafica(de: sesiones(idEjercicio: idEjercicio), tipo: tipo)
    }

    // MARK: - Progresión

    /// Sugerencia de carga para un ejercicio, a partir de su última sesión.
    func sugerencia(
        idEjercicio: UUID,
        objetivo: ObjetivoEjercicio,
        material: Material,
        tipo: TipoRegistro,
        reglas: ReglasIncremento,
        excluyendoEntreno: UUID?
    ) -> SugerenciaProgresion {
        let anterior = repositorio.ultimaActuacion(
            idEjercicio: idEjercicio,
            excluyendo: excluyendoEntreno
        )
        return ServicioProgresion.sugerencia(
            seriesAnteriores: anterior?.seriesValor ?? [],
            objetivo: objetivo,
            material: material,
            tipo: tipo,
            reglas: reglas
        )
    }

    // MARK: - Volumen semanal

    /// Todas las series del historial con su grupo muscular, para el recuento
    /// semanal.
    ///
    /// - Parameter desde: fecha a partir de la cual mirar. Acota el trabajo:
    ///   para la vista semanal no hace falta recorrer dos años de historial.
    func seriesConEjercicio(desde: Date) -> [SerieConEjercicio] {
        let entrenos = repositorio.entrenosFinalizados(desde: desde, hasta: Date.distantFuture)
        var resultado: [SerieConEjercicio] = []

        for entreno in entrenos {
            for ejercicioEntreno in entreno.ejercicios {
                // El grupo sale del ejercicio de la biblioteca. Si se borró,
                // la serie no se puede clasificar y se omite del recuento.
                guard let ejercicio = ejercicioEntreno.ejercicio else { continue }
                let principal = ejercicio.grupoPrincipal
                let secundarios = ejercicio.gruposSecundarios

                for serie in ejercicioEntreno.series where serie.esEfectiva {
                    resultado.append(
                        SerieConEjercicio(
                            fecha: entreno.fechaInicio,
                            grupoPrincipal: principal,
                            gruposSecundarios: secundarios,
                            peso: serie.peso,
                            repeticiones: serie.repeticiones,
                            esEfectiva: true
                        )
                    )
                }
            }
        }
        return resultado
    }

    /// Series semanales frente a los objetivos configurados.
    func seriesSemanales(semanaDe fecha: Date, objetivos: [GrupoMuscular: Int]) -> [SeriesDeGrupo] {
        let inicio = CalendarioEntrenos.inicioDeSemana(de: fecha)
        return ServicioVolumen.seriesSemanales(
            seriesConEjercicio(desde: inicio),
            semanaDe: fecha,
            objetivos: objetivos
        )
    }

    /// Tendencia de series por semana.
    func tendenciaSemanal(semanas: Int, grupo: GrupoMuscular? = nil) -> [SeriesDeSemana] {
        let desde = CalendarioEntrenos.ultimasSemanas(semanas).first ?? Date()
        return ServicioVolumen.seriesPorSemana(
            seriesConEjercicio(desde: desde),
            semanas: semanas,
            grupo: grupo
        )
    }

    // MARK: - Ejercicios con historial

    /// Ejercicios que tienen al menos un entreno registrado, de más reciente a
    /// más antiguo por última vez hecho. Es la lista de la pestaña Progreso.
    func ejerciciosConHistorial() -> [(ejercicio: Ejercicio, ultimaVez: Date)] {
        let descriptor = FetchDescriptor<EjercicioEntreno>(
            predicate: #Predicate<EjercicioEntreno> { $0.entrenoFinalizado },
            sortBy: [SortDescriptor(\.fechaEntreno, order: .reverse)]
        )
        guard let realizados = try? contexto.fetch(descriptor) else { return [] }

        var vistos: Set<UUID> = []
        var resultado: [(Ejercicio, Date)] = []
        for realizado in realizados {
            guard let ejercicio = realizado.ejercicio else { continue }
            guard !vistos.contains(ejercicio.idPublico) else { continue }
            vistos.insert(ejercicio.idPublico)
            resultado.append((ejercicio, realizado.fechaEntreno))
        }
        return resultado.map { (ejercicio: $0.0, ultimaVez: $0.1) }
    }
}
