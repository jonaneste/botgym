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

/// Los grupos de una región, con el total de la región.
///
/// La lista de grupos era plana: dieciséis filas seguidas, cada una con su
/// aviso, y para saber cómo iba la pierna había que sumar seis a ojo. El mapa
/// del cuerpo de encima ya organiza por región y las filas ya llevan el punto
/// de color, así que la lista es el único sitio donde esa estructura se
/// perdía.
public struct SeriesDeRegion: Equatable, Sendable, Identifiable {
    public var id: String { region.rawValue }
    public var region: RegionCorporal
    public var grupos: [SeriesDeGrupo]

    public init(region: RegionCorporal, grupos: [SeriesDeGrupo]) {
        self.region = region
        self.grupos = grupos
    }

    /// Series de la región: la suma de las de sus grupos.
    public var series: Double {
        grupos.reduce(0) { $0 + $1.series }
    }

    /// Objetivo de la región, o `nil` si ninguno de sus grupos tiene uno.
    ///
    /// Suma solo los grupos que lo tienen: la alternativa, contar como cero
    /// los que no, daría una región «cumplida» por grupos que nadie se
    /// propuso.
    public var objetivo: Int? {
        let conObjetivo = grupos.compactMap(\.objetivo)
        return conObjetivo.isEmpty ? nil : conObjetivo.reduce(0, +)
    }

    /// La región como un grupo más, para reutilizar `ritmo` y `progreso` sin
    /// duplicar el criterio de «vas corto» en la vista.
    public var comoGrupo: SeriesDeGrupo {
        SeriesDeGrupo(grupo: .sinClasificar, series: series, objetivo: objetivo)
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
    /// en el orden de declaración de `GrupoMuscular`, para que la lista no
    /// baile de una semana a otra.
    ///
    /// Ese orden **no** está agrupado por región: `core` y `lumbar` son torso
    /// y van detrás de los de pierna. Quien necesite bloques por región que
    /// use `porRegion(_:)`, que sí agrupa.
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

    /// Agrupa por región, un bloque por región y en el orden de
    /// `RegionCorporal`.
    ///
    /// Cada bloque conserva sus grupos en el orden en que venían.
    ///
    /// No se puede hacer cortando la lista por tramos: el orden de
    /// `GrupoMuscular` **no** está agrupado por región. `core` y `lumbar` son
    /// torso y están declarados detrás de los de pierna, así que por tramos
    /// salían dos secciones llamadas «Torso», la primera con un total que se
    /// dejaba siete series fuera.
    public static func porRegion(_ grupos: [SeriesDeGrupo]) -> [SeriesDeRegion] {
        var porRegion: [RegionCorporal: [SeriesDeGrupo]] = [:]
        for grupo in grupos {
            porRegion[grupo.grupo.region, default: []].append(grupo)
        }
        return RegionCorporal.allCases.compactMap { region in
            guard let suyos = porRegion[region] else { return nil }
            return SeriesDeRegion(region: region, grupos: suyos)
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

    /// Series efectivas por semana y por región del cuerpo.
    ///
    /// Es para pintar la gráfica de tendencia por tramos y no como una barra
    /// gris: la pregunta que se le hace a esa gráfica no es solo «¿cuántas
    /// series?», es «¿de qué?». Una semana de 30 series que son todas de torso
    /// y ninguna de pierna se lee de un golpe, y con una barra sola no se veía.
    ///
    /// Aquí **no se ponderan los secundarios**, igual que en el total: una
    /// serie es una serie, y se cuenta en la región de su grupo principal. Si
    /// se ponderaran, la suma de los tramos no cuadraría con la altura de la
    /// barra.
    public static func seriesPorSemanaYRegion(
        _ series: [SerieConEjercicio],
        semanas: Int,
        hasta fecha: Date = Date(),
        calendario: Calendar = CalendarioEntrenos.es
    ) -> [SeriesDeSemanaYRegion] {
        let lunes = CalendarioEntrenos.ultimasSemanas(semanas, hasta: fecha, calendario: calendario)
        var resultado: [SeriesDeSemanaYRegion] = []

        for inicio in lunes {
            let fin = calendario.date(byAdding: .weekOfYear, value: 1, to: inicio) ?? inicio
            let efectivas = series.filter { $0.fecha >= inicio && $0.fecha < fin && $0.esEfectiva }

            var cuenta: [RegionCorporal: Int] = [:]
            for serie in efectivas {
                cuenta[serie.grupoPrincipal.region, default: 0] += 1
            }

            // El orden del enum, y no el del diccionario: los tramos de la
            // barra tienen que apilarse igual en todas las semanas o la
            // gráfica parece bailar.
            for region in RegionCorporal.allCases {
                guard let series = cuenta[region], series > 0 else { continue }
                resultado.append(
                    SeriesDeSemanaYRegion(inicioSemana: inicio, region: region, series: series)
                )
            }
        }

        return resultado
    }
}

/// Series de una semana, partidas por región del cuerpo.
public struct SeriesDeSemanaYRegion: Equatable, Sendable, Identifiable {
    /// La fecha no vale como identidad: hay una fila por región y semana, y
    /// usar solo la fecha hacía desaparecer tramos del `Chart` en silencio.
    public var id: String { "\(inicioSemana.timeIntervalSince1970)-\(region.rawValue)" }
    public var inicioSemana: Date
    public var region: RegionCorporal
    public var series: Int

    public init(inicioSemana: Date, region: RegionCorporal, series: Int) {
        self.inicioSemana = inicioSemana
        self.region = region
        self.series = series
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

/// Un hueco de ejercicio de una rutina, como valor puro, para poder contar lo
/// que una semana de rutinas se propone hacer.
public struct ElementoPlanificado: Equatable, Sendable {
    public var grupoPrincipal: GrupoMuscular
    public var gruposSecundarios: [GrupoMuscular]
    /// Series de trabajo. Las de calentamiento no entran: no cuentan en
    /// ningún recuento, que es lo que significa marcarlas.
    public var series: Int

    public init(grupoPrincipal: GrupoMuscular, gruposSecundarios: [GrupoMuscular], series: Int) {
        self.grupoPrincipal = grupoPrincipal
        self.gruposSecundarios = gruposSecundarios
        self.series = series
    }
}

/// Lo que una semana de rutinas se propone hacer de cada grupo.
public enum VolumenPlanificado {

    /// Series por grupo que suman los elementos dados, con la misma regla que
    /// el recuento real: el grupo principal suma una serie y cada secundario
    /// media.
    ///
    /// Sirve para poner los objetivos semanales a partir de lo que de verdad
    /// hay en las rutinas, en vez de un número de catálogo. Un objetivo que
    /// nadie puede cumplir con su propio plan no avisa de nada: pinta la
    /// semana en rojo siempre.
    public static func seriesPorGrupo(_ elementos: [ElementoPlanificado]) -> [GrupoMuscular: Double] {
        var cuenta: [GrupoMuscular: Double] = [:]
        for elemento in elementos where elemento.series > 0 {
            if elemento.grupoPrincipal.cuentaEnVolumen {
                cuenta[elemento.grupoPrincipal, default: 0] += Double(elemento.series)
            }
            for secundario in Set(elemento.gruposSecundarios)
            where secundario != elemento.grupoPrincipal && secundario.cuentaEnVolumen {
                cuenta[secundario, default: 0] += Double(elemento.series) * ServicioVolumen.pesoSecundario
            }
        }
        return cuenta
    }

    /// Los objetivos que salen de esas rutinas, redondeados a entero.
    ///
    /// Se redondea hacia abajo y no al más cercano a propósito: el objetivo es
    /// un suelo que se quiere alcanzar, y 7,5 series planificadas con un
    /// objetivo de 8 deja la semana sin cumplir haciendo justo el plan.
    /// Los grupos que no llegan a una serie entera se quedan fuera: seguir un
    /// grupo del que no se hace nada solo añade una fila en rojo.
    public static func objetivos(_ elementos: [ElementoPlanificado]) -> [GrupoMuscular: Int] {
        var resultado: [GrupoMuscular: Int] = [:]
        for (grupo, series) in seriesPorGrupo(elementos) {
            let entero = Int(series.rounded(.down))
            if entero >= 1 { resultado[grupo] = entero }
        }
        return resultado
    }
}
