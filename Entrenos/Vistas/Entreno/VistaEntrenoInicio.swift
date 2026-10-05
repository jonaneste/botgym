import SwiftUI
import SwiftData

/// Pestaña de entreno: reanuda el abierto, o deja empezar uno nuevo.
struct VistaEntrenoInicio: View {
    @Environment(ControladorEntreno.self) private var controlador
    @Environment(\.modelContext) private var contexto

    @Query(sort: \CarpetaRutinas.orden) private var carpetas: [CarpetaRutinas]
    @Query(sort: \Rutina.orden) private var rutinas: [Rutina]

    @State private var ajustes: Ajustes?

    var body: some View {
        NavigationStack {
            Group {
                if let entreno = controlador.entreno, let ajustes {
                    VistaEntrenoEnCurso(entreno: entreno, ajustes: ajustes)
                } else {
                    pantallaInicio
                }
            }
        }
        .onAppear {
            if ajustes == nil { ajustes = Ajustes.cargar(en: contexto) }
            controlador.reanudarSiProcede()
        }
    }

    private var pantallaInicio: some View {
        List {
            Section {
                Button {
                    controlador.empezarVacio()
                } label: {
                    Label("Empezar entreno vacío", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            ForEach(carpetas) { carpeta in
                if !carpeta.rutinas.isEmpty {
                    Section(carpeta.nombre) {
                        ForEach(carpeta.rutinasOrdenadas) { rutina in
                            filaRutina(rutina)
                        }
                    }
                }
            }

            let sueltas = rutinas.filter { $0.carpeta == nil }
            if !sueltas.isEmpty {
                Section("Sin carpeta") {
                    ForEach(sueltas) { rutina in
                        filaRutina(rutina)
                    }
                }
            }

            if carpetas.isEmpty && rutinas.isEmpty {
                ContentUnavailableView(
                    "Sin rutinas",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Ve a la pestaña Rutinas para crear la primera, o empieza un entreno vacío.")
                )
            }
        }
        .navigationTitle("Entrenar")
    }

    private func filaRutina(_ rutina: Rutina) -> some View {
        Button {
            controlador.empezar(desde: rutina)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(rutina.nombre)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(rutina.resumen)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            .padding(.vertical, 6)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
