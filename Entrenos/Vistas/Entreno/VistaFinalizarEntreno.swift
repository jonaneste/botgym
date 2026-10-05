import SwiftUI
import SwiftData

/// Pantalla de cierre del entreno: resumen, molestia articular y notas.
struct VistaFinalizarEntreno: View {
    let entreno: Entreno

    @Environment(ControladorEntreno.self) private var controlador
    @Environment(\.dismiss) private var cerrar

    @State private var anotarHombro = false
    @State private var anotarRodilla = false
    @State private var molestiaHombro: Double = 0
    @State private var molestiaRodilla: Double = 0
    @State private var notas = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Resumen") {
                    filaResumen("Duración", Formato.duracionLarga(entreno.duracion), "stopwatch")
                    filaResumen("Series completadas", "\(entreno.seriesCompletadas)", "checklist")
                    filaResumen("Volumen total", Formato.volumen(entreno.volumenTotal), "scalemass")
                    filaResumen("Ejercicios", "\(entreno.ejercicios.count)", "figure.strengthtraining.traditional")
                }

                Section {
                    Toggle("Anotar molestia de hombro", isOn: $anotarHombro)
                    if anotarHombro {
                        deslizadorMolestia(valor: $molestiaHombro, etiqueta: "Hombro")
                    }
                    Toggle("Anotar molestia de rodilla", isOn: $anotarRodilla)
                    if anotarRodilla {
                        deslizadorMolestia(valor: $molestiaRodilla, etiqueta: "Rodilla")
                    }
                } header: {
                    Text("Molestia articular")
                } footer: {
                    Text("De 0 (nada) a 10 (muy fuerte). Opcional: si no la anotas, no se guarda nada.")
                }

                Section("Notas del entreno") {
                    TextField("Cómo ha ido, sensaciones, lo que sea", text: $notas, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    Button {
                        controlador.finalizar(
                            molestiaHombro: anotarHombro ? Int(molestiaHombro) : nil,
                            molestiaRodilla: anotarRodilla ? Int(molestiaRodilla) : nil,
                            notas: notas
                        )
                        cerrar()
                    } label: {
                        Text("Guardar entreno")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Terminar entreno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { cerrar() }
                }
            }
            .onAppear { notas = entreno.notas }
        }
    }

    private func filaResumen(_ titulo: String, _ valor: String, _ icono: String) -> some View {
        HStack {
            Label(titulo, systemImage: icono)
            Spacer()
            Text(valor)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func deslizadorMolestia(valor: Binding<Double>, etiqueta: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(etiqueta)
                Spacer()
                Text("\(Int(valor.wrappedValue))")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(colorMolestia(valor.wrappedValue))
                    .monospacedDigit()
            }
            Slider(value: valor, in: 0...10, step: 1)
                .tint(colorMolestia(valor.wrappedValue))
        }
    }

    private func colorMolestia(_ valor: Double) -> Color {
        switch valor {
        case 0..<3: return .green
        case 3..<6: return .yellow
        case 6..<8: return .orange
        default: return .red
        }
    }
}
