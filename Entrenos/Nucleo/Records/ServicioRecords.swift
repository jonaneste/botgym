import Foundation

/// Una sesión pasada de un ejercicio, como valor puro.
public struct SesionEjercicio: Equatable, Sendable {
    public var fecha: Date
    public var series: [SerieValor]

    public init(fecha: Date, series: [SerieValor]) {
        self.fecha = fecha
        self.series = series
    }

    public var seriesEfectivas: [SerieValor] {
        series.filter(\.esEfectiva)
    }

    public var volumen: Double {
        seriesEfectivas.reduce(0) { $0 + $1.volumen }
    }
}

/// Récords personales de un ejercicio.
public struct RecordsEjercicio: Equatable, Sendable {
    public var pesoMaximo: Double?
    public var fechaPesoMaximo: Date?
    public var mejorUnRM: Double?
    public var fechaMejorUnRM: Date?
    public var mejorVolumenSesion: Double?
    public var fechaMejorVolumen: Date?
    /// Solo en ejercicios de tiempo.
    public var mejorTiempo: Int?
    public var fechaMejorTiempo: Date?

    public init() {}

    public var estaVacio: Bool {
        pesoMaximo == nil && mejorUnRM == nil && mejorVolumenSesion == nil && mejorTiempo == nil
    }
}

/// Qué récord se acaba de batir.
public enum TipoRecord: String, Equatable, Sendable, CaseIterable {
    case peso
    case unRM
    case volumenSesion
    case tiempo

    public var nombre: String {
        switch self {
        case .peso: return "Peso máximo"
        case .unRM: return "1RM estimado"
        case .volumenSesion: return "Volumen en sesión"
        case .tiempo: return "Tiempo máximo"
        }
    }
}

public struct RecordBatido: Equatable, Sendable {
    public var tipo: TipoRecord
    public var valor: Double
    /// El récord anterior, o `nil` si no había.
    public var anterior: Double?

    public init(tipo: TipoRecord, valor: Double, anterior: Double?) {
        self.tipo = tipo
        self.valor = valor
        self.anterior = anterior
    }
}

/// Cálculo y detección de récords personales.
public enum ServicioRecords {

    /// Récords a partir del historial completo de un ejercicio.
    ///
    /// Solo cuentan las series completadas que no son calentamiento. En los
    /// ejercicios de tiempo no se calcula 1RM, porque no significa nada.
    public static func records(
        de sesiones: [SesionEjercicio],
        tipo: TipoRegistro
    ) -> RecordsEjercicio {
        var resultado = RecordsEjercicio()

        for sesion in sesiones {
            let efectivas = sesion.seriesEfectivas
            guard !efectivas.isEmpty else { continue }

            // Peso máximo. Se exige peso > 0 para no registrar un "récord" de
            // 0 kg en los ejercicios a peso corporal sin lastre.
            if let pesoSesion = efectivas.map(\.peso).max(), pesoSesion > 0 {
                if resultado.pesoMaximo == nil || pesoSesion > resultado.pesoMaximo! {
                    resultado.pesoMaximo = pesoSesion
                    resultado.fechaPesoMaximo = sesion.fecha
                }
            }

            // 1RM estimado, solo con repeticiones.
            if !tipo.esTiempo {
                let estimaciones = efectivas.compactMap {
                    CalculadoraRM.epley(peso: $0.peso, repeticiones: $0.repeticiones)
                }
                if let mejor = estimaciones.max() {
                    if resultado.mejorUnRM == nil || mejor > resultado.mejorUnRM! {
                        resultado.mejorUnRM = mejor
                        resultado.fechaMejorUnRM = sesion.fecha
                    }
                }
            }

            // Tiempo máximo, solo en isométricos.
            if tipo.esTiempo {
                if let mejorSegundos = efectivas.compactMap(\.segundos).max(), mejorSegundos > 0 {
                    if resultado.mejorTiempo == nil || mejorSegundos > resultado.mejorTiempo! {
                        resultado.mejorTiempo = mejorSegundos
                        resultado.fechaMejorTiempo = sesion.fecha
                    }
                }
            }

            // Volumen de la sesión.
            let volumen = sesion.volumen
            if volumen > 0 {
                if resultado.mejorVolumenSesion == nil || volumen > resultado.mejorVolumenSesion! {
                    resultado.mejorVolumenSesion = volumen
                    resultado.fechaMejorVolumen = sesion.fecha
                }
            }
        }

        return resultado
    }

    /// Récords que bate una serie recién marcada, comparada con los récords
    /// previos. Es lo que dispara el aviso durante el entreno.
    ///
    /// No incluye el volumen de sesión: ese solo se puede saber al terminar.
    public static func recordsBatidos(
        por serie: SerieValor,
        tipo: TipoRegistro,
        frenteA records: RecordsEjercicio
    ) -> [RecordBatido] {
        guard serie.esEfectiva else { return [] }
        var batidos: [RecordBatido] = []

        if tipo.esTiempo {
            if let segundos = serie.segundos, segundos > 0,
               records.mejorTiempo == nil || segundos > records.mejorTiempo! {
                batidos.append(
                    RecordBatido(
                        tipo: .tiempo,
                        valor: Double(segundos),
                        anterior: records.mejorTiempo.map(Double.init)
                    )
                )
            }
            return batidos
        }

        if serie.peso > 0, records.pesoMaximo == nil || serie.peso > records.pesoMaximo! {
            batidos.append(
                RecordBatido(tipo: .peso, valor: serie.peso, anterior: records.pesoMaximo)
            )
        }

        if let estimado = CalculadoraRM.epley(peso: serie.peso, repeticiones: serie.repeticiones),
           records.mejorUnRM == nil || estimado > records.mejorUnRM! {
            batidos.append(
                RecordBatido(tipo: .unRM, valor: estimado, anterior: records.mejorUnRM)
            )
        }

        return batidos
    }

    /// Comprueba si el volumen de la sesión que acaba de cerrarse es récord.
    public static func recordDeVolumen(
        volumenSesion: Double,
        frenteA records: RecordsEjercicio
    ) -> RecordBatido? {
        guard volumenSesion > 0 else { return nil }
        guard records.mejorVolumenSesion == nil || volumenSesion > records.mejorVolumenSesion! else {
            return nil
        }
        return RecordBatido(
            tipo: .volumenSesion,
            valor: volumenSesion,
            anterior: records.mejorVolumenSesion
        )
    }

    /// Récords actualizados con una serie recién marcada.
    ///
    /// Se usa durante el entreno para no volver a avisar del mismo récord: en
    /// cuanto una serie lo bate, se incorpora, y la siguiente serie se compara
    /// ya contra el valor nuevo.
    public static func incorporando(
        _ serie: SerieValor,
        tipo: TipoRegistro,
        en records: RecordsEjercicio,
        fecha: Date
    ) -> RecordsEjercicio {
        guard serie.esEfectiva else { return records }
        var resultado = records

        if tipo.esTiempo {
            if let segundos = serie.segundos, segundos > 0,
               resultado.mejorTiempo == nil || segundos > resultado.mejorTiempo! {
                resultado.mejorTiempo = segundos
                resultado.fechaMejorTiempo = fecha
            }
            return resultado
        }

        if serie.peso > 0, resultado.pesoMaximo == nil || serie.peso > resultado.pesoMaximo! {
            resultado.pesoMaximo = serie.peso
            resultado.fechaPesoMaximo = fecha
        }

        if let estimado = CalculadoraRM.epley(peso: serie.peso, repeticiones: serie.repeticiones),
           resultado.mejorUnRM == nil || estimado > resultado.mejorUnRM! {
            resultado.mejorUnRM = estimado
            resultado.fechaMejorUnRM = fecha
        }

        return resultado
    }

    /// Serie de puntos para la gráfica de un ejercicio: por sesión, el mejor
    /// 1RM estimado y el peso máximo.
    public static func puntosGrafica(
        de sesiones: [SesionEjercicio],
        tipo: TipoRegistro
    ) -> [PuntoGrafica] {
        sesiones.compactMap { sesion in
            let efectivas = sesion.seriesEfectivas
            guard !efectivas.isEmpty else { return nil }

            let pesoMaximo = efectivas.map(\.peso).max() ?? 0
            let unRM: Double? = tipo.esTiempo
                ? nil
                : efectivas.compactMap { CalculadoraRM.epley(peso: $0.peso, repeticiones: $0.repeticiones) }.max()
            let segundos = tipo.esTiempo ? efectivas.compactMap(\.segundos).max() : nil

            return PuntoGrafica(
                fecha: sesion.fecha,
                pesoMaximo: pesoMaximo,
                unRMEstimado: unRM,
                volumen: sesion.volumen,
                segundosMaximo: segundos
            )
        }
        .sorted { $0.fecha < $1.fecha }
    }
}

/// Un punto de la gráfica de progreso de un ejercicio.
public struct PuntoGrafica: Equatable, Sendable, Identifiable {
    public var id: Date { fecha }
    public var fecha: Date
    public var pesoMaximo: Double
    public var unRMEstimado: Double?
    public var volumen: Double
    public var segundosMaximo: Int?

    public init(
        fecha: Date,
        pesoMaximo: Double,
        unRMEstimado: Double?,
        volumen: Double,
        segundosMaximo: Int? = nil
    ) {
        self.fecha = fecha
        self.pesoMaximo = pesoMaximo
        self.unRMEstimado = unRMEstimado
        self.volumen = volumen
        self.segundosMaximo = segundosMaximo
    }
}
