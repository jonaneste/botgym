import SwiftUI
import SwiftData

/// Selector de ejercicio de la biblioteca, con buscador y filtro por grupo.
struct VistaSelectorEjercicio: View {
    let alElegir: (Ejercicio) -> Void

    @Environment(\.dismiss) private var cerrar
    @Environment(\.modelContext) private var contexto
    @Query(sort: \Ejercicio.nombre) private var ejercicios: [Ejercicio]

    @State private var busqueda = ""
    @State private var grupoFiltro: GrupoMuscular?
    @State private var mostrarNuevoEjercicio = false

    var body: some View {
        NavigationStack {
            List {
                if !gruposPresentes.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                botonFiltro(nil, texto: "Todos")
                                ForEach(gruposPresentes, id: \.self) { grupo in
                                    botonFiltro(grupo, texto: grupo.nombre)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                ForEach(filtrados) { ejercicio in
                    Button {
                        alElegir(ejercicio)
                        cerrar()
                    } label: {
                        FilaEjercicio(ejercicio: ejercicio)
                    }
                    .buttonStyle(.plain)
                }

                if filtrados.isEmpty {
                    ContentUnavailableView(
                        "Sin resultados",
                        systemImage: "magnifyingglass",
                        description: Text("Prueba con otro nombre o créalo nuevo.")
                    )
                }
            }
            .searchable(text: $busqueda, prompt: "Buscar ejercicio")
            .navigationTitle("Añadir ejercicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        mostrarNuevoEjercicio = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $mostrarNuevoEjercicio) {
                VistaEditorEjercicio(ejercicio: nil) { nuevo in
                    alElegir(nuevo)
                    cerrar()
                }
            }
        }
    }

    private var gruposPresentes: [GrupoMuscular] {
        let presentes = Set(ejercicios.map(\.grupoPrincipal))
        return GrupoMuscular.allCases.filter { presentes.contains($0) }
    }

    private var filtrados: [Ejercicio] {
        var resultado = ejercicios
        if let grupoFiltro {
            resultado = resultado.filter { $0.grupoPrincipal == grupoFiltro }
        }
        let texto = Ejercicio.normalizar(busqueda)
        if !texto.isEmpty {
            resultado = resultado.filter { $0.nombreNormalizado.contains(texto) }
        }
        return resultado
    }

    private func botonFiltro(_ grupo: GrupoMuscular?, texto: String) -> some View {
        let activo = grupoFiltro == grupo
        return Button {
            grupoFiltro = grupo
        } label: {
            Text(texto)
                .font(.subheadline.weight(activo ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    activo ? Color.accentColor : Color(.secondarySystemFill),
                    in: .capsule
                )
                .foregroundStyle(activo ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

/// Fila de la biblioteca: nombre, grupo y material.
struct FilaEjercicio: View {
    let ejercicio: Ejercicio

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: ejercicio.material.icono)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(ejercicio.nombre)
                    .font(.body)
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Text(ejercicio.descripcionCorta)
                    if ejercicio.tipoRegistro != .repeticiones {
                        Text("·")
                        Text(ejercicio.tipoRegistro.nombre.lowercased())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if ejercicio.esPersonalizado {
                Image(systemName: "person.crop.circle")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
