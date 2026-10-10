import SwiftUI
import SwiftData

/// Editor de una rutina: ejercicios, objetivos, orden y superseries.
struct VistaEditorRutina: View {
    let rutina: Rutina

    @Environment(\.dismiss) private var cerrar
    @Environment(\.modelContext) private var contexto
    @Query(sort: \CarpetaRutinas.orden) private var carpetas: [CarpetaRutinas]

    @State private var mostrarSelector = false
    @State private var elementoAEditar: ElementoRutina?
    @State private var modoEdicion: EditMode = .inactive

    var body: some View {
        NavigationStack {
            List {
                Section("Nombre") {
                    TextField("Lunes – Empuje", text: Binding(
                        get: { rutina.nombre },
                        set: { rutina.nombre = $0 }
                    ))
                    .font(.body.weight(.medium))
                }

                Section("Carpeta") {
                    Picker("Carpeta", selection: Binding(
                        get: { rutina.carpeta?.idPublico },
                        set: { nuevo in
                            rutina.carpeta = carpetas.first { $0.idPublico == nuevo }
                        }
                    )) {
                        Text("Sin carpeta").tag(UUID?.none)
                        ForEach(carpetas) { carpeta in
                            Text(carpeta.nombre).tag(Optional(carpeta.idPublico))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    ForEach(rutina.elementosOrdenados) { elemento in
                        filaElemento(elemento)
                    }
                    .onMove(perform: mover)
                    .onDelete(perform: borrar)

                    Button {
                        mostrarSelector = true
                    } label: {
                        Label("Añadir ejercicio", systemImage: "plus.circle.fill")
                            .font(.body.weight(.semibold))
                    }
                } header: {
                    HStack {
                        Text("Ejercicios")
                        Spacer()
                        Text(rutina.resumen).foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Arrastra para reordenar. Desliza a la izquierda para borrar. Para crear una superserie, selecciona dos ejercicios consecutivos con «Agrupar en superserie».")
                }

                Section("Notas") {
                    TextField("Notas de la rutina", text: Binding(
                        get: { rutina.notas },
                        set: { rutina.notas = $0 }
                    ), axis: .vertical)
                    .lineLimit(2...6)
                }
            }
            .environment(\.editMode, $modoEdicion)
            .navigationTitle("Editar rutina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(modoEdicion == .active ? "Hecho" : "Reordenar") {
                        withAnimation {
                            modoEdicion = modoEdicion == .active ? .inactive : .active
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        try? contexto.save()
                        cerrar()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $mostrarSelector) {
                VistaSelectorEjercicio { ejercicio in
                    añadir(ejercicio)
                }
            }
            .sheet(item: $elementoAEditar) { elemento in
                VistaEditorElementoRutina(elemento: elemento)
            }
        }
    }

    // MARK: - Fila

    private func filaElemento(_ elemento: ElementoRutina) -> some View {
        Button {
            elementoAEditar = elemento
        } label: {
            HStack(spacing: 10) {
                if elemento.idSuperserie != nil {
                    Image(systemName: "link")
                        .font(.caption)
                        .foregroundStyle(.tint)
                        .frame(width: 16)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(elemento.ejercicio?.nombre ?? "Ejercicio borrado")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("\(elemento.resumenObjetivo) · \(Formato.descanso(elemento.descansoSegundos))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            if elemento.idSuperserie == nil {
                Button {
                    agruparConSiguiente(elemento)
                } label: {
                    Label("Agrupar", systemImage: "link")
                }
                .tint(Paleta.carpeta)
            } else {
                Button {
                    desagrupar(elemento)
                } label: {
                    Label("Separar", systemImage: "link.badge.plus")
                }
                .tint(Paleta.aviso)
            }
        }
    }

    // MARK: - Acciones

    private func añadir(_ ejercicio: Ejercicio) {
        let ajustes = Ajustes.cargar(en: contexto)
        let orden = (rutina.elementos.map(\.orden).max() ?? -1) + 1
        let elemento = ElementoRutina(
            ejercicio: ejercicio,
            orden: orden,
            seriesObjetivo: 3,
            objetivoMin: ejercicio.tipoRegistro.esTiempo ? 30 : 8,
            objetivoMax: ejercicio.tipoRegistro.esTiempo ? 45 : 10,
            rirMin: ajustes.rirPorDefectoMin,
            rirMax: ajustes.rirPorDefectoMax,
            descansoSegundos: ajustes.descansoPorDefecto
        )
        contexto.insert(elemento)
        elemento.rutina = rutina
        try? contexto.save()
    }

    private func mover(desde origen: IndexSet, hasta destino: Int) {
        var lista = rutina.elementosOrdenados
        lista.move(fromOffsets: origen, toOffset: destino)
        for (indice, elemento) in lista.enumerated() {
            elemento.orden = indice
        }
        try? contexto.save()
    }

    private func borrar(_ indices: IndexSet) {
        let lista = rutina.elementosOrdenados
        let aBorrar = indices.compactMap { indice in
            indice < lista.count ? lista[indice] : nil
        }
        let restantes = lista.filter { elemento in !aBorrar.contains { $0 === elemento } }
        for elemento in aBorrar {
            contexto.delete(elemento)
        }
        for (indice, elemento) in restantes.enumerated() {
            elemento.orden = indice
        }
        try? contexto.save()
    }

    /// Agrupa este ejercicio con el siguiente en una superserie.
    private func agruparConSiguiente(_ elemento: ElementoRutina) {
        let lista = rutina.elementosOrdenados
        guard let posicion = lista.firstIndex(where: { $0 === elemento }),
              posicion + 1 < lista.count else { return }
        let siguiente = lista[posicion + 1]
        // Si el siguiente ya está en un grupo, se suma a ese.
        let id = siguiente.idSuperserie ?? UUID()
        elemento.idSuperserie = id
        siguiente.idSuperserie = id
        try? contexto.save()
    }

    private func desagrupar(_ elemento: ElementoRutina) {
        guard let id = elemento.idSuperserie else { return }
        elemento.idSuperserie = nil
        // Un grupo de uno no es una superserie: se deshace.
        let compañeros = rutina.elementos.filter { $0.idSuperserie == id }
        if compañeros.count == 1 {
            compañeros[0].idSuperserie = nil
        }
        try? contexto.save()
    }
}
