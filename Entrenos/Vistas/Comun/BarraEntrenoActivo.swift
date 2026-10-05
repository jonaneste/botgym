import SwiftUI

/// Barra flotante que avisa de que hay un entreno en curso.
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
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(entreno.nombre)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text("\(entreno.seriesCompletadas) series · \(Formato.volumen(entreno.volumenTotal))")
                                .font(.caption2)
                                .opacity(0.85)
                        }
                        .foregroundStyle(.white)

                        Spacer()

                        if controlador.temporizador.activo {
                            Text(Formato.cuentaAtras(controlador.temporizador.restante))
                                .font(.system(.body, design: .rounded, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        } else {
                            Text(Formato.cronometro(entreno.duracion))
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        }

                        Image(systemName: "chevron.up")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.accentColor, in: .rect(cornerRadius: 14))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
