import SwiftUI

/// Barra de descanso, fija en la parte baja para alcanzarla con el pulgar.
struct BarraDescanso: View {
    @Environment(ControladorEntreno.self) private var controlador
    let ajustes: Ajustes

    var body: some View {
        // TimelineView redibuja cada segundo sin tener que gestionar un Timer,
        // y se comporta bien al volver del segundo plano.
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            contenido
        }
    }

    private var contenido: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Descanso")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Formato.cuentaAtras(controlador.temporizador.restante))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            ProgressView(value: controlador.temporizador.progreso)
                .tint(.accentColor)

            HStack(spacing: 10) {
                Button("−15 s") {
                    controlador.ajustarDescanso(segundos: -15, ajustes: ajustes)
                }
                .buttonStyle(.bordered)

                Button("+15 s") {
                    controlador.ajustarDescanso(segundos: 15, ajustes: ajustes)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Saltar") {
                    controlador.saltarDescanso()
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
        .padding(16)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
