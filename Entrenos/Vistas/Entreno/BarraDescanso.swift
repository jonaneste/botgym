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
        VStack(spacing: 12) {
            // La cuenta atrás ocupa el centro y a cuerpo grande: es lo único
            // que se mira desde lejos, con el móvil en el banco y a dos metros
            // de la cara. Antes iba a un lado, al mismo peso que la palabra
            // «Descanso», que no hace falta leer dos veces.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Descanso")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text(Formato.cuentaAtras(controlador.temporizador.restante))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(seAcaba ? Paleta.aviso : .primary)
                Spacer()
                // Hueco simétrico al de la etiqueta, para que el número quede
                // centrado de verdad y no salte al cambiar de dos a un dígito.
                Text("Descanso")
                    .font(.footnote.weight(.medium))
                    .textCase(.uppercase)
                    .hidden()
            }

            ProgressView(value: controlador.temporizador.progreso)
                .tint(seAcaba ? Paleta.aviso : .accentColor)

            HStack(spacing: 10) {
                Button {
                    controlador.ajustarDescanso(segundos: -15, ajustes: ajustes)
                } label: {
                    Text("−15 s").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    controlador.ajustarDescanso(segundos: 15, ajustes: ajustes)
                } label: {
                    Text("+15 s").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    controlador.saltarDescanso()
                } label: {
                    Text("Saltar").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    /// Los últimos diez segundos. Cambia el color para avisar sin sonido, que
    /// en un gimnasio con música no siempre se oye la notificación.
    private var seAcaba: Bool {
        controlador.temporizador.restante <= 10
    }
}
