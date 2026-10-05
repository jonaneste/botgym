import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Exportar el historial, importar rutinas y conectar con Salud.
struct VistaDatos: View {
    @Environment(\.modelContext) private var contexto

    @State private var ajustes: Ajustes?
    @State private var archivoACompartir: ArchivoCompartible?
    @State private var mostrarImportarRutinas = false
    @State private var mostrarSelectorHealth = false
    @State private var mensaje: MensajeDatos?
    @State private var trabajando = false

    var body: some View {
        List {
            seccionExportar

            seccionImportarRutinas

            if let ajustes {
                seccionSalud(ajustes)
            }
        }
        .navigationTitle("Datos")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if ajustes == nil { ajustes = Ajustes.cargar(en: contexto) } }
        .sheet(item: $archivoACompartir) { archivo in
            HojaCompartir(elementos: [archivo.url])
        }
        .sheet(isPresented: $mostrarImportarRutinas) {
            VistaImportarRutinas()
        }
        .fileImporter(
            isPresented: $mostrarSelectorHealth,
            allowedContentTypes: [.xml],
            allowsMultipleSelection: false
        ) { resultado in
            importarExportDeSalud(resultado)
        }
        .alert(
            mensaje?.titulo ?? "",
            isPresented: Binding(
                get: { mensaje != nil },
                set: { presentado in if !presentado { mensaje = nil } }
            ),
            presenting: mensaje
        ) { _ in
            Button("Vale", role: .cancel) { mensaje = nil }
        } message: { aviso in
            Text(aviso.detalle)
        }
        .overlay {
            if trabajando {
                ProgressView("Procesando…")
                    .padding(24)
                    .background(.regularMaterial, in: .rect(cornerRadius: 14))
            }
        }
    }

    // MARK: - Exportar

    private var seccionExportar: some View {
        Section {
            Button { exportar(.json) } label: {
                Label("Historial completo (JSON)", systemImage: "doc.badge.arrow.up")
            }
            Button { exportar(.csv) } label: {
                Label("Historial completo (CSV)", systemImage: "tablecells")
            }
            Button { exportar(.rutinas) } label: {
                Label("Solo las rutinas (JSON)", systemImage: "list.bullet.rectangle.portrait")
            }
        } header: {
            Text("Exportar")
        } footer: {
            Text("El JSON lleva todo: ejercicios, rutinas y cada serie de cada entreno. El CSV es una fila por serie, con punto y coma y coma decimal, que es lo que espera Excel en español. «Solo las rutinas» sale en el mismo formato que lee el importador, así que puedes pasárselo a una IA y pedirle variaciones.")
        }
    }

    private enum TipoExportacion { case json, csv, rutinas }

    private func exportar(_ tipo: TipoExportacion) {
        let servicio = ServicioExportacion(contexto: contexto)
        do {
            let url: URL
            switch tipo {
            case .json: url = try servicio.archivoJSON()
            case .csv: url = try servicio.archivoCSV()
            case .rutinas: url = try servicio.archivoRutinasJSON()
            }
            archivoACompartir = ArchivoCompartible(url: url)
        } catch {
            mensaje = MensajeDatos(
                titulo: "No se pudo exportar",
                detalle: error.localizedDescription
            )
        }
    }

    // MARK: - Importar rutinas

    private var seccionImportarRutinas: some View {
        Section {
            Button {
                mostrarImportarRutinas = true
            } label: {
                Label("Importar rutinas desde JSON", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Importar")
        } footer: {
            Text("Pega el JSON o elige un archivo. El formato está documentado en docs/ESQUEMA-RUTINA-JSON.md del repositorio: pásaselo entero a una IA y te devolverá algo que la app lee.")
        }
    }

    // MARK: - Salud

    private func seccionSalud(_ ajustes: Ajustes) -> some View {
        Section {
            Toggle("Conectar con Apple Salud", isOn: Binding(
                get: { ajustes.healthKitActivado },
                set: { activar in
                    if activar {
                        activarHealthKit(ajustes)
                    } else {
                        ajustes.healthKitActivado = false
                        try? contexto.save()
                    }
                }
            ))

            Button {
                mostrarSelectorHealth = true
            } label: {
                Label("Importar carreras desde un archivo", systemImage: "figure.run")
            }
        } header: {
            Text("Carreras")
        } footer: {
            Text("""
            Conectar con Salud lee las carreras que Zepp escribe allí, y guarda tus entrenos de fuerza como «Traditional Strength Training». **Requiere el Apple Developer Program de pago**: Apple no concede esa capability a una cuenta gratuita.

            Sin él, el camino es el archivo: en Salud, foto de perfil → Exportar todos los datos de salud. Sale un exportar.zip; descomprímelo e importa el exportar.xml de dentro.
            """)
        }
    }

    private func activarHealthKit(_ ajustes: Ajustes) {
        Task {
            trabajando = true
            defer { trabajando = false }
            do {
                try await GestorHealthKit.shared.solicitarPermiso()
                ajustes.healthKitActivado = true
                try? contexto.save()
            } catch {
                ajustes.healthKitActivado = false
                try? contexto.save()
                mensaje = MensajeDatos(
                    titulo: "No se pudo conectar con Salud",
                    detalle: "\(error.localizedDescription)\n\nSi la app se instaló con un Apple ID gratuito, esto no puede funcionar: usa la importación por archivo."
                )
            }
        }
    }

    private func importarExportDeSalud(_ resultado: Result<[URL], Error>) {
        switch resultado {
        case .failure(let error):
            mensaje = MensajeDatos(titulo: "No se pudo abrir", detalle: error.localizedDescription)

        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                trabajando = true
                defer { trabajando = false }
                do {
                    // El archivo llega del selector del sistema: hay que pedir
                    // acceso explícito antes de leerlo.
                    let concedido = url.startAccessingSecurityScopedResource()
                    defer { if concedido { url.stopAccessingSecurityScopedResource() } }

                    let lector = LectorExportHealth()
                    let carreras = try lector.leer(urlArchivo: url)
                    CacheCarreras.compartida.guardar(carreras)
                    mensaje = MensajeDatos(
                        titulo: carreras.isEmpty ? "Ninguna carrera" : "Carreras importadas",
                        detalle: carreras.isEmpty
                            ? "El archivo tenía entrenamientos, pero ninguno de tipo carrera."
                            : "Se han leído \(carreras.count) carreras. Ya aparecen en el historial."
                    )
                } catch {
                    mensaje = MensajeDatos(
                        titulo: "No se pudo importar",
                        detalle: error.localizedDescription
                    )
                }
            }
        }
    }
}

/// Aviso simple para las alertas de esta pantalla.
struct MensajeDatos: Identifiable {
    let id = UUID()
    let titulo: String
    let detalle: String
}

/// Envoltorio para poder pasar una URL a `.sheet(item:)`.
///
/// Se prefiere esto a conformar `URL` a `Identifiable` retroactivamente: una
/// conformidad de un tipo de la librería estándar a un protocolo de la
/// librería estándar puede chocar con la que añada Apple más adelante.
struct ArchivoCompartible: Identifiable {
    let id = UUID()
    let url: URL
}

/// La hoja de compartir de iOS.
struct HojaCompartir: UIViewControllerRepresentable {
    let elementos: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: elementos, applicationActivities: nil)
    }

    func updateUIViewController(_ controlador: UIActivityViewController, context: Context) {}
}
