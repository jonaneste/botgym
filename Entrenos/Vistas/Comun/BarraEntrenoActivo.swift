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

    var body: some View {
        if let entreno = controlador.entreno {
            Button(action: alTocar) {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    HStack(spacing: 12) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.title3)
                            .foregroundStyle(.tint)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(entreno.nombre)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                            Text("\(entreno.seriesCompletadas) series · \(Formato.volumen(entreno.volumenTotal))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

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

                        Image(systemName: "chevron.up")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: .rect(cornerRadius: 14))
                    // Un filo de acento: dice de qué va la barra sin apoyar
                    // texto encima del color.
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
