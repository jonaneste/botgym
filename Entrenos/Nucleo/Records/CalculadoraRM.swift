import Foundation

/// Estimación de 1RM.
///
/// Se usa Epley, que es la que pidió el usuario:
///
///     1RM = peso × (1 + reps / 30)
///
/// Con una sola repetición la fórmula se cortocircuita y devuelve el propio
/// peso, porque Epley daría peso × 1,033 para un single, que ya es el máximo.
public enum CalculadoraRM {

    /// Repeticiones por encima de las cuales no se estima nada.
    ///
    /// Epley es una recta, y la fuerza real no lo es: la fórmula se ajusta
    /// razonablemente hasta unas diez o quince repeticiones y a partir de ahí
    /// se dispara. A 127 repeticiones da 5,2 veces el peso levantado.
    ///
    /// El tope no es un tecnicismo. Un dedo de más al teclear —«12» que sale
    /// «127»— convertía una serie normal en un récord de 167 kg que ya no se
    /// puede superar nunca, y que ensucia la gráfica del ejercicio para
    /// siempre. Más vale no estimar que estimar un disparate.
    public static let repeticionesMaximasParaEstimar = 20

    /// 1RM estimado por Epley. Devuelve `nil` si los datos no permiten estimar.
    public static func epley(peso: Double, repeticiones: Int) -> Double? {
        guard peso > 0, repeticiones >= 1 else { return nil }
        guard repeticiones <= repeticionesMaximasParaEstimar else { return nil }
        guard repeticiones > 1 else { return peso }
        return peso * (1.0 + Double(repeticiones) / 30.0)
    }

    /// 1RM estimado teniendo en cuenta las repeticiones en reserva.
    ///
    /// Una serie de 8 con RIR 2 se comporta, de cara al máximo, como una serie
    /// de 10 llevada al fallo, así que se suman las reps en reserva antes de
    /// aplicar Epley. Sin RIR anotado equivale a `epley(peso:repeticiones:)`.
    public static func epleyConRIR(peso: Double, repeticiones: Int, rir: Int?) -> Double? {
        let reserva = max(0, rir ?? 0)
        return epley(peso: peso, repeticiones: repeticiones + reserva)
    }

    /// 1RM estimado de una serie, respetando su tipo de registro.
    ///
    /// Los ejercicios de tiempo no tienen 1RM, así que devuelven `nil`.
    public static func epley(serie: SerieValor, tipo: TipoRegistro) -> Double? {
        guard !tipo.esTiempo else { return nil }
        return epley(peso: serie.peso, repeticiones: serie.repeticiones)
    }

    /// Peso estimado para lograr un número concreto de repeticiones, dado un
    /// 1RM. Es Epley despejada, y sirve para sugerir cargas de partida.
    public static func pesoPara(unRM: Double, repeticiones: Int) -> Double? {
        guard unRM > 0, repeticiones >= 1 else { return nil }
        return unRM / (1.0 + Double(repeticiones) / 30.0)
    }
}
