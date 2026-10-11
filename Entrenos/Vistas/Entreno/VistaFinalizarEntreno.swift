import SwiftUI
import SwiftData

/// Pantalla de cierre del entreno: resumen, molestia articular y notas.
struct VistaFinalizarEntreno: View {
    let entreno: Entreno
    let ajustes: Ajustes

    @Environment(ControladorEntreno.self) private var controlador
    @Environment(\.dismiss) private var cerrar

    @State private var anotarHombro = false
    @State private var anotarRodilla = false
    @State private var molestiaHombro: Double = 0
    @State private var molestiaRodilla: Double = 0
    @State private var notas = ""
    @State private var recordsVolumen: [RecordDeEjercicio] = []

    var body: some View {
        NavigationStack {
            Form {
                // Es la última pantalla del entreno, y la última impresión es
                // la que queda. Las cuatro cifras van grandes y juntas, como un
                // marcador, en vez de cuatro filas de etiqueta y valor donde la
                // etiqueta pesaba más que el número.
                Section {
                    VStack(spacing: 14) {
                        Text("Entreno terminado")
                            .font(.headline)
                        HStack(spacing: 0) {
                            CifraDestacada(
                                valor: Formato.duracionLarga(entreno.duracion),
                                etiqueta: "Duración"
                            )
                            Divider().frame(height: 28)
                            CifraDestacada(
                                valor: "\(entreno.seriesCompletadas)",
                                etiqueta: entreno.seriesCompletadas == 1 ? "Serie" : "Series",
                                color: Paleta.logrado
                            )
                        }
                        HStack(spacing: 0) {
                            CifraDestacada(
                                valor: Formato.volumen(entreno.volumenTotal),
                                etiqueta: "Volumen"
                            )
                            Divider().frame(height: 28)
                            CifraDestacada(
                                valor: "\(entreno.ejercicios.count)",
                                etiqueta: entreno.ejercicios.count == 1 ? "Ejercicio" : "Ejercicios"
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                }

                if !todosLosRecords.isEmpty {
                    Section {
                        ForEach(todosLosRecords) { entrada in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "trophy.fill")
                                    .font(.title3)
                                    .foregroundStyle(Paleta.record)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entrada.nombreEjercicio)
                                        .font(.subheadline.weight(.semibold))
                                    Text(textoRecord(entrada.batido))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .listRowBackground(Paleta.record.opacity(0.12))
                    } header: {
                        Label(
                            todosLosRecords.count == 1 ? "Récord batido" : "Récords batidos",
                            systemImage: "sparkles"
                        )
                        .foregroundStyle(Paleta.record)
                        .textCase(nil)
                        .font(.subheadline.weight(.semibold))
                    }
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
                            notas: notas,
                            ajustes: ajustes
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
            .onAppear {
                notas = entreno.notas
                recordsVolumen = controlador.recordsDeVolumen()
            }
        }
    }

    /// Los de serie, detectados durante el entreno, más los de volumen, que
    /// solo se pueden saber ahora.
    private var todosLosRecords: [RecordDeEjercicio] {
        controlador.resumenRecords + recordsVolumen
    }

    private func textoRecord(_ batido: RecordBatido) -> String {
        let valor: String
        switch batido.tipo {
        case .peso, .unRM: valor = Formato.peso(batido.valor)
        case .volumenSesion: valor = Formato.volumen(batido.valor)
        case .tiempo: valor = "\(Int(batido.valor)) s"
        }
        guard let anterior = batido.anterior else {
            return "\(batido.tipo.nombre): \(valor) — el primero"
        }
        let textoAnterior: String
        switch batido.tipo {
        case .peso, .unRM: textoAnterior = Formato.peso(anterior)
        case .volumenSesion: textoAnterior = Formato.volumen(anterior)
        case .tiempo: textoAnterior = "\(Int(anterior)) s"
        }
        return "\(batido.tipo.nombre): \(valor), antes \(textoAnterior)"
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
