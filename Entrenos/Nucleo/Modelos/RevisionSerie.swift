import Foundation

/// Una cifra de una serie que no es imposible, pero que casi nunca es lo que
/// se quiso escribir.
public enum SospechaSerie: String, Equatable, Sendable, CaseIterable {
    /// Más repeticiones de las que se hacen con peso encima.
    case repeticiones
    /// Más repeticiones en reserva de las que caben en una serie.
    case rir

    /// Texto para el usuario, en la fila y como etiqueta de VoiceOver.
    public var aviso: String {
        switch self {
        case .repeticiones: return "Revisa las repeticiones, son muchas"
        case .rir: return "Revisa el RIR, es muy alto"
        }
    }

    /// Nombre del campo, para enumerar varias sospechas en una frase.
    public var campo: String {
        switch self {
        case .repeticiones: return "repeticiones"
        case .rir: return "RIR"
        }
    }
}

/// Qué cifras de una serie conviene mirar dos veces.
///
/// El umbral no se bloquea en ningún sitio: hay quien hace cincuenta
/// repeticiones a peso corporal, y un RIR alto en una serie de aproximación es
/// legítimo. Lo que faltaba era que el dedazo típico —un dígito de más al
/// teclear— se viese. En el primer entreno volcado, «12» salió «121» y «127»,
/// y un RIR de 7 salió 70; nada lo dijo ni al escribirlo ni después, y esas
/// dos series solas eran el 38 % del volumen del entreno.
public enum RevisionSerie {

    /// RIR por encima del cual se avisa. Diez repeticiones en reserva ya son
    /// una serie que no entrena nada, así que más arriba no hay nada que
    /// anotar: es un dígito de más.
    public static let rirMaximoPlausible = 10

    /// Cifras sospechosas de una serie, en el orden en que están los campos.
    ///
    /// El umbral de repeticiones es el mismo a partir del cual no se estima
    /// 1RM (`CalculadoraRM.repeticionesMaximasParaEstimar`): por encima, el
    /// número deja de significar lo que parece.
    public static func sospechas(de serie: SerieValor, tipo: TipoRegistro) -> [SospechaSerie] {
        var encontradas: [SospechaSerie] = []

        // Se exige peso > 0 porque sin lastre las repeticiones altas son
        // normales, y en los ejercicios de tiempo el campo no es este.
        if !tipo.esTiempo,
           serie.peso > 0,
           serie.repeticiones > CalculadoraRM.repeticionesMaximasParaEstimar {
            encontradas.append(.repeticiones)
        }

        if let rir = serie.rir, rir > rirMaximoPlausible {
            encontradas.append(.rir)
        }

        return encontradas
    }

    /// Serie marcada como hecha en la que no se anotó nada.
    ///
    /// Peso 0 es legítimo —todo lo que se hace a peso corporal—, pero cero
    /// repeticiones o cero segundos no es una serie: es una casilla marcada por
    /// error. Guardarla no suma volumen, pero sí cuenta como serie del grupo
    /// muscular en el recuento semanal, que es justo lo que no se puede
    /// falsear en silencio.
    public static func estaVacia(_ serie: SerieValor, tipo: TipoRegistro) -> Bool {
        serie.logro(tipo: tipo) <= 0
    }
}
