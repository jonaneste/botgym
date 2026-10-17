import SwiftUI

/// Barra flotante que avisa de que hay un entreno en curso.
///
/// Va sobre material y no sobre el verde de acento, aunque el verde llamara
/// más. En modo oscuro el acento es un verde claro (#28AF55) y el texto
/// blanco encima daba 2,9:1, cuando el texto pequeño necesita 4,5:1: la línea
/// de series y volumen, que va a cuerpo `caption2`, no se leía. Sobre material
/// el texto es la etiqueta del sistema, que cumple en los dos modos, y el
/// acento se queda donde sí contrasta: el icono y el cronómetro.
struct BarraEntrenoActivo: View {
    let alTocar: () -> Void

    @Environment(ControladorEntreno.self) private var controlador
    @Environment(\.dynamicTypeSize) private var tamañoTexto

    var body: some View {
        if let entreno = controlador.entreno {
            Button(action: alTocar) {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    contenido(entreno)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: .rect(cornerRadius: 14))
                    // Un filo de acento: dice de qué va la barra sin apoyar
                    // texto encima del color.
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Paleta.acento.opacity(0.4), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }
            }
            .buttonStyle(.plain)
        }
    }

    /// Con el texto de accesibilidad se queda lo imprescindible.
    ///
    /// Esta barra vive en `tabViewBottomAccessory`, un hueco de alto fijo que
    /// decide el sistema: crecer no es una opción, se corta por arriba y por
    /// abajo. Así que a esos cuerpos no se reparte en dos filas, se quita lo
    /// que sobra. Queda el nombre del entreno y el reloj, que es a lo que se
    /// mira; las series y el volumen están a un toque, dentro del entreno, y
    /// el galón se va porque la barra entera ya es el botón.
    ///
    /// Antes se apretaba todo en la misma fila y el cronómetro acababa en
    /// «1:…», que es justo lo único que no puede faltar.
    @ViewBuilder
    private func contenido(_ entreno: Entreno) -> some View {
        if tamañoTexto.isAccessibilitySize {
            HStack(spacing: 10) {
                nombre(entreno)
                Spacer(minLength: 8)
                // El reloj entero o nada: es lo único que se mira de esta
                // barra, y recortado en «4:35:…» no sirve. Lo que cede es el
                // nombre, que además está escrito en la pantalla de al lado.
                reloj(entreno)
                    .fixedSize()
                    .layoutPriority(1)
            }
        } else {
            HStack(spacing: 12) {
                icono
                VStack(alignment: .leading, spacing: 1) {
                    nombre(entreno)
                    resumen(entreno)
                }
                Spacer()
                reloj(entreno)
                galon
            }
        }
    }

    private var icono: some View {
        Image(systemName: "figure.strengthtraining.traditional")
            .font(.title3)
            .foregroundStyle(.tint)
    }

    private func nombre(_ entreno: Entreno) -> some View {
        Text(entreno.nombre)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(.primary)
            // La barra no puede crecer ni a lo ancho ni a lo alto, así que el
            // nombre se encoge antes que quedarse en «Lunes –...».
            .minimumScaleFactor(0.6)
    }

    private func resumen(_ entreno: Entreno) -> some View {
        Text("\(Formato.cuenta(entreno.seriesCompletadas, "serie", "series")) · \(Formato.volumen(entreno.volumenTotal))")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func reloj(_ entreno: Entreno) -> some View {
        if controlador.temporizador.activo {
            Text(Formato.cuentaAtras(controlador.temporizador.restante))
                .font(.system(.body, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.tint)
        } else {
            Text(Formato.cronometro(entreno.duracion))
                .font(.system(.body, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }

    private var galon: some View {
        Image(systemName: "chevron.up")
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
    }
}
