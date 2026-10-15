import SwiftUI
import SwiftData

/// Historial de entrenos finalizados.
struct VistaHistorial: View {
    @Environment(\.modelContext) private var contexto

    // Se filtra por el valor crudo del estado porque en iOS 17 los
    // `#Predicate` sobre propiedades de tipo enum no son fiables.
    // `rawEntrenoFinalizado` es una constante de nivel de archivo definida en
    // Entreno.swift: dentro de un predicado solo se pueden capturar
    // identificadores simples. Ver el comentario de allí.
    @Query(
        filter: #Predicate<Entreno> { $0.estadoRaw == rawEntrenoFinalizado },
        sort: \Entreno.fechaInicio,
        order: .reverse
    )
    private var entrenos: [Entreno]

    @State private var entrenoABorrar: Entreno?
    @State private var carreras: [Carrera] = []
    @State private var mostrarAnotarCarrera = false

    var body: some View {
        NavigationStack {
            List {
                if !entrenos.isEmpty {
                    Section {
                        resumenGeneral
                    }
                }

                if resumenSemanal.carreras > 0 {
                    Section("Esta semana corriendo") {
                        FilaResumenCarreras(resumen: resumenSemanal)
                    }
                }

                ForEach(agrupadosPorMes, id: \.clave) { grupo in
                    Section(grupo.titulo) {
                        ForEach(grupo.elementos) { elemento in
                            switch elemento {
                            case .gimnasio(let entreno):
                                NavigationLink {
                                    VistaDetalleEntreno(entreno: entreno)
                                } label: {
                                    filaEntreno(entreno)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        entrenoABorrar = entreno
                                    } label: {
                                        Label("Borrar", systemImage: "trash")
                                    }
                                }
                            case .carrera(let carrera):
                                FilaCarrera(carrera: carrera)
                            }
                        }
                    }
                }

                if entrenos.isEmpty && carreras.isEmpty {
                    ContentUnavailableView(
                        "Sin entrenos todavía",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Cuando termines tu primer entreno aparecerá aquí.")
                    )
                }
            }
            .navigationTitle("Historial")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        mostrarAnotarCarrera = true
                    } label: {
                        Label("Anotar carrera", systemImage: "figure.run")
                    }
                    .tint(Paleta.carrera)
                }
            }
            .sheet(isPresented: $mostrarAnotarCarrera) {
                VistaAnotarCarreraManual()
            }
            .onChange(of: mostrarAnotarCarrera) { _, abierto in
                // Al cerrar la hoja: si se anotó una, tiene que aparecer ya.
                if !abierto { carreras = RepositorioCarreras(contexto: contexto).recientes() }
            }
            .onAppear { carreras = RepositorioCarreras(contexto: contexto).recientes() }
            .refreshable { await recargarCarreras() }
            .alert(
                "¿Borrar entreno?",
                isPresented: Binding(
                    get: { entrenoABorrar != nil },
                    set: { presentado in if !presentado { entrenoABorrar = nil } }
                ),
                presenting: entrenoABorrar
            ) { objetivo in
                Button("Borrar", role: .destructive) {
                    contexto.delete(objetivo)
                    try? contexto.save()
                    entrenoABorrar = nil
                }
                Button("Cancelar", role: .cancel) { entrenoABorrar = nil }
            } message: { objetivo in
                Text("Se borra el entreno de \(Formato.fechaCorta(objetivo.fechaInicio)) y todas sus series. No se puede deshacer.")
            }
        }
    }

    // MARK: - Resumen

    /// El acumulado de todo el historial, con las mismas cifras grandes que
    /// la cabecera del entreno y el resumen de fin: es el mismo tipo de dato
    /// y tiene que leerse igual en los tres sitios.
    ///
    /// Las filas de abajo siguen siendo filas de lista a propósito. Un
    /// historial es para recorrerlo con el pulgar, y convertirlo en tarjetas
    /// sueltas caben menos entrenos en pantalla sin ganar nada.
    private var resumenGeneral: some View {
        HStack(spacing: 0) {
            CifraDestacada(valor: "\(entrenos.count)", etiqueta: "Entrenos")
            Divider().frame(height: 28)
            CifraDestacada(
                valor: "\(entrenos.reduce(0) { $0 + $1.seriesCompletadas })",
                etiqueta: "Series"
            )
            Divider().frame(height: 28)
            CifraDestacada(
                valor: Formato.volumen(entrenos.reduce(0) { $0 + $1.volumenTotal }),
                etiqueta: "Volumen"
            )
        }
        .padding(.vertical, 6)
        // Mínimo y no fijo: las dos líneas de texto crecen con el ajuste
        // del sistema, y a tamaños de accesibilidad se recortaban.
        .frame(minHeight: 44)
    }

    // MARK: - Fila

    private func filaEntreno(_ entreno: Entreno) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(entreno.nombre)
                    .font(.body.weight(.medium))
                Spacer()
                Text(Formato.fechaRelativa(entreno.fechaInicio))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                etiqueta("stopwatch", Formato.duracionLarga(entreno.duracionFinal ?? entreno.duracion))
                etiqueta("checklist", "\(entreno.seriesCompletadas) series")
                etiqueta("scalemass", Formato.volumen(entreno.volumenTotal))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let hombro = entreno.molestiaHombro, hombro >= 4 {
                etiquetaMolestia("Hombro", hombro)
            }
            if let rodilla = entreno.molestiaRodilla, rodilla >= 4 {
                etiquetaMolestia("Rodilla", rodilla)
            }
        }
        .padding(.vertical, 3)
    }

    private func etiqueta(_ icono: String, _ texto: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icono)
            Text(texto)
        }
    }

    private func etiquetaMolestia(_ zona: String, _ valor: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("\(zona) \(valor)/10")
        }
        .font(.caption2)
        .foregroundStyle(Paleta.molestia(valor))
    }

    // MARK: - Agrupación por mes

    /// Resumen de kilómetros de la semana en curso.
    private var resumenSemanal: ResumenCarreras {
        ServicioCarreras.resumenSemanal(carreras, semanaDe: Date())
    }

    /// Gimnasio y carreras en una sola línea de tiempo, de más reciente a más
    /// antigua.
    private var todosLosElementos: [ElementoHistorial] {
        let deGimnasio = entrenos.map(ElementoHistorial.gimnasio)
        let deCarreras = carreras.map(ElementoHistorial.carrera)
        return (deGimnasio + deCarreras).sorted { $0.fecha > $1.fecha }
    }

    private var agrupadosPorMes: [GrupoMes] {
        let calendario = Formato.calendarioES
        var grupos: [GrupoMes] = []
        for elemento in todosLosElementos {
            let componentes = calendario.dateComponents([.year, .month], from: elemento.fecha)
            let clave = (componentes.year ?? 0) * 100 + (componentes.month ?? 0)
            if let ultimo = grupos.last, ultimo.clave == clave {
                grupos[grupos.count - 1].elementos.append(elemento)
            } else {
                grupos.append(
                    GrupoMes(
                        clave: clave,
                        titulo: Self.tituloMes(elemento.fecha),
                        elementos: [elemento]
                    )
                )
            }
        }
        return grupos
    }

    /// Relee las carreras de Salud si está conectado, y si no se queda con lo
    /// que haya en el caché del archivo importado.
    private func recargarCarreras() async {
        let ajustes = Ajustes.cargar(en: contexto)
        if ajustes.healthKitActivado, GestorHealthKit.shared.disponible {
            let desde = Date().addingTimeInterval(-120 * 86_400)
            if let nuevas = try? await GestorHealthKit.shared.carreras(desde: desde) {
                CacheCarreras.compartida.guardar(nuevas)
            }
        }
        carreras = RepositorioCarreras(contexto: contexto).recientes()
    }

    private static func tituloMes(_ fecha: Date) -> String {
        let formateador = DateFormatter()
        formateador.locale = Formato.localeES
        formateador.setLocalizedDateFormatFromTemplate("MMMM y")
        return Formato.capitalizarPrimera(formateador.string(from: fecha))
    }
}

struct GrupoMes {
    let clave: Int
    let titulo: String
    var elementos: [ElementoHistorial]
}

/// Una entrada del historial: un entreno de gimnasio o una carrera de Salud.
enum ElementoHistorial: Identifiable {
    case gimnasio(Entreno)
    case carrera(Carrera)

    var id: String {
        switch self {
        case .gimnasio(let entreno): return "g-\(entreno.idPublico.uuidString)"
        case .carrera(let carrera): return "c-\(carrera.id)"
        }
    }

    var fecha: Date {
        switch self {
        case .gimnasio(let entreno): return entreno.fechaInicio
        case .carrera(let carrera): return carrera.fechaInicio
        }
    }
}

/// Fila de una carrera en el historial.
struct FilaCarrera: View {
    let carrera: Carrera

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.title3)
                .foregroundStyle(Paleta.carrera)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(Formato.numeroCorto(carrera.distanciaKm) + " km")
                        .font(.body.weight(.medium))
                    Spacer()
                    Text(Formato.fechaRelativa(carrera.fechaInicio))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    HStack(spacing: 3) {
                        Image(systemName: "stopwatch")
                        Text(Formato.duracionLarga(carrera.duracion))
                    }
                    if let ritmo = carrera.ritmoTexto {
                        HStack(spacing: 3) {
                            Image(systemName: "speedometer")
                            Text(ritmo)
                        }
                    }
                    if let pulso = carrera.pulsoMedio {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill")
                            Text("\(Int(pulso.rounded()))")
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

/// Resumen de kilómetros de la semana.
struct FilaResumenCarreras: View {
    let resumen: ResumenCarreras

    var body: some View {
        HStack {
            columna(Formato.numeroCorto(resumen.kilometros) + " km", "Distancia")
            Divider()
            columna("\(resumen.carreras)", resumen.carreras == 1 ? "Carrera" : "Carreras")
            Divider()
            columna(Formato.duracionLarga(resumen.duracion), "Tiempo")
            if let ritmo = resumen.ritmoMedioSegundosPorKm {
                Divider()
                columna(textoRitmo(ritmo), "Ritmo medio")
            }
        }
        // Mínimo y no fijo: las dos líneas de texto crecen con el ajuste
        // del sistema, y a tamaños de accesibilidad se recortaban.
        .frame(minHeight: 44)
    }

    private func columna(_ valor: String, _ titulo: String) -> some View {
        VStack(spacing: 2) {
            Text(valor)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .monospacedDigit()
            Text(titulo)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func textoRitmo(_ segundosPorKm: Double) -> String {
        let total = Int(segundosPorKm.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
