import SwiftUI
import SwiftData

/// El entreno en curso.
struct VistaEntrenoEnCurso: View {
    let entreno: Entreno
    let ajustes: Ajustes

    @Environment(ControladorEntreno.self) private var controlador
    @Environment(\.modelContext) private var contexto

    @State private var mostrarSelectorEjercicio = false
    @State private var mostrarFinalizar = false
    @State private var mostrarDescartar = false
    @State private var ejercicioAEditar: EjercicioEntreno?

    /// Lo que se hizo la última vez en cada ejercicio, indexado por
    /// `idEjercicio`. Se calcula una sola vez y al cambiar la lista de
    /// ejercicios: consultarlo dentro del cuerpo de la vista lanzaría un
    /// `fetch` por ejercicio en cada redibujado, y la cabecera redibuja cada
    /// segundo.
    @State private var anteriores: [UUID: [SerieValor]] = [:]

    /// Sugerencia de doble progresión por ejercicio. Se calcula con las
    /// anteriores, por el mismo motivo: consultarla en el cuerpo de la vista
    /// lanzaría un `fetch` por ejercicio en cada redibujado.
    @State private var sugerencias: [UUID: SugerenciaProgresion] = [:]

    var body: some View {
        VStack(spacing: 0) {
            lista

            if controlador.temporizador.activo {
                BarraDescanso(ajustes: ajustes)
                    .transition(.move(edge: .bottom))
            }
        }
        .overlay(alignment: .top) {
            if let aviso = controlador.avisoRecord {
                VistaAvisoRecord(aviso: aviso) {
                    withAnimation { controlador.descartarAvisoRecord() }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: aviso.id) {
                    // Se va solo a los 6 segundos: con el móvil en el banco no
                    // apetece buscar la X.
                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                    withAnimation { controlador.descartarAvisoRecord() }
                }
            }
        }
        .animation(.spring(duration: 0.35), value: controlador.avisoRecord)
        .onAppear(perform: recargarContexto)
        .onChange(of: entreno.ejercicios.count) { _, _ in recargarContexto() }
        .navigationTitle(entreno.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { barraHerramientas }
        .conBotonHecho()
        .sheet(isPresented: $mostrarSelectorEjercicio) {
            VistaSelectorEjercicio { ejercicio in
                controlador.añadirEjercicio(ejercicio, ajustes: ajustes)
            }
        }
        .sheet(isPresented: $mostrarFinalizar) {
            VistaFinalizarEntreno(entreno: entreno)
        }
        .sheet(item: $ejercicioAEditar) { ejercicio in
            VistaEditarObjetivoEjercicio(ejercicio: ejercicio)
        }
        .confirmationDialog(
            "¿Descartar este entreno?",
            isPresented: $mostrarDescartar,
            titleVisibility: .visible
        ) {
            Button("Descartar entreno", role: .destructive) {
                controlador.descartar()
            }
            Button("Seguir entrenando", role: .cancel) {}
        } message: {
            Text("Se borrará todo lo anotado. No se puede deshacer.")
        }
    }

    // MARK: - Lista

    private var lista: some View {
        List {
            Section { cabecera }

            ForEach(gruposVisuales) { grupo in
                Section {
                    ForEach(grupo.ejercicios) { ejercicio in
                        bloqueEjercicio(ejercicio)
                    }
                } header: {
                    if grupo.esSuperserie {
                        Label("Superserie", systemImage: "link")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                }
            }

            Section {
                Button {
                    mostrarSelectorEjercicio = true
                } label: {
                    Label("Añadir ejercicio", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                }

                Button(role: .destructive) {
                    mostrarDescartar = true
                } label: {
                    Label("Descartar entreno", systemImage: "trash")
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// Cronómetro, series y volumen. Se refresca cada segundo.
    private var cabecera: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            HStack {
                bloqueDato(
                    titulo: "Tiempo",
                    valor: Formato.cronometro(entreno.duracion),
                    icono: "stopwatch"
                )
                Spacer()
                bloqueDato(
                    titulo: "Series",
                    valor: "\(entreno.seriesCompletadas)/\(entreno.seriesTotales)",
                    icono: "checklist"
                )
                Spacer()
                bloqueDato(
                    titulo: "Volumen",
                    valor: Formato.volumen(entreno.volumenTotal),
                    icono: "scalemass"
                )
            }
            .padding(.vertical, 4)
        }
    }

    private func bloqueDato(titulo: String, valor: String, icono: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(titulo, systemImage: icono)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(valor)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .monospacedDigit()
        }
    }

    // MARK: - Bloque de un ejercicio

    @ViewBuilder
    private func bloqueEjercicio(_ ejercicio: EjercicioEntreno) -> some View {
        let seriesAnteriores = anteriores[ejercicio.idEjercicio] ?? []

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ejercicio.nombreEjercicio)
                        .font(.headline)
                    Text("\(ejercicio.resumenObjetivo) · descanso \(Formato.descanso(ejercicio.descansoSegundos))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let sugerencia = sugerencias[ejercicio.idEjercicio] {
                        VistaSugerencia(sugerencia: sugerencia, ejercicio: ejercicio)
                            .padding(.top, 2)
                    }
                }
                Spacer()
                Menu {
                    Button {
                        ejercicioAEditar = ejercicio
                    } label: {
                        Label("Editar objetivo", systemImage: "slider.horizontal.3")
                    }
                    Button {
                        controlador.añadirSerie(a: ejercicio)
                    } label: {
                        Label("Añadir serie", systemImage: "plus")
                    }
                    Button(role: .destructive) {
                        controlador.quitarEjercicio(ejercicio)
                    } label: {
                        Label("Quitar ejercicio", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
            }
        }
        .padding(.vertical, 2)

        ForEach(ejercicio.seriesOrdenadas) { serie in
            FilaSerie(
                serie: serie,
                ejercicio: ejercicio,
                serieAnterior: serieAnterior(para: serie, en: seriesAnteriores),
                ajustes: ajustes
            )
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    controlador.quitarSerie(serie, de: ejercicio)
                } label: {
                    Label("Borrar", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                Button {
                    serie.esCalentamiento.toggle()
                } label: {
                    Label("Calentamiento", systemImage: "flame")
                }
                .tint(.orange)
            }
        }

        Button {
            controlador.añadirSerie(a: ejercicio)
        } label: {
            Label("Añadir serie", systemImage: "plus")
                .font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(.bordered)

        TextField("Notas del ejercicio", text: Binding(
            get: { ejercicio.notas },
            set: { ejercicio.notas = $0 }
        ), axis: .vertical)
        .font(.subheadline)
        .lineLimit(1...3)
    }

    private func recargarContexto() {
        var mapaAnteriores: [UUID: [SerieValor]] = [:]
        var mapaSugerencias: [UUID: SugerenciaProgresion] = [:]

        for ejercicio in entreno.ejerciciosOrdenados {
            let id = ejercicio.idEjercicio
            if mapaAnteriores[id] == nil, let previa = controlador.actuacionAnterior(de: ejercicio) {
                mapaAnteriores[id] = previa.seriesEfectivas.map(\.valor)
            }
            if mapaSugerencias[id] == nil {
                let sugerencia = controlador.sugerencia(para: ejercicio, ajustes: ajustes)
                // Las series libres no tienen nada que sugerir: no se guarda,
                // y así la vista no pinta un hueco vacío.
                if sugerencia.accion != .sinRango {
                    mapaSugerencias[id] = sugerencia
                }
            }
        }

        anteriores = mapaAnteriores
        sugerencias = mapaSugerencias
    }

    /// Casa la serie actual con la misma serie de la sesión anterior.
    /// Si la anterior tuvo menos series, se usa la última.
    private func serieAnterior(para serie: SerieRegistrada, en previas: [SerieValor]) -> SerieValor? {
        guard !previas.isEmpty else { return nil }
        if serie.orden < previas.count { return previas[serie.orden] }
        return previas.last
    }

    // MARK: - Agrupación por superseries

    /// Agrupa los ejercicios consecutivos que comparten `idSuperserie` para
    /// pintarlos juntos bajo una cabecera.
    private var gruposVisuales: [GrupoEjercicios] {
        var grupos: [GrupoEjercicios] = []
        for ejercicio in entreno.ejerciciosOrdenados {
            if let id = ejercicio.idSuperserie,
               let ultimo = grupos.last,
               ultimo.idSuperserie == id {
                grupos[grupos.count - 1].ejercicios.append(ejercicio)
            } else {
                grupos.append(
                    GrupoEjercicios(
                        id: ejercicio.idPublico,
                        idSuperserie: ejercicio.idSuperserie,
                        ejercicios: [ejercicio]
                    )
                )
            }
        }
        return grupos
    }

    // MARK: - Barra de herramientas

    @ToolbarContentBuilder
    private var barraHerramientas: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                mostrarFinalizar = true
            } label: {
                Text("Terminar")
                    .fontWeight(.semibold)
            }
            .disabled(entreno.seriesCompletadas == 0)
        }
    }
}

/// Grupo de ejercicios que se pintan juntos: uno solo, o una superserie.
struct GrupoEjercicios: Identifiable {
    let id: UUID
    let idSuperserie: UUID?
    var ejercicios: [EjercicioEntreno]

    var esSuperserie: Bool { idSuperserie != nil && ejercicios.count > 1 }
}
