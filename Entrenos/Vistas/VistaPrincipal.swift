import SwiftUI

/// Pestañas de la app. En la fase 0 son marcadores de posición: lo único que
/// se comprueba aquí es que el proyecto abre, compila y arranca en el iPhone.
struct VistaPrincipal: View {
    var body: some View {
        TabView {
            PlaceholderFase(
                titulo: "Entreno",
                icono: "figure.strengthtraining.traditional",
                detalle: "Aquí empezarás un entreno desde una rutina o en vacío.",
                fase: 1
            )
            .tabItem { Label("Entreno", systemImage: "figure.strengthtraining.traditional") }

            PlaceholderFase(
                titulo: "Rutinas",
                icono: "list.bullet.rectangle",
                detalle: "Tus rutinas organizadas en carpetas, con superseries.",
                fase: 1
            )
            .tabItem { Label("Rutinas", systemImage: "list.bullet.rectangle") }

            PlaceholderFase(
                titulo: "Historial",
                icono: "clock.arrow.circlepath",
                detalle: "Entrenos pasados, con detalle, edición y borrado.",
                fase: 1
            )
            .tabItem { Label("Historial", systemImage: "clock.arrow.circlepath") }

            PlaceholderFase(
                titulo: "Progreso",
                icono: "chart.xyaxis.line",
                detalle: "Récords, 1RM estimado y series semanales por grupo muscular.",
                fase: 2
            )
            .tabItem { Label("Progreso", systemImage: "chart.xyaxis.line") }

            PlaceholderFase(
                titulo: "Ajustes",
                icono: "gearshape",
                detalle: "Incrementos de carga, mancuernas disponibles y objetivos semanales.",
                fase: 2
            )
            .tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
    }
}

/// Pantalla temporal que indica en qué fase llega cada parte.
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
                    .foregroundStyle(.primary)
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

#Preview {
    VistaPrincipal()
}
