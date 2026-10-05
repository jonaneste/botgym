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

            PlaceholderFase(
                titulo: "Progreso",
                icono: "chart.xyaxis.line",
                detalle: "Récords, 1RM estimado, gráficas y series semanales por grupo muscular.",
                fase: 2
            )
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

/// Pantalla temporal para lo que llega en fases posteriores.
struct PlaceholderFase: View {
    let titulo: String
    let icono: String
    let detalle: String
    let fase: Int

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: icono)
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text(detalle)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("Llega en la fase \(fase).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(titulo)
        }
    }
}
