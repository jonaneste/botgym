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
                        }
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

                Section {
                    Button {
                        crearRutina(en: nil)
                    } label: {
                        Label("Nueva rutina", systemImage: "plus.circle.fill")
                    }
                    Button {
                        mostrarNuevaCarpeta = true
                    } label: {
                        Label("Nueva carpeta", systemImage: "folder.badge.plus")
                    }
                    NavigationLink {
                        VistaBibliotecaEjercicios()
                    } label: {
                        Label("Biblioteca de ejercicios", systemImage: "dumbbell")
                    }
                }

                if carpetas.isEmpty && rutinasSueltas.isEmpty {
                    ContentUnavailableView(
                        "Sin rutinas",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Crea una rutina para empezar a entrenar con ella.")
                    )
                }
            }
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
            VStack(alignment: .leading, spacing: 3) {
                Text(rutina.nombre)
                    .font(.body.weight(.medium))
                Text(rutina.resumen)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Con un entreno abierto no se puede empezar otro, pero cinco
            // botones grises sin decir por qué no explican nada: parecen la
            // app rota. El de la rutina en curso pasa a «En curso», que es
            // la razón de que los demás estén apagados.
            if esLaDelEntrenoActivo(rutina) {
                Pastilla(texto: "En curso")
            } else {
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
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
        .onTapGesture { rutinaAEditar = rutina }
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

    // MARK: - Acciones

    private func borrar(_ rutina: Rutina) {
        rutinaABorrar = nil
        contexto.delete(rutina)
        try? contexto.save()
    }

    /// La rutina de la que salió el entreno que está abierto ahora mismo.
    ///
    /// Por identificador y no por nombre: dos rutinas pueden llamarse igual, y
    /// renombrar una no debe desvincularla del entreno que salió de ella.
    private func esLaDelEntrenoActivo(_ rutina: Rutina) -> Bool {
        guard let entreno = controlador.entreno else { return false }
        return entreno.idRutinaOrigen == rutina.idPublico
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
