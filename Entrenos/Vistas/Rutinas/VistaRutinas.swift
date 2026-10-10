import SwiftUI
import SwiftData

/// Carpetas y rutinas.
struct VistaRutinas: View {
    @Environment(\.modelContext) private var contexto
    @Environment(ControladorEntreno.self) private var controlador

    @Query(sort: \CarpetaRutinas.orden) private var carpetas: [CarpetaRutinas]
    @Query(sort: \Rutina.orden) private var todasLasRutinas: [Rutina]

    @State private var mostrarNuevaCarpeta = false
    @State private var nombreNuevaCarpeta = ""
    @State private var rutinaAEditar: Rutina?
    @State private var carpetaDestino: CarpetaRutinas?
    @State private var rutinaABorrar: Rutina?

    private var rutinasSueltas: [Rutina] {
        todasLasRutinas.filter { $0.carpeta == nil }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(carpetas) { carpeta in
                    Section {
                        ForEach(carpeta.rutinasOrdenadas) { rutina in
                            filaRutina(rutina)
                        }
                        Button {
                            crearRutina(en: carpeta)
                        } label: {
                            Label("Nueva rutina aquí", systemImage: "plus")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .tarjeta(relleno: 12)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                        .filaDesnuda(arriba: 4, abajo: 4)
                    } header: {
                        HStack {
                            Label(carpeta.nombre, systemImage: "folder")
                            Spacer()
                            Text("\(carpeta.rutinas.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !rutinasSueltas.isEmpty {
                    Section("Sin carpeta") {
                        ForEach(rutinasSueltas) { rutina in
                            filaRutina(rutina)
                        }
                    }
                }

                // Las tres acciones comparten una sola tarjeta: son del mismo
                // tipo y separarlas repartiría tres bloques por el final de la
                // pantalla sin decir nada más.
                Section {
                    VStack(spacing: 0) {
                        accion("Nueva rutina", "plus.circle.fill") {
                            crearRutina(en: nil)
                        }
                        Divider().padding(.leading, 32)
                        accion("Nueva carpeta", "folder.badge.plus") {
                            mostrarNuevaCarpeta = true
                        }
                        Divider().padding(.leading, 32)
                        NavigationLink {
                            VistaBibliotecaEjercicios()
                        } label: {
                            HStack {
                                Label("Biblioteca de ejercicios", systemImage: "dumbbell")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                    }
                    .padding(.horizontal, 16)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                    .filaDesnuda(arriba: 12, abajo: 8)
                }

                if carpetas.isEmpty && rutinasSueltas.isEmpty {
                    ContentUnavailableView(
                        "Sin rutinas",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Crea una rutina para empezar a entrenar con ella.")
                    )
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Rutinas")
            .sheet(item: $rutinaAEditar) { rutina in
                VistaEditorRutina(rutina: rutina)
            }
            .alert("Nueva carpeta", isPresented: $mostrarNuevaCarpeta) {
                TextField("Bloque otoño", text: $nombreNuevaCarpeta)
                Button("Crear") { crearCarpeta() }
                Button("Cancelar", role: .cancel) { nombreNuevaCarpeta = "" }
            }
            // Con confirmación, como el borrado de un entreno y el de un
            // ejercicio. La fila ya tiene un toque que abre el editor y un
            // botón de "Empezar", así que es un sitio donde se desliza sin
            // querer, y "Borrar" está justo al lado de "Duplicar". El borrado
            // va en cascada a los elementos de la rutina: se lleva objetivos,
            // rangos de RIR, descansos, notas y superseries, sin deshacer.
            //
            // Es un `confirmationDialog` y no un `.alert` para no apilar dos
            // modificadores del mismo tipo de presentación en la misma vista,
            // que es la clase de cosa que SwiftUI resuelve de formas poco
            // obvias. Y para un borrado destructivo desde un deslizamiento, la
            // hoja de abajo es además lo idiomático en iOS.
            .confirmationDialog(
                "¿Borrar la rutina?",
                isPresented: Binding(
                    get: { rutinaABorrar != nil },
                    set: { presentado in if !presentado { rutinaABorrar = nil } }
                ),
                titleVisibility: .visible,
                presenting: rutinaABorrar
            ) { rutina in
                Button("Borrar", role: .destructive) { borrar(rutina) }
                Button("Cancelar", role: .cancel) { rutinaABorrar = nil }
            } message: { rutina in
                Text("«\(rutina.nombre)» y sus \(rutina.elementos.count) ejercicios planificados. El historial de lo que ya entrenaste no se toca.")
            }
        }
    }

    // MARK: - Filas

    private func filaRutina(_ rutina: Rutina) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(rutina.nombre)
                    .font(.headline)
                Text(rutina.resumen)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button {
                controlador.empezar(desde: rutina)
            } label: {
                Text("Empezar")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(controlador.hayEntrenoActivo)
        }
        .tarjeta()
        .contentShape(.rect)
        .onTapGesture { rutinaAEditar = rutina }
        .filaDesnuda(arriba: 4, abajo: 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                rutinaABorrar = rutina
            } label: {
                Label("Borrar", systemImage: "trash")
            }
            Button {
                duplicar(rutina)
            } label: {
                Label("Duplicar", systemImage: "doc.on.doc")
            }
            .tint(Paleta.carpeta)
        }
    }

    /// Una acción de la tarjeta del final.
    private func accion(_ titulo: String, _ icono: String, _ alPulsar: @escaping () -> Void) -> some View {
        Button(action: alPulsar) {
            Label(titulo, systemImage: icono)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
    }

    // MARK: - Acciones

    private func borrar(_ rutina: Rutina) {
        rutinaABorrar = nil
        contexto.delete(rutina)
        try? contexto.save()
    }

    private func crearCarpeta() {
        let nombre = nombreNuevaCarpeta.trimmingCharacters(in: .whitespacesAndNewlines)
        nombreNuevaCarpeta = ""
        guard !nombre.isEmpty else { return }
        let orden = (carpetas.map(\.orden).max() ?? -1) + 1
        let carpeta = CarpetaRutinas(nombre: nombre, orden: orden)
        contexto.insert(carpeta)
        try? contexto.save()
    }

    private func crearRutina(en carpeta: CarpetaRutinas?) {
        let hermanas = carpeta?.rutinas ?? rutinasSueltas
        let orden = (hermanas.map(\.orden).max() ?? -1) + 1
        let rutina = Rutina(nombre: "Rutina nueva", orden: orden)
        contexto.insert(rutina)
        rutina.carpeta = carpeta
        try? contexto.save()
        rutinaAEditar = rutina
    }

    private func duplicar(_ rutina: Rutina) {
        let copia = Rutina(
            nombre: "\(rutina.nombre) (copia)",
            notas: rutina.notas,
            orden: rutina.orden + 1
        )
        contexto.insert(copia)
        copia.carpeta = rutina.carpeta

        // Las superseries se renumeran: los identificadores no se comparten
        // entre rutinas distintas.
        var mapaSuperseries: [UUID: UUID] = [:]
        for elemento in rutina.elementosOrdenados {
            var nuevoIdSuperserie: UUID?
            if let original = elemento.idSuperserie {
                if let yaMapeado = mapaSuperseries[original] {
                    nuevoIdSuperserie = yaMapeado
                } else {
                    let nuevo = UUID()
                    mapaSuperseries[original] = nuevo
                    nuevoIdSuperserie = nuevo
                }
            }
            let copiaElemento = ElementoRutina(
                ejercicio: elemento.ejercicio,
                orden: elemento.orden,
                seriesObjetivo: elemento.seriesObjetivo,
                objetivoMin: elemento.objetivoMin,
                objetivoMax: elemento.objetivoMax,
                rirMin: elemento.rirMin,
                rirMax: elemento.rirMax,
                descansoSegundos: elemento.descansoSegundos,
                notas: elemento.notas,
                idSuperserie: nuevoIdSuperserie
            )
            contexto.insert(copiaElemento)
            copiaElemento.rutina = copia
        }
        try? contexto.save()
    }
}
