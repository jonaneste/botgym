import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Exportar el historial, importar rutinas y conectar con Salud.
struct VistaDatos: View {
    @Environment(\.modelContext) private var contexto

    @State private var ajustes: Ajustes?
    @State private var archivoACompartir: ArchivoCompartible?
    @State private var mostrarImportarRutinas = false
    /// Qué se está eligiendo en el selector de archivos. Vive aparte del
    /// booleano de presentación porque el callback lo necesita después de que
    /// la hoja se cierre.
    @State private var modoSelector: ModoSelector = .carpetaClaude
    @State private var mostrarSelector = false
    @State private var mensaje: MensajeDatos?
    @State private var trabajando = false
    @State private var progresoSync: (hechos: Int, total: Int)?
    @State private var pendientesDeSync = 0
    @State private var carpetaClaude: String?
    @State private var ultimaAuto: Date?

    var body: some View {
        List {
            seccionCarpetaClaude

            seccionExportar

            seccionImportarRutinas

            if let ajustes {
                seccionSalud(ajustes)
                seccionCentroDeDatos(ajustes)
                if ajustes.healthKitActivado {
                    seccionCalorias(ajustes)
                }
            }
        }
        .navigationTitle("Datos")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if ajustes == nil { ajustes = Ajustes.cargar(en: contexto) }
            recontarPendientes()
            carpetaClaude = ExportadorAutomatico.compartido.nombreCarpeta
            ultimaAuto = ExportadorAutomatico.compartido.ultimaExportacion
        }
        .sheet(item: $archivoACompartir) { archivo in
            HojaCompartir(elementos: [archivo.url])
        }
        .sheet(isPresented: $mostrarImportarRutinas) {
            VistaImportarRutinas()
        }
        .fileImporter(
            isPresented: $mostrarSelector,
            allowedContentTypes: ModoSelector.tiposAdmitidos,
            allowsMultipleSelection: false
        ) { salida in
            switch modoSelector {
            case .carpetaClaude: configurarCarpetaClaude(salida)
            case .exportDeSalud: importarExportDeSalud(salida)
            }
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

    /// Carpeta donde la app vuelca el JSON para que Claude lo lea por MCP.
    private var seccionCarpetaClaude: some View {
        Section {
            if let nombreCarpeta = carpetaClaude {
                HStack {
                    Label(nombreCarpeta, systemImage: "folder.badge.gearshape")
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                if let ultimaAuto {
                    HStack {
                        Text("Última escritura")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Formato.fechaRelativa(ultimaAuto)) \(Formato.hora(ultimaAuto))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    volcarAhora()
                } label: {
                    Label("Volcar ahora", systemImage: "arrow.down.doc")
                }

                Button(role: .destructive) {
                    ExportadorAutomatico.compartido.olvidarCarpeta()
                    carpetaClaude = nil
                    ultimaAuto = nil
                } label: {
                    Label("Olvidar la carpeta", systemImage: "folder.badge.minus")
                }
            } else {
                Button {
                    modoSelector = .carpetaClaude
                    mostrarSelector = true
                } label: {
                    Label("Elegir carpeta para Claude", systemImage: "folder.badge.plus")
                }
            }
        } header: {
            Text("Carpeta para Claude")
        } footer: {
            Text(carpetaClaude == nil
                 ? "Elige una carpeta de iCloud Drive. La app escribirá ahí un entrenos.json cada vez que termines un entreno, tu Mac lo sincroniza, y el servidor MCP de mcp/ se lo da a Claude para que te aconseje. No hace falta la capability de iCloud: el permiso llega por el selector del sistema."
                 : "La app escribe aquí al terminar cada entreno. En el Mac, apunta el servidor MCP a este mismo archivo; las instrucciones están en mcp/README.md del repositorio.")
        }
    }

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
                modoSelector = .exportDeSalud
                mostrarSelector = true
            } label: {
                Label("Importar carreras desde un archivo", systemImage: "figure.run")
            }
        } header: {
            Text("Carreras")
        } footer: {
            Text("""
            Conectar con Salud lee las carreras que Zepp escribe allí. **Requiere el Apple Developer Program de pago**: Apple no concede esa capability a una cuenta gratuita.

            Sin él, el camino es el archivo: en Salud, foto de perfil → Exportar todos los datos de salud. Sale un exportar.zip; descomprímelo e importa el exportar.xml de dentro.
            """)
        }
    }

    /// Panel del centro de datos: subir el historial a Salud y los ajustes que
    /// lo afectan.
    private func seccionCentroDeDatos(_ ajustes: Ajustes) -> some View {
        Section {
            if let progreso = progresoSync {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Subiendo \(progreso.hechos) de \(progreso.total)…")
                        .font(.subheadline)
                    ProgressView(
                        value: Double(progreso.hechos),
                        total: Double(max(1, progreso.total))
                    )
                }
            } else {
                Button {
                    sincronizarConSalud(ajustes)
                } label: {
                    HStack {
                        Label("Subir el historial a Salud", systemImage: "arrow.up.heart")
                        Spacer()
                        if pendientesDeSync > 0 {
                            Text("\(pendientesDeSync)")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor, in: .capsule)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .disabled(!ajustes.healthKitActivado || pendientesDeSync == 0)
            }

            Toggle("Evitar duplicados del reloj", isOn: Binding(
                get: { ajustes.evitarDuplicadosEnSalud },
                set: { ajustes.evitarDuplicadosEnSalud = $0; try? contexto.save() }
            ))
        } header: {
            Text("Salud como centro de datos")
        } footer: {
            Text(textoPieCentro(ajustes))
        }
    }

    private func textoPieCentro(_ ajustes: Ajustes) -> String {
        if !ajustes.healthKitActivado {
            return "Activa «Conectar con Apple Salud» arriba para poder subir el historial. Zepp ya escribe allí tus carreras; esto pone los entrenos de fuerza al lado, y Salud queda con todo."
        }
        if pendientesDeSync == 0 {
            return "Todos tus entrenos están ya en Salud. Los nuevos suben solos al terminarlos.\n\n«Evitar duplicados» comprueba antes de escribir que no haya un entrenamiento de fuerza de otra app a la misma hora: si entrenas con el Amazfit puesto, Zepp registra el suyo con pulso real y ese es mejor que el mío."
        }
        return "Activar Salud no reescribe el pasado, así que tus \(pendientesDeSync) entrenos anteriores siguen fuera. Esto los sube. Es idempotente: cada entreno recuerda que ya subió, así que puedes tocarlo las veces que quieras."
    }

    /// Estimación de calorías, que solo tiene sentido con Salud conectado.
    private func seccionCalorias(_ ajustes: Ajustes) -> some View {
        Section {
            Toggle("Estimar calorías", isOn: Binding(
                get: { ajustes.estimarCalorias },
                set: { ajustes.estimarCalorias = $0; try? contexto.save() }
            ))

            if ajustes.estimarCalorias {
                HStack {
                    Text("Peso corporal")
                    Spacer()
                    CampoDecimal(marcador: "kg", valor: Binding(
                        get: { ajustes.pesoCorporal },
                        set: { ajustes.pesoCorporal = $0; try? contexto.save() }
                    ))
                    .frame(width: 70)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 8))
                    Text("kg").foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Intensidad (MET)")
                        Spacer()
                        Text(Formato.numeroCorto(ajustes.metFuerza))
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { ajustes.metFuerza },
                            set: { ajustes.metFuerza = $0; try? contexto.save() }
                        ),
                        in: EstimadorEnergia.metMinimo...EstimadorEnergia.metMaximo,
                        step: 0.5
                    )
                }

                if let ejemplo = EstimadorEnergia.kilocalorias(
                    duracion: 75 * 60,
                    pesoCorporal: ajustes.pesoCorporal,
                    met: EstimadorEnergia.metValido(ajustes.metFuerza)
                ) {
                    Label(
                        "Una sesión de 75 min saldría a \(Int(ejemplo)) kcal",
                        systemImage: "flame"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Calorías")
        } footer: {
            Text("Apagado por defecto a propósito. Si entrenas con el reloj puesto, Zepp escribe las calorías reales y estimar sobra. Sin esto, el entreno aparece en Salud con duración pero sin energía, así que no suma al anillo de movimiento.\n\nLa fórmula es MET × peso × horas, que es el estándar. 3,5 es esfuerzo ligero, 6 es alto; 4,5 es una sesión de hipertrofia normal con descansos. Sin peso corporal no se estima nada.")
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

    private func configurarCarpetaClaude(_ salida: Result<[URL], Error>) {
        switch salida {
        case .failure(let fallo):
            mensaje = MensajeDatos(titulo: "No se pudo elegir la carpeta", detalle: fallo.localizedDescription)
        case .success(let urls):
            guard let url = urls.first else { return }
            guard esCarpeta(url) != false else {
                mensaje = MensajeDatos(
                    titulo: "Eso es un archivo",
                    detalle: "Hay que elegir una CARPETA, no un archivo: la app escribe «entrenos.json» dentro de ella."
                )
                return
            }
            do {
                try ExportadorAutomatico.compartido.configurar(carpeta: url)
                carpetaClaude = ExportadorAutomatico.compartido.nombreCarpeta
                // Se vuelca ya, para que no haya que esperar al siguiente
                // entreno para comprobar que funciona.
                volcarAhora()
            } catch {
                mensaje = MensajeDatos(
                    titulo: "No se pudo guardar el permiso",
                    detalle: "\(error.localizedDescription)\n\nPrueba con otra carpeta: algunas ubicaciones no admiten acceso permanente."
                )
            }
        }
    }

    private func volcarAhora() {
        Task { await volcarAhoraEsperando() }
    }

    private func volcarAhoraEsperando() async {
        trabajando = true
        defer { trabajando = false }
        switch await ExportadorAutomatico.compartido.exportarFueraDelPrincipal(contexto: contexto) {
        case .escrito(let url):
            ultimaAuto = ExportadorAutomatico.compartido.ultimaExportacion
            mensaje = MensajeDatos(
                titulo: "Escrito",
                detalle: "\(url.lastPathComponent) en «\(url.deletingLastPathComponent().lastPathComponent)».\n\nEn el Mac, apunta el servidor MCP a este archivo."
            )
        case .sinCarpeta:
            mensaje = MensajeDatos(titulo: "Sin carpeta", detalle: "Elige primero una carpeta.")
        case .fallo(let detalle):
            mensaje = MensajeDatos(titulo: "No se pudo escribir", detalle: detalle)
        }
    }

    /// ¿Es una carpeta lo que se eligió? `nil` si el sistema no lo dice.
    ///
    /// Los dos sitios que la usan comparan contra `false` y contra `true`, no
    /// contra `nil`: ante la duda se sigue adelante. Un falso positivo aquí
    /// dejaría la función inalcanzable, que es exactamente lo que se quería
    /// evitar al dejar de atar los tipos admitidos al modo del selector.
    private func esCarpeta(_ url: URL) -> Bool? {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory
    }

    private func recontarPendientes() {
        pendientesDeSync = SincronizadorSalud(contexto: contexto).pendientes().count
    }

    private func sincronizarConSalud(_ ajustes: Ajustes) {
        Task {
            progresoSync = (0, pendientesDeSync)
            defer { progresoSync = nil }

            let sincronizador = SincronizadorSalud(contexto: contexto)
            let resultado = await sincronizador.sincronizar(ajustes: ajustes) { hechos, total in
                progresoSync = (hechos, total)
            }
            recontarPendientes()

            var partes: [String] = []
            if resultado.subidos > 0 {
                partes.append("\(resultado.subidos) \(resultado.subidos == 1 ? "entreno subido" : "entrenos subidos").")
            }
            if resultado.omitidosPorDuplicado > 0 {
                partes.append("\(resultado.omitidosPorDuplicado) omitidos porque el reloj ya los había registrado.")
            }
            if resultado.fallidos > 0 {
                partes.append("\(resultado.fallidos) fallaron: \(resultado.primerError ?? "error desconocido")")
            }
            if partes.isEmpty {
                partes.append("No había nada pendiente.")
            }

            mensaje = MensajeDatos(
                titulo: resultado.fallidos > 0 ? "Sincronización incompleta" : "Salud actualizada",
                detalle: partes.joined(separator: "\n")
            )
        }
    }

    private func importarExportDeSalud(_ resultado: Result<[URL], Error>) {
        switch resultado {
        case .failure(let error):
            mensaje = MensajeDatos(titulo: "No se pudo abrir", detalle: error.localizedDescription)

        case .success(let urls):
            guard let url = urls.first else { return }
            guard esCarpeta(url) != true else {
                mensaje = MensajeDatos(
                    titulo: "Eso es una carpeta",
                    detalle: "Hay que elegir el archivo «exportar.xml» que sale al descomprimir la exportación de Salud."
                )
                return
            }
            Task {
                trabajando = true
                defer { trabajando = false }
                do {
                    // El archivo llega del selector del sistema: hay que pedir
                    // acceso explícito antes de leerlo.
                    let concedido = url.startAccessingSecurityScopedResource()
                    defer { if concedido { url.stopAccessingSecurityScopedResource() } }

                    // Fuera del hilo principal: recorrer un export de
                    // varios cientos de megas son decenas de segundos, y
                    // hacerlo aquí mismo congelaba la interfaz hasta que el
                    // sistema mataba la app por no responder. El permiso de
                    // lectura sigue abierto durante el await, porque el
                    // `defer` de arriba no corre hasta que esto vuelve.
                    let carreras = try await LectorExportHealth.leerFueraDelPrincipal(urlArchivo: url)
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

/// Qué se va a elegir en el selector de archivos.
///
/// Hace falta porque la pantalla tiene dos selectores distintos y SwiftUI no
/// admite dos `.fileImporter` en la misma vista: se usa uno y el modo decide
/// qué tipos admite y a dónde va el resultado.
enum ModoSelector {
    case carpetaClaude
    case exportDeSalud

    /// Los tipos NO dependen del modo, a propósito.
    ///
    /// Hacerlos depender del modo acoplaba la configuración del selector a un
    /// estado que cambia en el mismo gesto que lo presenta, y si SwiftUI
    /// presentase con el valor anterior, el selector se abriría pidiendo
    /// carpetas cuando toca elegir el XML y el archivo saldría en gris, sin
    /// forma de seguir. Admitiendo siempre los dos, lo que se eligió se
    /// comprueba después: lo peor que pasa es un mensaje de error claro en
    /// lugar de una función inalcanzable.
    static let tiposAdmitidos: [UTType] = [.folder, .xml]
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
