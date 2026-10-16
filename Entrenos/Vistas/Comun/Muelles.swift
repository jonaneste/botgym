import SwiftUI

/// Los muelles de la app, en un solo sitio.
///
/// Apple describe el movimiento de sus interfaces con dos parámetros y no con
/// una duración: **respuesta**, lo rápido que llega al destino, y
/// **amortiguación**, cuánto se pasa de frenada. Una animación con duración
/// fija no se puede interrumpir bien; un muelle sí, porque al cambiar el
/// destino sigue desde donde está y con la velocidad que llevaba.
///
/// Dos muelles bastan, y la diferencia entre ellos significa algo:
///
/// - `firme` no rebota. Es lo que se usa en todo lo que cambia sin que el
///   dedo haya empujado nada: una cifra que sube, una fila que se tiñe.
/// - `elastico` rebota un poco, y **solo** se usa cuando el gesto traía
///   impulso o cuando algo aparece de golpe y queremos que se note. Un rebote
///   en algo que simplemente apareció se lee como un adorno.
///
/// Los valores son los que Apple publica para mover (1,0 / 0,4) y para hojas
/// y cajones (0,8 / 0,3).
enum Muelles {
    static let firme = Animation.spring(response: 0.4, dampingFraction: 1.0)
    static let elastico = Animation.spring(response: 0.3, dampingFraction: 0.8)
    /// Para cifras que ruedan: más corto, porque acompaña a un toque.
    static let cifra = Animation.spring(response: 0.25, dampingFraction: 1.0)
}

extension View {
    /// Anima con el muelle que toque, respetando «Reducir movimiento».
    ///
    /// Reducir movimiento no significa quitar el aviso: significa cambiar el
    /// desplazamiento por un fundido. Por eso aquí no se devuelve `nil` sin
    /// más, se devuelve una transición de opacidad corta.
    func animacion<V: Equatable>(_ muelle: Animation, value: V) -> some View {
        modifier(AnimacionRespetuosa(muelle: muelle, value: value))
    }
}

private struct AnimacionRespetuosa<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    let muelle: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(
            reducirMovimiento ? .easeOut(duration: 0.15) : muelle,
            value: value
        )
    }
}

/// Botón que responde al pulsar, no al soltar.
///
/// Es la diferencia entre una interfaz que parece viva y una que parece
/// muerta: el aviso de que algo se ha tocado tiene que salir en el instante
/// del dedo abajo, no al levantarlo. `.buttonStyle(.plain)`, que es lo que
/// usan las tarjetas de esta app, no da ninguno.
///
/// El cambio es pequeño a propósito —un 3 %— y vuelve con el muelle firme:
/// lo que se quiere es notarlo, no ver una animación.
struct BotonPulsable: ButtonStyle {
    var escala: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? escala : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animacion(Muelles.firme, value: configuration.isPressed)
    }
}
