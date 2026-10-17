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
                    .buttonStyle(BotonPulsable())
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
        // Cada filtro lleva el color de su región, apagado mientras no está
        // elegido: así la tira de filtros es también la leyenda de los colores
        // que luego se ven en las filas.
        let color = grupo.map(Paleta.grupo) ?? Paleta.acento
        // Elegido, el texto va en blanco sobre el color lleno; sin elegir, va
        // sobre ese color al 14 %, y ahí el del sistema no contrasta en claro.
        let colorTexto = grupo.map(Paleta.grupoTexto) ?? Paleta.acento
        return Button {
            grupoFiltro = grupo
        } label: {
            Text(texto)
                .font(.subheadline.weight(activo ? .semibold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(activo ? color : color.opacity(0.14), in: .capsule)
                .foregroundStyle(activo ? Color.white : colorTexto)
        }
        .buttonStyle(.plain)
    }
}

/// Fila de la biblioteca: nombre, grupo y material.
struct FilaEjercicio: View {
    let ejercicio: Ejercicio

    /// Para el icono sobre su propio relleno: ahí es un color, no un texto.
    private var color: Color { Paleta.grupo(ejercicio.grupoPrincipal) }

    /// Para el nombre del grupo, que sí es texto y pide más contraste.
    private var colorTexto: Color { Paleta.grupoTexto(ejercicio.grupoPrincipal) }

    var body: some View {
        HStack(spacing: 12) {
            // El icono del material sobre el color de su región. Antes todos
            // eran del mismo azul de acento, así que una lista de cincuenta
            // ejercicios era cincuenta filas idénticas: el color es lo que
            // permite encontrar «el de pierna» sin leer.
            Image(systemName: ejercicio.material.icono)
                .font(.system(size: 16, weight: .semibold))
                // Sobre su propio color al 16 %, el del sistema desaparece en
                // claro igual que el texto.
                .foregroundStyle(colorTexto)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.16), in: .rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(ejercicio.nombre)
                    .font(.body)
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Text(ejercicio.grupoPrincipal.nombre)
                        .foregroundStyle(colorTexto)
                        .fontWeight(.medium)
                    Text("·")
                    Text(ejercicio.material.nombre.lowercased())
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
