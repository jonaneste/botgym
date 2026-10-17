import SwiftUI
import SwiftData

/// Pestaña de progreso: series semanales y ejercicios con historial.
struct VistaProgreso: View {
    @Environment(\.modelContext) private var contexto

    @State private var ajustes: Ajustes?
    @State private var seriesSemanales: [SeriesDeGrupo] = []
    @State private var tendencia: [SeriesDeSemana] = []
    @State private var tendenciaPorRegion: [SeriesDeSemanaYRegion] = []
    @State private var ejercicios: [(ejercicio: Ejercicio, ultimaVez: Date)] = []
    @State private var busqueda = ""
    /// Se fija al recargar y no se lee en el cuerpo de la vista: así la lista
    /// no cambia de color a mitad de un redibujado.
    @State private var fraccionDeSemana: Double = 1

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
                // Ocho semanas a cero no son una gráfica: son un marco con
                // fechas y nada dentro, que parece que algo ha fallado. Hasta
                // que haya una serie registrada, mejor no pintarla.
                if tendencia.contains(where: { $0.series > 0 }) {
                    Section {
                        VStack(spacing: 14) {
                            HStack(spacing: 0) {
                                CifraDestacada(
                                    valor: Formato.numeroCorto(seriesEstaSemana),
                                    etiqueta: "Series esta semana",
                                    color: Paleta.acento
                                )
                                Divider().frame(height: 28)
                                CifraDestacada(
                                    valor: Formato.numeroCorto(mediaSemanal),
                                    etiqueta: "Media de 8 semanas"
                                )
                            }

                            GraficaSeriesSemanales(datos: tendencia, porRegion: tendenciaPorRegion)
                                .frame(height: altoGrafica)
                        }
                        .padding(.vertical, 6)
                    }
                }

                // El cuerpo antes que la lista: dice dónde se ha ido la
                // semana de un golpe, y la lista de abajo es el detalle para
                // quien quiera la cifra exacta.
                if !seriesSemanales.isEmpty {
                    Section {
                        MapaDelCuerpo(grupos: seriesSemanales)
                            .padding(.vertical, 6)
                    } header: {
                        Text("Dónde se ha ido la semana")
                    }
                }

                if seriesSemanales.isEmpty {
                    Section {
                        Text("Sin series esta semana.")
                            .foregroundStyle(.secondary)
                    } header: {
                        cabeceraDeGrupos
                    }
                } else {
                    // Una sección por región en vez de dieciséis filas
                    // seguidas. Para saber cómo iba la pierna había que sumar
                    // seis a ojo, y el mapa de arriba ya organiza por región:
                    // la lista era el único sitio donde esa estructura se
                    // perdía.
                    ForEach(Array(bloquesPorRegion.enumerated()), id: \.element.id) { indice, bloque in
                        Section {
                            ForEach(bloque.grupos) { grupo in
                                FilaSeriesGrupo(datos: grupo, fraccionDeSemana: fraccionDeSemana)
                            }
                        } header: {
                            // En un `VStack` explícito y no como dos vistas
                            // sueltas: la cabecera de una sección de `List`
                            // espera una vista, y con dos la segunda —la de la
                            // región— no llegaba a pintarse en el primer
                            // bloque.
                            //
                            // El enlace a Objetivos va una sola vez, en la
                            // primera región: repetido en cada bloque serían
                            // cinco enlaces al mismo sitio.
                            VStack(alignment: .leading, spacing: 8) {
                                if indice == 0 {
                                    cabeceraDeGrupos
                                }
                                TotalDeRegion(bloque: bloque, fraccionDeSemana: fraccionDeSemana)
                            }
                        } footer: {
                            if indice == bloquesPorRegion.count - 1 {
                                Text("Los grupos secundarios cuentan como media serie: un press de banca suma 1 a pecho y 0,5 a tríceps. El aviso mira cuánta semana queda, así que el lunes no sale en rojo nada.")
                            }
                        }
                    }
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

    private var cabeceraDeGrupos: some View {
        HStack {
            Text("Esta semana por grupo")
            Spacer()
            NavigationLink("Objetivos") {
                VistaObjetivosSemanales()
            }
            .font(.caption)
        }
    }

    private var bloquesPorRegion: [SeriesDeRegion] {
        ServicioVolumen.porRegion(seriesSemanales)
    }

    /// Pone los objetivos semanales a partir de las rutinas, una sola vez.
    ///
    /// Sin objetivos, media pantalla no dice nada: ni ritmo, ni color, ni
    /// aviso de que vas corto. Y el número no se inventa, sale de lo que
    /// suman tus propias rutinas en una semana, así que es el que se cumple
    /// haciendo tu plan.
    ///
    /// Una sola vez, con su marca guardada: quien los borra a propósito no
    /// quiere encontrárselos de vuelta al entrar en Progreso.
    private func ponerObjetivosSiFaltan(_ ajustes: Ajustes) {
        guard !ajustes.objetivosPuestosSolos, ajustes.objetivosSemanales.isEmpty else { return }

        let rutinas = RepositorioEntrenos(contexto: contexto).rutinas()
        let elementos = rutinas.flatMap { rutina in
            rutina.elementosOrdenados.compactMap { elemento -> ElementoPlanificado? in
                guard let ejercicio = elemento.ejercicio else { return nil }
                return ElementoPlanificado(
                    grupoPrincipal: ejercicio.grupoPrincipal,
                    gruposSecundarios: ejercicio.gruposSecundarios,
                    series: elemento.seriesObjetivo
                )
            }
        }
        let objetivos = VolumenPlanificado.objetivos(elementos)
        guard !objetivos.isEmpty else { return }

        ajustes.objetivosSemanales = objetivos
        ajustes.objetivosPuestosSolos = true
        try? contexto.save()
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
        ponerObjetivosSiFaltan(cargados)

        let repositorio = RepositorioProgreso(contexto: contexto)
        seriesSemanales = repositorio.seriesSemanales(
            semanaDe: Date(),
            objetivos: cargados.objetivosSemanales
        )
        tendencia = repositorio.tendenciaSemanal(semanas: 8)
        tendenciaPorRegion = repositorio.tendenciaSemanalPorRegion(semanas: 8)
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
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // El punto es de la región y el número es del estado: dos
                // informaciones distintas que antes se peleaban por el mismo
                // color, porque la fila solo tenía el del cumplimiento.
                Circle()
                    .fill(Paleta.grupo(datos.grupo))
                    .frame(width: 8, height: 8)
                Text(datos.grupo.nombre)
                    .font(.subheadline)
                Spacer()
                // El rojo/naranja/verde es justo el par que peor distinguen
                // los daltónicos más comunes, así que el estado lleva además
                // una marca. La cifra ya va siempre, que es lo que de verdad
                // informa, y el símbolo se le oculta a VoiceOver porque la
                // etiqueta de la fila ya lo dice con palabras.
                if let simbolo {
                    Image(systemName: simbolo)
                        .font(.caption.weight(.semibold))
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
                    .tint(ritmo == .alDia ? Paleta.grupo(datos.grupo) : color)
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
        case .cumplido: return Paleta.logrado
        case .alDia: return .primary
        case .corto: return Paleta.aviso
        case .muyCorto: return Paleta.insuficiente
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

/// La cabecera de un bloque de región: su nombre y su total.
///
/// Es el número que de verdad se mira entre semana —«cómo voy de pierna»—, y
/// antes había que sumar seis filas a ojo para sacarlo.
struct TotalDeRegion: View {
    let bloque: SeriesDeRegion
    var fraccionDeSemana: Double = 1

    private var ritmo: RitmoSemanal {
        bloque.comoGrupo.ritmo(fraccionDeSemana: fraccionDeSemana)
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Paleta.region(bloque.region))
                .frame(width: 8, height: 8)
            // En primario y no con el gris de cabecera de sección: esta
            // línea no rotula, lleva un dato —«0,5 / 43» es el número que se
            // mira entre semana—, y el gris de las cabeceras se queda en 2,9:1
            // sobre el fondo claro. Un dato no se lee a contraste de rótulo.
            // `Color.primary` y no `.primary` a secas: dentro de la cabecera
            // de una sección, el estilo jerárquico se resuelve contra el de la
            // propia cabecera, así que `.primary` ahí sigue siendo el gris de
            // rótulo. El nombre salía apagado y la cifra de al lado no.
            Text(bloque.region.nombre)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
            Spacer()
            Text(texto)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bloque.region.nombre)
        .accessibilityValue(texto)
    }

    private var texto: String {
        let series = Formato.numeroCorto(bloque.series)
        guard let objetivo = bloque.objetivo else { return series }
        return "\(series) / \(objetivo)"
    }

    /// Sin los rojos y ámbares de las filas: el aviso de cada grupo ya está
    /// ahí abajo, y repetirlo en la cabecera son dieciséis avisos más cinco.
    /// Solo el verde de cumplido se destaca, porque es el único que da una
    /// noticia que no estaba.
    private var color: Color {
        ritmo == .cumplido ? Paleta.logrado : Color.primary
    }
}
