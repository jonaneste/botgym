import SwiftUI
import SwiftData

/// Pestaña de progreso: series semanales y ejercicios con historial.
struct VistaProgreso: View {
    @Environment(\.modelContext) private var contexto

    @State private var ajustes: Ajustes?
    @State private var seriesSemanales: [SeriesDeGrupo] = []
    @State private var tendencia: [SeriesDeSemana] = []
    @State private var ejercicios: [(ejercicio: Ejercicio, ultimaVez: Date)] = []
    @State private var busqueda = ""

    /// El alto de la gráfica sube con el tamaño de texto del sistema: con
    /// cuerpos de accesibilidad, las etiquetas de los ejes se comían el área
    /// de dibujo a 150 puntos fijos.
    @ScaledMetric(relativeTo: .caption) private var altoGrafica: CGFloat = 150

    var body: some View {
        NavigationStack {
            List {
                // La pestaña abría directamente con una gráfica de barras y
                // ningún número: para saber cómo iba la semana había que leer
                // el eje. Esto lo dice de una vez, que es lo que se viene a ver.
                if !tendencia.isEmpty {
                    Section {
                        VStack(spacing: 14) {
                            HStack(spacing: 0) {
                                CifraDestacada(
                                    valor: Formato.numeroCorto(seriesEstaSemana),
                                    etiqueta: "Series esta semana",
                                    color: .accentColor
                                )
                                Divider().frame(height: 28)
                                CifraDestacada(
                                    valor: Formato.numeroCorto(mediaSemanal),
                                    etiqueta: "Media de 8 semanas"
                                )
                            }

                            GraficaSeriesSemanales(datos: tendencia)
                                .frame(height: altoGrafica)
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section {
                    if seriesSemanales.isEmpty {
                        Text("Sin series esta semana.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(seriesSemanales) { grupo in
                            FilaSeriesGrupo(datos: grupo)
                        }
                    }
                } header: {
                    HStack {
                        Text("Esta semana por grupo")
                        Spacer()
                        NavigationLink("Objetivos") {
                            VistaObjetivosSemanales()
                        }
                        .font(.caption)
                    }
                } footer: {
                    Text("Los grupos secundarios cuentan como media serie: un press de banca suma 1 a pecho y 0,5 a tríceps.")
                }

                Section("Ejercicios") {
                    if ejerciciosFiltrados.isEmpty {
                        Text(ejercicios.isEmpty
                             ? "Cuando termines un entreno, aquí verás tus récords y gráficas."
                             : "Sin resultados.")
                        .foregroundStyle(.secondary)
                    }
                    ForEach(ejerciciosFiltrados, id: \.ejercicio.idPublico) { entrada in
                        NavigationLink {
                            VistaDetalleEjercicio(ejercicio: entrada.ejercicio)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entrada.ejercicio.nombre)
                                    .font(.body)
                                Text("Última vez: \(Formato.fechaRelativa(entrada.ultimaVez))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .searchable(text: $busqueda, prompt: "Buscar ejercicio")
            .navigationTitle("Progreso")
            .refreshable { recargar() }
            .onAppear(perform: recargar)
        }
    }

    /// Las series de la última semana de la tendencia, que es la actual.
    private var seriesEstaSemana: Double {
        tendencia.last?.series ?? 0
    }

    private var mediaSemanal: Double {
        guard !tendencia.isEmpty else { return 0 }
        return tendencia.reduce(0.0) { $0 + $1.series } / Double(tendencia.count)
    }

    private var ejerciciosFiltrados: [(ejercicio: Ejercicio, ultimaVez: Date)] {
        let texto = Ejercicio.normalizar(busqueda)
        guard !texto.isEmpty else { return ejercicios }
        return ejercicios.filter { $0.ejercicio.nombreNormalizado.contains(texto) }
    }

    private func recargar() {
        let cargados = ajustes ?? Ajustes.cargar(en: contexto)
        ajustes = cargados

        let repositorio = RepositorioProgreso(contexto: contexto)
        seriesSemanales = repositorio.seriesSemanales(
            semanaDe: Date(),
            objetivos: cargados.objetivosSemanales
        )
        tendencia = repositorio.tendenciaSemanal(semanas: 8)
        ejercicios = repositorio.ejerciciosConHistorial()
    }
}

/// Fila de un grupo muscular con su progreso semanal.
struct FilaSeriesGrupo: View {
    let datos: SeriesDeGrupo

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(datos.grupo.nombre)
                    .font(.subheadline)
                Spacer()
                // El símbolo acompaña al color a propósito: si el cumplimiento
                // se dijera solo con verde, naranja o rojo, quien no distinga
                // esos tonos se queda sin saber si va bien.
                if let simbolo {
                    Image(systemName: simbolo)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                }
                Text(texto)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
            }

            if let progreso = datos.progreso {
                ProgressView(value: progreso)
                    .tint(color)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(datos.grupo.nombre)
        .accessibilityValue(descripcionAccesible)
    }

    private var texto: String {
        let series = Formato.numeroCorto(datos.series)
        if let objetivo = datos.objetivo {
            return "\(series) / \(objetivo)"
        }
        return series
    }

    private var color: Color {
        guard let progreso = datos.progreso else { return .secondary }
        if datos.cumplido { return Paleta.logrado }
        return progreso >= 0.6 ? Paleta.aviso : Paleta.insuficiente
    }

    /// Forma que dobla al color. Sin objetivo no hay nada que cumplir, así que
    /// tampoco hay símbolo.
    private var simbolo: String? {
        guard let progreso = datos.progreso else { return nil }
        if datos.cumplido { return "checkmark.circle.fill" }
        return progreso >= 0.6 ? "circle.bottomhalf.filled" : "exclamationmark.circle"
    }

    /// Lo que oye VoiceOver: el número y el estado dichos con palabras, porque
    /// ni el color ni la barra de progreso le llegan.
    private var descripcionAccesible: String {
        let series = Formato.numeroCorto(datos.series)
        guard let objetivo = datos.objetivo else {
            return "\(series) series esta semana"
        }
        let estado: String
        if datos.cumplido {
            estado = "objetivo cumplido"
        } else if let progreso = datos.progreso, progreso >= 0.6 {
            estado = "cerca del objetivo"
        } else {
            estado = "por debajo del objetivo"
        }
        return "\(series) de \(objetivo) series, \(estado)"
    }
}
