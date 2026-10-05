import SwiftUI
import SwiftData

/// Configura el objetivo de series semanales por grupo muscular.
struct VistaObjetivosSemanales: View {
    @Environment(\.modelContext) private var contexto
    @State private var ajustes: Ajustes?
    @State private var objetivos: [GrupoMuscular: Int] = [:]

    var body: some View {
        List {
            Section {
                Text("Series semanales que quieres hacer de cada grupo. Déjalo en 0 para no seguir ese grupo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(RegionCorporal.allCases, id: \.self) { region in
                Section(region.nombre) {
                    ForEach(gruposDe(region), id: \.self) { grupo in
                        Stepper(
                            value: Binding(
                                get: { objetivos[grupo] ?? 0 },
                                set: { nuevo in
                                    if nuevo <= 0 {
                                        objetivos[grupo] = nil
                                    } else {
                                        objetivos[grupo] = nuevo
                                    }
                                    guardar()
                                }
                            ),
                            in: 0...40
                        ) {
                            HStack {
                                Text(grupo.nombre)
                                Spacer()
                                Text(objetivos[grupo].map { "\($0)" } ?? "—")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                    .foregroundStyle(objetivos[grupo] == nil ? .secondary : .primary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }

            Section {
                Button("Aplicar un plan de hipertrofia (10-16 por grupo)") {
                    aplicarPlanSugerido()
                }
                Button("Quitar todos los objetivos", role: .destructive) {
                    objetivos = [:]
                    guardar()
                }
            } footer: {
                Text("El plan sugerido reparte entre 10 y 16 series semanales por grupo grande, que es el rango habitual para ganar masa, y menos en los pequeños.")
            }
        }
        .navigationTitle("Objetivos semanales")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let cargados = ajustes ?? Ajustes.cargar(en: contexto)
            ajustes = cargados
            objetivos = cargados.objetivosSemanales
        }
    }

    private func gruposDe(_ region: RegionCorporal) -> [GrupoMuscular] {
        GrupoMuscular.allCases.filter { $0.region == region }
    }

    private func aplicarPlanSugerido() {
        objetivos = [
            .pecho: 12, .espalda: 12, .dorsal: 12,
            .cuadriceps: 12, .isquios: 10, .gluteo: 10,
            .hombroLateral: 12, .hombroPosterior: 10, .hombroAnterior: 6,
            .biceps: 10, .triceps: 10,
            .gemelo: 8, .core: 6, .trapecio: 6, .lumbar: 4, .antebrazo: 4,
        ]
        guardar()
    }

    private func guardar() {
        ajustes?.objetivosSemanales = objetivos
        try? contexto.save()
    }
}
