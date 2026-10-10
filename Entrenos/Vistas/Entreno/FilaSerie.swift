import SwiftUI

/// Una fila de serie dentro del entreno en curso.
///
/// Pensada para usarse con una mano y el móvil apoyado: la casilla de
/// completada ocupa toda la altura de la fila por el lado derecho, y el peso de
/// la serie anterior se copia tocando el texto gris de la izquierda.
struct FilaSerie: View {
    let serie: SerieRegistrada
    let ejercicio: EjercicioEntreno
    let serieAnterior: SerieValor?
    let ajustes: Ajustes

    @Environment(ControladorEntreno.self) private var controlador

    private var tipo: TipoRegistro { ejercicio.tipoRegistro }

    var body: some View {
        HStack(spacing: 10) {
            indiceSerie

            VStack(alignment: .leading, spacing: 2) {
                campos
                textoAnterior
            }

            casillaCompletada
        }
        .padding(.vertical, 6)
        .listRowBackground(serie.completada ? Paleta.logrado.opacity(0.12) : nil)
    }

    // MARK: - Piezas

    private var indiceSerie: some View {
        Group {
            if serie.esCalentamiento {
                Image(systemName: "flame")
                    .foregroundStyle(Paleta.calentamiento)
            } else {
                Text("\(numeroSerieEfectiva)")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 26)
    }

    /// Número que se muestra: las de calentamiento no cuentan.
    private var numeroSerieEfectiva: Int {
        let previas = ejercicio.seriesOrdenadas
            .prefix(while: { $0.orden < serie.orden })
            .filter { !$0.esCalentamiento }
            .count
        return previas + 1
    }

    private var campos: some View {
        HStack(spacing: 8) {
            // Peso
            CampoDecimal(marcador: "kg", valor: Binding(
                get: { serie.peso },
                set: { serie.peso = $0 }
            ))
            .frame(minWidth: 62)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))

            Text("×")
                .foregroundStyle(.secondary)

            // Repeticiones o segundos
            if tipo.esTiempo {
                CampoEntero(marcador: "s", valor: Binding(
                    get: { serie.segundos ?? 0 },
                    set: { serie.segundos = $0 }
                ))
                .frame(minWidth: 56)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))
            } else {
                CampoEntero(marcador: "reps", valor: Binding(
                    get: { serie.repeticiones },
                    set: { serie.repeticiones = $0 }
                ))
                .frame(minWidth: 56)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))
            }

            // RIR
            CampoEnteroOpcional(marcador: "RIR", valor: Binding(
                get: { serie.rir },
                set: { serie.rir = $0 }
            ))
            .frame(minWidth: 46)
            .padding(.vertical, 8)
            .background(Color(.quaternarySystemFill), in: .rect(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private var textoAnterior: some View {
        if let serieAnterior {
            Button {
                controlador.copiarDeAnterior(serie, de: ejercicio)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.down")
                        .font(.caption2)
                    Text("Anterior: \(Formato.resumenSerie(peso: serieAnterior.peso, repeticiones: serieAnterior.repeticiones, segundos: serieAnterior.segundos, tipo: tipo))")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Copia el peso y las repeticiones de la última vez")
        } else {
            Text("Primera vez con este ejercicio")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        }
    }

    private var casillaCompletada: some View {
        Button {
            controlador.alternarCompletada(serie, de: ejercicio, ajustes: ajustes)
        } label: {
            Image(systemName: serie.completada ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 30))
                .foregroundStyle(serie.completada ? Paleta.logrado : Color.secondary)
                .frame(width: 48, height: 48)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(serie.completada ? "Serie completada" : "Marcar serie como completada")
    }
}
