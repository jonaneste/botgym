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

    var body: some View {
        NavigationStack {
            List {
                if !entrenos.isEmpty {
                    Section {
                        resumenGeneral
                            .tarjeta()
                            .filaDesnuda(arriba: 8, abajo: 4)
                    }
                }

                if resumenSemanal.carreras > 0 {
                    Section("Esta semana corriendo") {
                        FilaResumenCarreras(resumen: resumenSemanal)
                            .tarjeta()
                            .filaDesnuda(arriba: 4, abajo: 4)
                    }
                }

                ForEach(agrupadosPorMes, id: \.clave) { grupo in
                    Section(grupo.titulo) {
                        ForEach(grupo.elementos) { elemento in
                            switch elemento {
                            case .gimnasio(let entreno):
                                // El enlace va invisible encima de la
                                // tarjeta, y no envolviéndola: un
                                // `NavigationLink` normal pinta su chevron en
                                // el borde de la fila, que con la lista sin
                                // fondo cae fuera de la tarjeta y sobre el
                                // gris. Así el chevron es el de dentro. El
                                // `Color.clear` es lo que le da el área de
                                // toque: con `EmptyView` el enlace no mide
                                // nada y la tarjeta dejaría de abrirse.
                                filaEntreno(entreno)
                                    .overlay {
                                        NavigationLink {
                                            VistaDetalleEntreno(entreno: entreno)
                                        } label: {
                                            Color.clear
                                        }
                                        .opacity(0)
                                    }
                                    .filaDesnuda(arriba: 4, abajo: 4)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            entrenoABorrar = entreno
                                        } label: {
                                            Label("Borrar", systemImage: "trash")
                                        }
                                    }
                            case .carrera(let carrera):
                                FilaCarrera(carrera: carrera)
                                    .filaDesnuda(arriba: 4, abajo: 4)
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
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Historial")
            .onAppear {
                CacheCarreras.compartida.cargarSiHaceFalta()
                carreras = CacheCarreras.compartida.recientes()
            }
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

    private var resumenGeneral: some View {
        HStack(spacing: 0) {
            CifraDestacada(valor: "\(entrenos.count)", etiqueta: "Entrenos")
            Divider()
            CifraDestacada(
                valor: "\(entrenos.reduce(0) { $0 + $1.seriesCompletadas })",
                etiqueta: "Series"
            )
            Divider()
            CifraDestacada(
                valor: Formato.volumen(entrenos.reduce(0) { $0 + $1.volumenTotal }),
                etiqueta: "Volumen"
            )
        }
        .frame(height: 52)
    }

    // MARK: - Fila

    private func filaEntreno(_ entreno: Entreno) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(entreno.nombre)
                    .font(.headline)
                Spacer(minLength: 8)
                Text(Formato.fechaRelativa(entreno.fechaInicio))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
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
        .tarjeta()
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
        carreras = CacheCarreras.compartida.recientes()
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
        .tarjeta()
    }
}

/// Resumen de kilómetros de la semana.
struct FilaResumenCarreras: View {
    let resumen: ResumenCarreras

    var body: some View {
        HStack(spacing: 0) {
            columna(Formato.numeroCorto(resumen.kilometros) + " km", "Distancia")
            Divider()
            columna("\(resumen.carreras)", resumen.carreras == 1 ? "Carrera" : "Carreras")
            Divider()
            columna(Formato.duracionLarga(resumen.duracion), "Tiempo")
            if let ritmo = resumen.ritmoMedioSegundosPorKm {
                Divider()
                columna(textoRitmo(ritmo), "Ritmo")
            }
        }
        .frame(height: 52)
    }

    private func columna(_ valor: String, _ titulo: String) -> some View {
        CifraDestacada(valor: valor, etiqueta: titulo)
    }

    private func textoRitmo(_ segundosPorKm: Double) -> String {
        let total = Int(segundosPorKm.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
