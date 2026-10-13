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

    /// Cómo va el grupo **teniendo en cuenta cuánta semana queda**.
    ///
    /// Sin esto, la interfaz pintaba de rojo todo lo que estuviera por debajo
    /// del 60 % del objetivo, así que el lunes la pantalla entera salía en rojo
    /// aunque la semana fuese perfectamente bien. Un aviso que salta siempre no
    /// avisa de nada.
    ///
    /// - Parameter fraccionDeSemana: parte de la semana ya transcurrida, de 0 a
    ///   1, tal como la da `CalendarioEntrenos.fraccionTranscurridaDeSemana`.
    public func ritmo(fraccionDeSemana: Double) -> RitmoSemanal {
        guard let progreso else { return .sinObjetivo }
        if cumplido { return .cumplido }

        let transcurrido = min(1, max(0, fraccionDeSemana))

        // Un día de margen antes de considerar que vas por detrás: el lunes a
        // primera hora no se va corto de nada, queda la semana entera.
        let margen = 1.0 / 7.0
        if progreso >= transcurrido - margen { return .alDia }

        // Y por detrás hay dos situaciones distintas: la que se arregla
        // apretando, y la que ya no da. El corte está en si lo que falta cabe
        // en lo que queda de semana yendo al doble del ritmo medio.
        let falta = 1 - progreso
        let queda = 1 - transcurrido
        return falta <= queda * 2 ? .corto : .muyCorto
    }
}

/// Cómo va un grupo frente a su objetivo semanal, a estas alturas de la semana.
public enum RitmoSemanal: Equatable, Sendable {
    /// No hay objetivo configurado: no hay nada que juzgar.
    case sinObjetivo
    case cumplido
    /// Al ritmo necesario, o por delante.
    case alDia
    /// Por detrás, pero aún cabe en lo que queda de semana.
    case corto
    /// Por detrás de lo que queda de semana da de sí.
    case muyCorto
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
    ///
    /// Los grupos que no son músculo (`sinClasificar`) no aparecen: una serie
    /// de un ejercicio sin clasificar es trabajo real, pero no se sabe de qué,
    /// y ponerla en cualquier grupo falsea el recuento semanal.
    public static func seriesPorGrupo(_ series: [SerieConEjercicio]) -> [GrupoMuscular: Double] {
        var cuenta: [GrupoMuscular: Double] = [:]
        for serie in series where serie.esEfectiva {
            if serie.grupoPrincipal.cuentaEnVolumen {
                cuenta[serie.grupoPrincipal, default: 0] += 1
            }
            for secundario in Set(serie.gruposSecundarios)
            where secundario != serie.grupoPrincipal && secundario.cuentaEnVolumen {
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
            // El filtro por `cuentaEnVolumen` no sobra: un objetivo guardado
            // de una versión anterior podría nombrar un grupo que ya no suma,
            // y entonces aparecería la fila con un objetivo imposible de
            // cumplir.
            .filter { $0.cuentaEnVolumen && relevantes.contains($0) }
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
                // Y por lo mismo entran las sin clasificar, que sí se hicieron:
                // lo que no se sabe es a qué músculo apuntarlas, no si existen.
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
