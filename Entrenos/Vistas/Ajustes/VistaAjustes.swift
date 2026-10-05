import SwiftUI
import SwiftData

/// Ajustes de la app.
struct VistaAjustes: View {
    @Environment(\.modelContext) private var contexto
    @State private var ajustes: Ajustes?
    @State private var mostrarMancuernas = false

    var body: some View {
        NavigationStack {
            Form {
                if let ajustes {
                    seccionDescanso(ajustes)
                    seccionProgresion(ajustes)
                    seccionObjetivos(ajustes)
                    seccionDatos()
                    seccionAcerca()
                }
            }
            .navigationTitle("Ajustes")
            .onAppear {
                if ajustes == nil { ajustes = Ajustes.cargar(en: contexto) }
            }
            .onDisappear { try? contexto.save() }
            .sheet(isPresented: $mostrarMancuernas) {
                if let ajustes {
                    VistaMancuernas(ajustes: ajustes)
                }
            }
        }
    }

    // MARK: - Secciones

    private func seccionDescanso(_ ajustes: Ajustes) -> some View {
        Section {
            Toggle("Arrancar el descanso al marcar la serie", isOn: Binding(
                get: { ajustes.descansoAutomatico },
                set: { ajustes.descansoAutomatico = $0 }
            ))
            Toggle("Vibrar", isOn: Binding(
                get: { ajustes.vibrarFinDescanso },
                set: { ajustes.vibrarFinDescanso = $0 }
            ))
            Toggle("Notificación al terminar", isOn: Binding(
                get: { ajustes.notificarFinDescanso },
                set: { nuevo in
                    ajustes.notificarFinDescanso = nuevo
                    if nuevo {
                        Task { await GestorNotificaciones.shared.solicitarPermiso() }
                    }
                }
            ))

            VStack(alignment: .leading, spacing: 8) {
                Text("Descanso por defecto")
                    .font(.subheadline)
                SelectorDescanso(segundos: Binding(
                    get: { ajustes.descansoPorDefecto },
                    set: { ajustes.descansoPorDefecto = $0 }
                ))
            }
        } header: {
            Text("Descanso")
        } footer: {
            Text("La notificación avisa aunque tengas el móvil bloqueado o la app en segundo plano.")
        }
    }

    private func seccionProgresion(_ ajustes: Ajustes) -> some View {
        Section {
            filaIncremento("Barra", Binding(
                get: { ajustes.incrementoBarra },
                set: { ajustes.incrementoBarra = $0 }
            ))
            filaIncremento("Polea", Binding(
                get: { ajustes.incrementoPolea },
                set: { ajustes.incrementoPolea = $0 }
            ))
            filaIncremento("Máquina", Binding(
                get: { ajustes.incrementoMaquina },
                set: { ajustes.incrementoMaquina = $0 }
            ))

            Stepper(
                "Isométricos: +\(ajustes.incrementoTiempo) s",
                value: Binding(
                    get: { ajustes.incrementoTiempo },
                    set: { ajustes.incrementoTiempo = $0 }
                ),
                in: 1...30
            )

            Button {
                mostrarMancuernas = true
            } label: {
                HStack {
                    Text("Mancuernas disponibles")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(ajustes.mancuernasDisponibles.count)")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text("Incrementos de carga")
        } footer: {
            Text("Cuánto sube la sugerencia de peso cuando completas todas las series en el tope del rango. Las mancuernas saltan al siguiente par que tengas en el gimnasio.")
        }
    }

    private func seccionObjetivos(_ ajustes: Ajustes) -> some View {
        Section {
            Stepper(
                "RIR mínimo: \(ajustes.rirPorDefectoMin)",
                value: Binding(
                    get: { ajustes.rirPorDefectoMin },
                    set: { ajustes.rirPorDefectoMin = min($0, ajustes.rirPorDefectoMax) }
                ),
                in: 0...5
            )
            Stepper(
                "RIR máximo: \(ajustes.rirPorDefectoMax)",
                value: Binding(
                    get: { ajustes.rirPorDefectoMax },
                    set: { ajustes.rirPorDefectoMax = max($0, ajustes.rirPorDefectoMin) }
                ),
                in: 0...5
            )
        } header: {
            Text("RIR por defecto")
        } footer: {
            Text("Se aplica a los ejercicios nuevos y a los que la rutina no fija un RIR propio.")
        }
    }

    private func seccionDatos() -> some View {
        Section {
            NavigationLink {
                VistaBibliotecaEjercicios()
            } label: {
                Label("Biblioteca de ejercicios", systemImage: "dumbbell")
            }
            NavigationLink {
                VistaDatos()
            } label: {
                Label("Exportar, importar y Salud", systemImage: "arrow.up.arrow.down.circle")
            }
        } header: {
            Text("Datos")
        } footer: {
            Text("Exportar el historial a JSON o CSV, importar rutinas desde JSON y conectar con Apple Salud.")
        }
    }

    private func seccionAcerca() -> some View {
        Section("Acerca de") {
            HStack {
                Text("Versión")
                Spacer()
                Text(versionApp)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var versionApp: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func filaIncremento(_ titulo: String, _ valor: Binding<Double>) -> some View {
        HStack {
            Text(titulo)
            Spacer()
            CampoDecimal(marcador: "kg", valor: valor)
                .frame(width: 70)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 8))
            Text("kg")
                .foregroundStyle(.secondary)
        }
    }
}

/// Edita el juego de mancuernas disponible.
struct VistaMancuernas: View {
    let ajustes: Ajustes

    @Environment(\.dismiss) private var cerrar
    @State private var nuevoPeso: Double = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        CampoDecimal(marcador: "kg", valor: $nuevoPeso)
                            .frame(width: 80)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 8))
                        Spacer()
                        Button("Añadir") { añadir() }
                            .buttonStyle(.borderedProminent)
                            .disabled(nuevoPeso <= 0)
                    }
                } footer: {
                    Text("La progresión en mancuernas salta al siguiente peso de esta lista.")
                }

                Section("Disponibles") {
                    ForEach(ajustes.mancuernasDisponibles, id: \.self) { peso in
                        Text(Formato.peso(peso))
                            .font(.system(.body, design: .rounded))
                    }
                    .onDelete(perform: borrar)
                }
            }
            .navigationTitle("Mancuernas")
            .navigationBarTitleDisplayMode(.inline)
            .conBotonHecho()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Hecho") { cerrar() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func añadir() {
        guard nuevoPeso > 0, !ajustes.mancuernasDisponibles.contains(nuevoPeso) else { return }
        ajustes.mancuernasDisponibles = (ajustes.mancuernasDisponibles + [nuevoPeso]).sorted()
        nuevoPeso = 0
    }

    private func borrar(_ indices: IndexSet) {
        var lista = ajustes.mancuernasDisponibles
        lista.remove(atOffsets: indices)
        ajustes.mancuernasDisponibles = lista
    }
}
