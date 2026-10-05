import SwiftUI
import SwiftData

/// Las cinco pestañas de la app.
struct VistaPrincipal: View {
    @Environment(ControladorEntreno.self) private var controlador

    @State private var pestaña: Pestaña = .entreno

    enum Pestaña: Hashable {
        case entreno, rutinas, historial, progreso, ajustes
    }

    var body: some View {
        TabView(selection: $pestaña) {
            VistaEntrenoInicio()
                .tag(Pestaña.entreno)
                .tabItem {
                    Label("Entreno", systemImage: "figure.strengthtraining.traditional")
                }

            VistaRutinas()
                .tag(Pestaña.rutinas)
                .tabItem {
                    Label("Rutinas", systemImage: "list.bullet.rectangle")
                }

            VistaHistorial()
                .tag(Pestaña.historial)
                .tabItem {
                    Label("Historial", systemImage: "clock.arrow.circlepath")
                }

            VistaProgreso()
                .tag(Pestaña.progreso)
                .tabItem {
                    Label("Progreso", systemImage: "chart.xyaxis.line")
                }

            VistaAjustes()
                .tag(Pestaña.ajustes)
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape")
                }
        }
        .safeAreaInset(edge: .bottom) {
            // Barra que recuerda que hay un entreno abierto desde cualquier
            // pestaña, y lleva de vuelta a él con un toque.
            if controlador.hayEntrenoActivo && pestaña != .entreno {
                BarraEntrenoActivo { pestaña = .entreno }
            }
        }
    }
}
