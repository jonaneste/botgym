import Foundation

/// Topes de lo que se puede escribir en un campo numérico, y conversiones que
/// no revientan.
///
/// `Int(_: Double)` **atrapa en tiempo de ejecución** si el valor no cabe en
/// `Int64` o no es finito, y en Swift una trampa es un cierre inmediato de la
/// app, no una excepción que se pueda capturar. Con los pesos y las
/// repeticiones llegando de un campo de texto, eso es alcanzable: el teclado
/// decimal no impide pegar, ni dictar, ni teclear veinte dígitos.
///
/// Un peso imposible guardado una vez no rompía solo la pantalla donde se
/// escribió: dejaba la app cerrándose cada vez que se construía la sugerencia
/// de ese ejercicio, y con un infinito el JSON de exportación fallaba para
/// siempre, porque `JSONEncoder` rechaza los no finitos y no había ninguna
/// forma de encontrar la serie culpable desde la interfaz.
public enum LimitesEntrada {

    /// Peso máximo de una serie, en kg. Con holgura sobre cualquier récord
    /// humano, que es lo que tiene que ser un tope de cordura.
    public static let pesoMaximo: Double = 1_000

    /// Tope de repeticiones y de segundos. 99.999 s son más de 27 horas.
    public static let enteroMaximo = 99_999

    /// Peso utilizable: no finito pasa a 0, y se recorta al rango admitido.
    public static func peso(_ valor: Double) -> Double {
        guard valor.isFinite else { return 0 }
        return min(max(valor, 0), pesoMaximo)
    }

    /// Entero recortado al rango admitido. Se llama distinto que `entero(_:)`
    /// a propósito: dos sobrecargas que solo difieren en `Int` frente a
    /// `Double` se resuelven de forma sorprendente con literales.
    public static func recortar(_ valor: Int) -> Int {
        min(max(valor, 0), enteroMaximo)
    }

    /// Conversión a `Int` que nunca atrapa.
    ///
    /// Se usa en lugar de `Int(valor)` en todo lo que se pinta o se exporta: el
    /// volumen de un entreno es peso × repeticiones, así que hereda cualquier
    /// valor absurdo que se haya colado en una serie.
    public static func entero(_ valor: Double) -> Int {
        guard valor.isFinite else { return 0 }
        let redondeado = valor.rounded()
        // El margen está muy por debajo de Int64.max (≈9,22e18) a propósito:
        // un Double de esa magnitud ya no representa enteros consecutivos, así
        // que no hay nada que ganar acercándose al límite exacto.
        return Int(min(max(redondeado, -1e15), 1e15))
    }
}
