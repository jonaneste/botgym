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

    var body: some View {
        NavigationStack {
            List {
                if !tendencia.isEmpty {
                    Section("Series por semana") {
                        GraficaSeriesSemanales(datos: tendencia)
                            .frame(height: 150)
                            .padding(.vertical, 4)
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
            HStack(alignment: .firstTextBaseline) {
                Text(datos.grupo.nombre)
                    .font(.subheadline)
                Spacer()
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
        if datos.cumplido { return .green }
        return progreso >= 0.6 ? .orange : .red
    }
}
