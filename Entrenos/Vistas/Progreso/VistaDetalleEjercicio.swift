import SwiftUI
import SwiftData

/// Récords y gráficas de un ejercicio.
struct VistaDetalleEjercicio: View {
    let ejercicio: Ejercicio

    @Environment(\.modelContext) private var contexto

    @State private var records = RecordsEjercicio()
    @State private var puntos: [PuntoGrafica] = []
    @State private var sesiones: [SesionEjercicio] = []
    @State private var metrica: MetricaGrafica = .unRM

    /// Igual que en la pestaña de progreso: el alto acompaña al cuerpo de
    /// letra para que las etiquetas de los ejes no ahoguen la gráfica.
    @ScaledMetric(relativeTo: .caption) private var altoGrafica: CGFloat = 200

    private var esTiempo: Bool { ejercicio.tipoRegistro.esTiempo }

    /// En los ejercicios de tiempo el 1RM no significa nada, así que esa
    /// métrica no se ofrece.
    private var metricasDisponibles: [MetricaGrafica] {
        esTiempo ? [.pesoMaximo, .volumen] : MetricaGrafica.allCases
    }

    var body: some View {
        List {
            ficha
                .filaDesnuda(arriba: 10, abajo: 4)

            if records.estaVacio {
                ContentUnavailableView(
                    "Sin datos todavía",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Completa alguna serie de este ejercicio y aquí aparecerán tus récords.")
                )
                .filaDesnuda(arriba: 12, abajo: 4)
            } else {
                Section("Récords") {
                    // Rejilla de dos columnas y no una lista de filas: un
                    // récord es un número, y en filas el número quedaba a la
                    // derecha en cuerpo de texto, con el mismo peso visual
                    // que su etiqueta.
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(recordsVisibles) { record in
                            tarjetaRecord(record)
                        }
                    }
                    .filaDesnuda(arriba: 4, abajo: 4)
                }
            }

            if puntos.count >= 2 {
                Section {
                    VStack(spacing: 12) {
                        Picker("Métrica", selection: $metrica) {
                            ForEach(metricasDisponibles) { opcion in
                                Text(opcion.nombre).tag(opcion)
                            }
                        }
                        .pickerStyle(.segmented)

                        GraficaEjercicio(puntos: puntos, metrica: metrica)
                            .frame(height: altoGrafica)
                    }
                    .tarjeta()
                    .filaDesnuda(arriba: 4, abajo: 4)
                } header: {
                    Text("Evolución")
                } footer: {
                    Text("El eje vertical no empieza en cero: con cargas parecidas, un eje desde cero aplanaría la línea y no se vería el progreso.")
                }
            } else if !records.estaVacio {
                Section("Evolución") {
                    Text("Hacen falta al menos dos sesiones para dibujar la gráfica.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tarjeta()
                        .filaDesnuda(arriba: 4, abajo: 4)
                }
            }

            if !sesiones.isEmpty {
                Section("Historial") {
                    ForEach(sesionesRecientes) { sesion in
                        filaSesion(sesion)
                            .filaDesnuda(arriba: 3, abajo: 3)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(ejercicio.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: cargar)
    }

    // MARK: - Ficha del ejercicio

    private var ficha: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Pastilla(texto: ejercicio.grupoPrincipal.nombre)
                Pastilla(texto: ejercicio.material.nombre, color: .secondary)
                Spacer(minLength: 0)
            }

            if !ejercicio.gruposSecundarios.isEmpty {
                Text("También trabaja \(ejercicio.gruposSecundarios.map(\.nombre).joined(separator: ", ").lowercased())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !ejercicio.notas.isEmpty {
                Text(ejercicio.notas)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta()
    }

    // MARK: - Récords

    /// Un récord ya listo para pintar. Se arma en una lista para poder
    /// repartirlo en una rejilla sin repetir el bloque cuatro veces.
    private struct Record: Identifiable {
        let id: String
        let titulo: String
        let valor: String
        let fecha: Date?
        let icono: String
    }

    private var recordsVisibles: [Record] {
        var lista: [Record] = []
        if let peso = records.pesoMaximo {
            lista.append(Record(
                id: "peso",
                titulo: "Peso máximo",
                valor: Formato.peso(peso),
                fecha: records.fechaPesoMaximo,
                icono: "scalemass"
            ))
        }
        if let unRM = records.mejorUnRM {
            lista.append(Record(
                id: "unRM",
                titulo: "1RM estimado",
                valor: Formato.peso(unRM),
                fecha: records.fechaMejorUnRM,
                icono: "arrow.up.circle"
            ))
        }
        if let tiempo = records.mejorTiempo {
            lista.append(Record(
                id: "tiempo",
                titulo: "Tiempo máximo",
                valor: "\(tiempo) s",
                fecha: records.fechaMejorTiempo,
                icono: "timer"
            ))
        }
        if let volumen = records.mejorVolumenSesion {
            lista.append(Record(
                id: "volumen",
                titulo: "Mejor sesión",
                valor: Formato.volumen(volumen),
                fecha: records.fechaMejorVolumen,
                icono: "chart.bar.fill"
            ))
        }
        return lista
    }

    private func tarjetaRecord(_ record: Record) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(record.titulo, systemImage: record.icono)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(record.valor)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(record.fecha.map(Formato.fechaCorta) ?? " ")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta(relleno: 12, radio: 14)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Historial

    /// Las sesiones, de la más reciente a la más antigua. El orden se calcula
    /// una vez y no dentro del `ForEach`.
    private var sesionesRecientes: [SesionEjercicio] {
        sesiones.sorted { $0.fecha > $1.fecha }
    }

    private func filaSesion(_ sesion: SesionEjercicio) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(Formato.fechaCorta(sesion.fecha))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(Formato.volumen(sesion.volumen))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(resumen(de: sesion))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tarjeta(relleno: 12)
    }

    private func resumen(de sesion: SesionEjercicio) -> String {
        sesion.seriesEfectivas
            .map {
                Formato.resumenSerie(
                    peso: $0.peso,
                    repeticiones: $0.repeticiones,
                    segundos: $0.segundos,
                    tipo: ejercicio.tipoRegistro
                )
            }
            .joined(separator: "  ·  ")
    }

    private func cargar() {
        let repositorio = RepositorioProgreso(contexto: contexto)
        sesiones = repositorio.sesiones(idEjercicio: ejercicio.idPublico)
        records = ServicioRecords.records(de: sesiones, tipo: ejercicio.tipoRegistro)
        puntos = ServicioRecords.puntosGrafica(de: sesiones, tipo: ejercicio.tipoRegistro)
        if !metricasDisponibles.contains(metrica) {
            metrica = metricasDisponibles.first ?? .pesoMaximo
        }
    }
}
