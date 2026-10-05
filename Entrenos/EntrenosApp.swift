import SwiftUI
import SwiftData

@main
struct EntrenosApp: App {
    private let contenedor: ModelContainer
    @State private var controlador: ControladorEntreno

    init() {
        do {
            contenedor = try EsquemaDatos.contenedor()
        } catch {
            // Se cae a propósito en lugar de recurrir a una base en memoria:
            // un registro de entrenos que parece guardar y no guarda es peor
            // que uno que no arranca. Si esto salta, es un fallo de esquema.
            fatalError("No se pudo abrir la base de datos: \(error)")
        }
        _controlador = State(initialValue: ControladorEntreno(contexto: contenedor.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            VistaPrincipal()
                .environment(controlador)
                .task {
                    CargadorSemilla.sembrarSiHaceFalta(contexto: contenedor.mainContext)
                    controlador.reanudarSiProcede()
                    await GestorNotificaciones.shared.solicitarPermiso()
                }
        }
        .modelContainer(contenedor)
    }
}
