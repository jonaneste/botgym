import Foundation

/// Una serie con el ejercicio al que pertenece, para contar volumen por grupo.
public struct SerieConEjercicio: Equatable, Sendable {
    public var fecha: Date
    public var grupoPrincipal: GrupoMuscular
    public var gruposSecundarios: [GrupoMuscular]
    public var peso: Double
    public var repeticiones: Int
    public var esEfectiva: Bool

    public init(
        fecha: Date,
        grupoPrincipal: GrupoMuscular,
        gruposSecundarios: [GrupoMuscular],
        peso: Double,
        repeticiones: Int,
        esEfectiva: Bool
    ) {
        self.fecha = fecha
        self.grupoPrincipal = grupoPrincipal
        self.gruposSecundarios = gruposSecundarios
        self.peso = peso
        self.repeticiones = repeticiones
        self.esEfectiva = esEfectiva
    }

    public var volumen: Double { peso * Double(repeticiones) }
}

/// Series semanales de un grupo muscular frente a su objetivo.
public struct SeriesDeGrupo: Equatable, Sendable, Identifiable {
    public var id: String { grupo.rawValue }
    public var grupo: GrupoMuscular
    /// Series contadas. Es un decimal porque los grupos secundarios suman 0,5.
    public var series: Double
    /// Objetivo configurado, o `nil` si no hay ninguno para este grupo.
    public var objetivo: Int?

    public init(grupo: GrupoMuscular, series: Double, objetivo: Int?) {
        self.grupo = grupo
        self.series = series
        self.objetivo = objetivo
    }

    /// Progreso de 0 a 1 frente al objetivo. `nil` si no hay objetivo.
    public var progreso: Double? {
        guard let objetivo, objetivo > 0 else { return nil }
        return min(1, series / Double(objetivo))
    }

    /// `true` si ya se alcanzó el objetivo.
    public var cumplido: Bool {
        guard let objetivo, objetivo > 0 else { return false }
        return series >= Double(objetivo)
    }

    /// Series que faltan para el objetivo, redondeadas hacia arriba.
    public var faltan: Int? {
        guard let objetivo, objetivo > 0 else { return nil }
        return max(0, Int((Double(objetivo) - series).rounded(.up)))
    }
}

/// Volumen y recuento de series por grupo muscular.
public enum ServicioVolumen {

    /// Peso con el que cuenta un grupo secundario. Media serie, como pidió el
    /// usuario: un press de banca entrena tríceps, pero no como una extensión.
    public static let pesoSecundario = 0.5

    // MARK: - Volumen

    /// Volumen en kg levantados: suma de peso × reps de las series efectivas.
    public static func volumen(de series: [SerieValor]) -> Double {
        series.filter(\.esEfectiva).reduce(0) { $0 + $1.volumen }
    }

    // MARK: - Series por grupo

    /// Cuenta las series por grupo muscular. El grupo principal suma 1 y cada
    /// secundario 0,5.
    public static func seriesPorGrupo(_ series: [SerieConEjercicio]) -> [GrupoMuscular: Double] {
        var cuenta: [GrupoMuscular: Double] = [:]
        for serie in series where serie.esEfectiva {
            cuenta[serie.grupoPrincipal, default: 0] += 1
            for secundario in Set(serie.gruposSecundarios) where secundario != serie.grupoPrincipal {
                cuenta[secundario, default: 0] += pesoSecundario
            }
        }
        return cuenta
    }

    /// Series de la semana en que cae `semanaDe`, frente a los objetivos.
    ///
    /// Devuelve solo los grupos con series hechas o con objetivo configurado,
    /// ordenados por región del cuerpo y luego por nombre, para que la lista no
    /// baile de una semana a otra.
    public static func seriesSemanales(
        _ series: [SerieConEjercicio],
        semanaDe fecha: Date,
        objetivos: [GrupoMuscular: Int] = [:],
        calendario: Calendar = CalendarioEntrenos.es
    ) -> [SeriesDeGrupo] {
        let inicio = CalendarioEntrenos.inicioDeSemana(de: fecha, calendario: calendario)
        let fin = CalendarioEntrenos.inicioDeSemanaSiguiente(de: fecha, calendario: calendario)

        let deLaSemana = series.filter { $0.fecha >= inicio && $0.fecha < fin }
        let cuenta = seriesPorGrupo(deLaSemana)

        let relevantes = Set(cuenta.keys).union(objetivos.keys)

        return GrupoMuscular.allCases
            .filter { relevantes.contains($0) }
            .map { grupo in
                SeriesDeGrupo(
                    grupo: grupo,
                    series: cuenta[grupo] ?? 0,
                    objetivo: objetivos[grupo]
                )
            }
    }

    /// Series totales por semana, para la gráfica de tendencia.
    ///
    /// Devuelve un valor por cada una de las `semanas` últimas semanas, de más
    /// antigua a más reciente, incluidas las semanas sin entrenar.
    public static func seriesPorSemana(
        _ series: [SerieConEjercicio],
        semanas: Int,
        hasta fecha: Date = Date(),
        grupo: GrupoMuscular? = nil,
        calendario: Calendar = CalendarioEntrenos.es
    ) -> [SeriesDeSemana] {
        let lunes = CalendarioEntrenos.ultimasSemanas(semanas, hasta: fecha, calendario: calendario)
        return lunes.map { inicio in
            let fin = calendario.date(byAdding: .weekOfYear, value: 1, to: inicio) ?? inicio
            let deLaSemana = series.filter { $0.fecha >= inicio && $0.fecha < fin }
            let cuenta = seriesPorGrupo(deLaSemana)
            let total: Double
            if let grupo {
                total = cuenta[grupo] ?? 0
            } else {
                // Sin grupo, el total son las series efectivas tal cual: aquí
                // no se ponderan secundarios, porque una serie es una serie.
                total = Double(deLaSemana.filter(\.esEfectiva).count)
            }
            return SeriesDeSemana(inicioSemana: inicio, series: total)
        }
    }
}

/// Series de una semana concreta, para la gráfica de tendencia.
public struct SeriesDeSemana: Equatable, Sendable, Identifiable {
    public var id: Date { inicioSemana }
    public var inicioSemana: Date
    public var series: Double

    public init(inicioSemana: Date, series: Double) {
        self.inicioSemana = inicioSemana
        self.series = series
    }
}
