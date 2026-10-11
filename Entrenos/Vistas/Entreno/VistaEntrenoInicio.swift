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
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .filaDesnuda(arriba: 8, abajo: 8)
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
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Entrenar")
    }

    /// Una rutina, como tarjeta con su botón de empezar.
    ///
    /// Era una fila de lista con una flecha pequeña a la derecha: lo mismo que
    /// un ajuste cualquiera, cuando es la acción con la que arranca todo lo
    /// que hace la app. El disco de play va a la derecha y grande porque es
    /// donde cae el pulgar sosteniendo el móvil con una mano.
    private func filaRutina(_ rutina: Rutina) -> some View {
        Button {
            controlador.empezar(desde: rutina)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(rutina.nombre)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(rutina.resumen)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.tint)
            }
            .tarjeta()
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .filaDesnuda(arriba: 4, abajo: 4)
    }
}
