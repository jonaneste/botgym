import SwiftUI
import SwiftData

/// Anotar una carrera a mano.
///
/// Existe porque con un Apple ID gratuito puede que no llegue ninguna carrera
/// desde Salud, y sin esto un plan de 180 km no tenía dónde registrarse.
struct VistaAnotarCarreraManual: View {
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar

    /// Kilómetros sugeridos, cuando se abre desde un día del plan.
    var kilometrosSugeridos: Double?

    @State private var fecha = Date()
    @State private var kilometros: Double = 0
    @State private var minutos: Double = 0
    @State private var pulso: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Cuándo", selection: $fecha)
                }

                Section {
                    filaNumero("Kilómetros", valor: $kilometros, marcador: "km")
                    filaNumero("Minutos", valor: $minutos, marcador: "min")
                } footer: {
                    if let ritmo {
                        Text("Ritmo: \(ritmo)")
                            .foregroundStyle(Paleta.carrera)
                    } else {
                        Text("Con la distancia y el tiempo sale el ritmo solo.")
                    }
                }

                Section {
                    filaNumero("Pulso medio", valor: $pulso, marcador: "ppm")
                } footer: {
                    Text("Opcional. Déjalo en blanco si no lo sabes: no se inventa.")
                }

                Section {
                    Button {
                        RepositorioCarreras(contexto: contexto).anotar(
                            fecha: fecha,
                            kilometros: kilometros,
                            minutos: minutos,
                            pulsoMedio: pulso > 0 ? pulso : nil
                        )
                        cerrar()
                    } label: {
                        Text("Guardar carrera")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Paleta.carrera)
                    .disabled(kilometros <= 0)
                } footer: {
                    Text("Si luego llega la misma carrera desde Salud, manda la medida: tiene el ritmo y el pulso de verdad. Esta se queda guardada igualmente.")
                }
            }
            .navigationTitle("Anotar carrera")
            .navigationBarTitleDisplayMode(.inline)
            .conBotonHecho()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { cerrar() }
                }
            }
            .onAppear {
                if kilometros == 0, let kilometrosSugeridos {
                    kilometros = kilometrosSugeridos
                }
            }
        }
    }

    private func filaNumero(_ titulo: String, valor: Binding<Double>, marcador: String) -> some View {
        HStack {
            Text(titulo)
            Spacer()
            CampoDecimal(marcador: marcador, valor: valor)
                .frame(maxWidth: 110)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 8))
        }
    }

    /// El ritmo mientras se escribe, para no tener que guardar y volver.
    private var ritmo: String? {
        guard kilometros > 0, minutos > 0 else { return nil }
        let carrera = Carrera(
            id: "previsualizacion",
            fechaInicio: fecha,
            duracion: minutos * 60,
            distanciaMetros: kilometros * 1_000
        )
        return carrera.ritmoTexto
    }
}
