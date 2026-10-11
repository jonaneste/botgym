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
            ForEach(secciones) { seccion in
                Section {
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
                } header: {
                    Text(seccion.titulo)
                } footer: {
                    if let aviso = seccion.aviso {
                        Text(aviso)
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

    /// Las secciones de la lista: primero los que no tienen grupo, luego las
    /// regiones del cuerpo.
    ///
    /// Los sin clasificar van aparte y arriba porque son los únicos que piden
    /// algo: mientras sigan así, sus series no cuentan para ningún músculo. Y
    /// van en su propia sección y no dentro de una región porque no pertenecen
    /// a ninguna: agrupando solo por región desaparecerían de la biblioteca,
    /// que es justo donde hay que ir a arreglarlos.
    private var secciones: [SeccionEjercicios] {
        let lista = filtrados
        var resultado: [SeccionEjercicios] = []

        let sinGrupo = lista.filter { $0.grupoPrincipal == .sinClasificar }
        if !sinGrupo.isEmpty {
            resultado.append(
                SeccionEjercicios(
                    id: GrupoMuscular.sinClasificar.rawValue,
                    titulo: "Sin clasificar",
                    aviso: "Entraron al importar una rutina y no tienen grupo muscular, así que sus series no cuentan en el recuento semanal. Toca uno para completarlo.",
                    ejercicios: sinGrupo.sorted { $0.nombre < $1.nombre }
                )
            )
        }

        let agrupados = Dictionary(grouping: lista) { $0.grupoPrincipal.region }
        for region in RegionCorporal.allCases {
            guard let deLaRegion = agrupados[region], !deLaRegion.isEmpty else { continue }
            resultado.append(
                SeccionEjercicios(
                    id: region.rawValue,
                    titulo: region.nombre,
                    aviso: nil,
                    ejercicios: deLaRegion.sorted { $0.nombre < $1.nombre }
                )
            )
        }
        return resultado
    }
}

struct SeccionEjercicios: Identifiable {
    let id: String
    let titulo: String
    let aviso: String?
    let ejercicios: [Ejercicio]
}
