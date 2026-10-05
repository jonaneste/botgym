import SwiftUI
import SwiftData

/// La biblioteca de ejercicios completa.
struct VistaBibliotecaEjercicios: View {
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Ejercicio.nombre) private var ejercicios: [Ejercicio]

    @State private var busqueda = ""
    @State private var mostrarNuevo = false
    @State private var ejercicioAEditar: Ejercicio?
    @State private var ejercicioABorrar: Ejercicio?

    var body: some View {
        List {
            ForEach(porRegion, id: \.region) { seccion in
                Section(seccion.region.nombre) {
                    ForEach(seccion.ejercicios) { ejercicio in
                        Button {
                            ejercicioAEditar = ejercicio
                        } label: {
                            FilaEjercicio(ejercicio: ejercicio)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                ejercicioABorrar = ejercicio
                            } label: {
                                Label("Borrar", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if ejercicios.isEmpty {
                ContentUnavailableView(
                    "Sin ejercicios",
                    systemImage: "dumbbell",
                    description: Text("Crea el primero con el botón +.")
                )
            }
        }
        .searchable(text: $busqueda, prompt: "Buscar ejercicio")
        .navigationTitle("Ejercicios")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    mostrarNuevo = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $mostrarNuevo) {
            VistaEditorEjercicio(ejercicio: nil)
        }
        .sheet(item: $ejercicioAEditar) { ejercicio in
            VistaEditorEjercicio(ejercicio: ejercicio)
        }
        .alert(
            "¿Borrar ejercicio?",
            isPresented: Binding(
                get: { ejercicioABorrar != nil },
                set: { presentado in if !presentado { ejercicioABorrar = nil } }
            ),
            presenting: ejercicioABorrar
        ) { objetivo in
            Button("Borrar", role: .destructive) {
                contexto.delete(objetivo)
                try? contexto.save()
                ejercicioABorrar = nil
            }
            Button("Cancelar", role: .cancel) { ejercicioABorrar = nil }
        } message: { objetivo in
            Text("Se quita \(objetivo.nombre) de la biblioteca. El historial conserva lo que hiciste: cada entreno guarda una copia del nombre.")
        }
    }

    private var filtrados: [Ejercicio] {
        let texto = Ejercicio.normalizar(busqueda)
        guard !texto.isEmpty else { return ejercicios }
        return ejercicios.filter { $0.nombreNormalizado.contains(texto) }
    }

    private var porRegion: [SeccionRegion] {
        let agrupados = Dictionary(grouping: filtrados) { $0.grupoPrincipal.region }
        return RegionCorporal.allCases.compactMap { region in
            guard let lista = agrupados[region], !lista.isEmpty else { return nil }
            return SeccionRegion(region: region, ejercicios: lista.sorted { $0.nombre < $1.nombre })
        }
    }
}

struct SeccionRegion {
    let region: RegionCorporal
    let ejercicios: [Ejercicio]
}
