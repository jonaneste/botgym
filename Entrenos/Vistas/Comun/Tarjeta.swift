import SwiftUI

/// El aspecto de tarjeta que comparten las pantallas de entreno.
///
/// La app era cinco pestañas de `List` agrupada: la apariencia por defecto de
/// una pantalla de ajustes. Funcionaba, pero todo pesaba visualmente lo mismo
/// y nada decía qué mirar primero. Esto no cambia la estructura —las filas
/// siguen siendo filas de `List`, porque de ahí salen los gestos de deslizar—
/// sino el revestimiento: fondo propio, aire dentro y una sombra tenue que
/// separa la tarjeta del fondo sin ensuciarla.
///
/// La sombra es negra al 8 %, no gris: una sombra gris sobre fondo de color se
/// ve sucia, y sobre el fondo oscuro del sistema no se ve en absoluto.
struct FondoTarjeta: ViewModifier {
    var relleno: CGFloat = 16
    var radio: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(relleno)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: radio))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }
}

extension View {
    func tarjeta(relleno: CGFloat = 16, radio: CGFloat = 16) -> some View {
        modifier(FondoTarjeta(relleno: relleno, radio: radio))
    }

    /// Deja una fila de `List` sin fondo ni separador para poder vestirla
    /// como tarjeta, conservando `swipeActions`, que solo existen dentro de
    /// una `List`.
    func filaDesnuda(arriba: CGFloat = 6, abajo: CGFloat = 6) -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: arriba, leading: 16, bottom: abajo, trailing: 16))
    }
}

/// Una cifra grande con su etiqueta debajo.
///
/// El orden importa: antes la etiqueta iba arriba a cuerpo `caption2` y el
/// número debajo a `headline`, que es casi el mismo tamaño. Leer «Volumen» más
/// fuerte que «4.250 kg» es justo lo que no se quiere: el dato es el valor, no
/// cómo se llama.
struct CifraDestacada: View {
    let valor: String
    let etiqueta: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 2) {
            Text(valor)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(etiqueta)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(etiqueta)
        .accessibilityValue(valor)
    }
}

/// Etiqueta pequeña de categoría: grupo muscular, material, número de serie.
struct Pastilla: View {
    let texto: String
    var color: Color = .accentColor

    var body: some View {
        Text(texto)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: .capsule)
    }
}
