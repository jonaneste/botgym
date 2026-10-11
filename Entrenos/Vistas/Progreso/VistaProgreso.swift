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
    /// Se fija al recargar y no se lee en el cuerpo de la vista: así la lista
    /// no cambia de color a mitad de un redibujado.
    @State private var fraccionDeSemana: Double = 1

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
                            FilaSeriesGrupo(datos: grupo, fraccionDeSemana: fraccionDeSemana)
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
                    Text("Los grupos secundarios cuentan como media serie: un press de banca suma 1 a pecho y 0,5 a tríceps. El aviso mira cuánta semana queda, así que el lunes no sale en rojo nada.")
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
        fraccionDeSemana = CalendarioEntrenos.fraccionTranscurridaDeSemana(Date())
        ejercicios = repositorio.ejerciciosConHistorial()
    }
}

/// Fila de un grupo muscular con su progreso semanal.
struct FilaSeriesGrupo: View {
    let datos: SeriesDeGrupo
    /// Parte de la semana transcurrida, para juzgar el ritmo. Se pasa desde
    /// fuera y no se lee de `Date()` aquí dentro para que la fila siga siendo
    /// una función de sus datos y se pueda previsualizar cualquier día.
    var fraccionDeSemana: Double = 1

    private var ritmo: RitmoSemanal { datos.ritmo(fraccionDeSemana: fraccionDeSemana) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(datos.grupo.nombre)
                    .font(.subheadline)
                Spacer()
                // El rojo/naranja/verde es justo el par que peor distinguen
                // los daltónicos más comunes, así que el objetivo cumplido
                // lleva además una marca. La cifra ya va siempre, que es lo
                // que de verdad informa.
                if let simbolo {
                    Image(systemName: simbolo)
                        .font(.caption)
                        .foregroundStyle(color)
                        .accessibilityHidden(true)
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
        .accessibilityValue(textoAccesible)
    }

    /// Lo que lee VoiceOver: sin esto leía el nombre, la cifra y la barra como
    /// tres elementos sueltos, y «8 / 12» no dice de qué.
    private var textoAccesible: String {
        let series = Formato.numeroCorto(datos.series)
        guard let objetivo = datos.objetivo else {
            return "\(series) series esta semana"
        }
        let base = "\(series) de \(objetivo) series."
        switch ritmo {
        case .sinObjetivo, .alDia:
            return "\(base) Vas al día, faltan \(datos.faltan ?? 0)."
        case .cumplido:
            return "\(base) Objetivo cumplido."
        case .corto:
            return "\(base) Vas corto: faltan \(datos.faltan ?? 0)."
        case .muyCorto:
            return "\(base) Quedan \(datos.faltan ?? 0) y poca semana."
        }
    }

    private var texto: String {
        let series = Formato.numeroCorto(datos.series)
        if let objetivo = datos.objetivo {
            return "\(series) / \(objetivo)"
        }
        return series
    }

    /// El color dice si hay algo que hacer, no cuánto falta: lo segundo ya lo
    /// dice la cifra. Ir al día no se pinta de ningún color de aviso.
    private var color: Color {
        switch ritmo {
        case .sinObjetivo: return .secondary
        case .cumplido: return .green
        case .alDia: return .primary
        case .corto: return .orange
        case .muyCorto: return .red
        }
    }

    /// Una forma además del color, porque rojo, naranja y verde son justo los
    /// que peor se distinguen con los daltonismos más comunes.
    private var simbolo: String? {
        switch ritmo {
        case .sinObjetivo, .alDia: return nil
        case .cumplido: return "checkmark.circle.fill"
        case .corto: return "clock"
        case .muyCorto: return "exclamationmark.triangle.fill"
        }
    }
}
