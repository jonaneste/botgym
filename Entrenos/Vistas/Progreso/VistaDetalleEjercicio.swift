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

    private var esTiempo: Bool { ejercicio.tipoRegistro.esTiempo }

    /// En los ejercicios de tiempo el 1RM no significa nada, así que esa
    /// métrica no se ofrece.
    private var metricasDisponibles: [MetricaGrafica] {
        esTiempo ? [.pesoMaximo, .volumen] : MetricaGrafica.allCases
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ejercicio.descripcionCorta)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !ejercicio.gruposSecundarios.isEmpty {
                        Text("También: \(ejercicio.gruposSecundarios.map(\.nombre).joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if records.estaVacio {
                Section {
                    ContentUnavailableView(
                        "Sin datos todavía",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Completa alguna serie de este ejercicio y aquí aparecerán tus récords.")
                    )
                }
            } else {
                Section("Récords") {
                    if let peso = records.pesoMaximo {
                        filaRecord("Peso máximo", Formato.peso(peso), records.fechaPesoMaximo, "scalemass")
                    }
                    if let unRM = records.mejorUnRM {
                        filaRecord("1RM estimado", Formato.peso(unRM), records.fechaMejorUnRM, "arrow.up.circle")
                    }
                    if let tiempo = records.mejorTiempo {
                        filaRecord("Tiempo máximo", "\(tiempo) s", records.fechaMejorTiempo, "timer")
                    }
                    if let volumen = records.mejorVolumenSesion {
                        filaRecord("Mejor sesión", Formato.volumen(volumen), records.fechaMejorVolumen, "chart.bar.fill")
                    }
                }
            }

            if puntos.count >= 2 {
                Section {
                    Picker("Métrica", selection: $metrica) {
                        ForEach(metricasDisponibles) { opcion in
                            Text(opcion.nombre).tag(opcion)
                        }
                    }
                    .pickerStyle(.segmented)

                    GraficaEjercicio(puntos: puntos, metrica: metrica)
                        .frame(height: 200)
                        .padding(.vertical, 6)
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
                }
            }

            if !sesiones.isEmpty {
                Section("Historial") {
                    ForEach(sesiones.sorted { $0.fecha > $1.fecha }, id: \.fecha) { sesion in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(Formato.fechaCorta(sesion.fecha))
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text(Formato.volumen(sesion.volumen))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(resumen(de: sesion))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(ejercicio.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: cargar)
    }

    private func filaRecord(_ titulo: String, _ valor: String, _ fecha: Date?, _ icono: String) -> some View {
        HStack {
            Label(titulo, systemImage: icono)
                .font(.subheadline)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(valor)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                if let fecha {
                    Text(Formato.fechaCorta(fecha))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
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
