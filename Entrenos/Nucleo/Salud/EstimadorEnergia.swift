import Foundation

/// Estimación de calorías de un entreno de fuerza.
///
/// Esto existe solo porque Apple Salud pasa a ser el centro de los datos: un
/// entrenamiento sin energía aparece vacío en Fitness y no suma al anillo de
/// movimiento. La estimación es **opcional y está apagada por defecto**: si
/// llevas el reloj puesto, el dato real lo escribe Zepp y no hay que inventar
/// nada.
///
/// Se usa el método MET, que es el estándar:
///
///     kcal = MET × peso corporal (kg) × horas
///
/// El MET del entrenamiento de fuerza tradicional ronda 3,5 con esfuerzo
/// ligero y 6,0 con esfuerzo alto. El valor por defecto, 4,5, corresponde a
/// una sesión de hipertrofia normal con descansos.
public enum EstimadorEnergia {

    /// MET por defecto para entrenamiento de fuerza tradicional.
    public static let metPorDefecto = 4.5

    /// Rango razonable del MET, para acotar el ajuste en la interfaz.
    public static let metMinimo = 2.0
    public static let metMaximo = 8.0

    /// Kilocalorías estimadas.
    ///
    /// Devuelve `nil` si falta algún dato o no tiene sentido estimar: sin peso
    /// corporal la fórmula no se puede aplicar, y es mejor no escribir energía
    /// que escribir un número inventado.
    public static func kilocalorias(
        duracion: TimeInterval,
        pesoCorporal: Double,
        met: Double = EstimadorEnergia.metPorDefecto
    ) -> Double? {
        guard duracion > 0, pesoCorporal > 0, met > 0 else { return nil }
        let horas = duracion / 3600
        let kcal = met * pesoCorporal * horas
        guard kcal.isFinite, kcal > 0 else { return nil }
        // Se redondea a entero: el decimal daría una falsa sensación de
        // precisión en algo que es una estimación.
        return kcal.rounded()
    }

    /// Acota un MET al rango admitido.
    public static func metValido(_ valor: Double) -> Double {
        min(metMaximo, max(metMinimo, valor))
    }
}
