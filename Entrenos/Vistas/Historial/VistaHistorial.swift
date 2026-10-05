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

    var body: some View {
        NavigationStack {
            List {
                if !entrenos.isEmpty {
                    Section {
                        resumenGeneral
                    }
                }

                ForEach(agrupadosPorMes, id: \.clave) { grupo in
                    Section(grupo.titulo) {
                        ForEach(grupo.entrenos) { entreno in
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
                        }
                    }
                }

                if entrenos.isEmpty {
                    ContentUnavailableView(
                        "Sin entrenos todavía",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Cuando termines tu primer entreno aparecerá aquí.")
                    )
                }
            }
            .navigationTitle("Historial")
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
        HStack {
            columnaResumen("Entrenos", "\(entrenos.count)")
            Divider()
            columnaResumen("Series", "\(entrenos.reduce(0) { $0 + $1.seriesCompletadas })")
            Divider()
            columnaResumen("Volumen", Formato.volumen(entrenos.reduce(0) { $0 + $1.volumenTotal }))
        }
        .frame(height: 44)
    }

    private func columnaResumen(_ titulo: String, _ valor: String) -> some View {
        VStack(spacing: 2) {
            Text(valor)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .monospacedDigit()
            Text(titulo)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
        .foregroundStyle(valor >= 7 ? .red : .orange)
    }

    // MARK: - Agrupación por mes

    private var agrupadosPorMes: [GrupoMes] {
        let calendario = Formato.calendarioES
        var grupos: [GrupoMes] = []
        for entreno in entrenos {
            let componentes = calendario.dateComponents([.year, .month], from: entreno.fechaInicio)
            let clave = (componentes.year ?? 0) * 100 + (componentes.month ?? 0)
            if let ultimo = grupos.last, ultimo.clave == clave {
                grupos[grupos.count - 1].entrenos.append(entreno)
            } else {
                grupos.append(
                    GrupoMes(
                        clave: clave,
                        titulo: Self.tituloMes(entreno.fechaInicio),
                        entrenos: [entreno]
                    )
                )
            }
        }
        return grupos
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
    var entrenos: [Entreno]
}
