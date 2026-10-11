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
                    Label("Rutinas", systemImage: "list.bullet.rectangle.fill")
                }

            VistaHistorial()
                .tag(Pestaña.historial)
                .tabItem {
                    Label("Historial", systemImage: "clock.arrow.circlepath")
                }

            VistaProgreso()
                .tag(Pestaña.progreso)
                .tabItem {
                    Label("Progreso", systemImage: "chart.bar.fill")
                }

            VistaAjustes()
                .tag(Pestaña.ajustes)
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape.fill")
                }
        }
        .conBarraDeEntreno(visible: controlador.hayEntrenoActivo && pestaña != .entreno) {
            pestaña = .entreno
        }
    }
}


private extension View {
    /// Coloca la barra de entreno activo encima de la barra de pestañas.
    ///
    /// Hacen falta dos caminos porque la barra de pestañas cambió de sitio.
    /// Hasta iOS 18 está pegada al borde inferior y `safeAreaInset` la
    /// respeta; desde iOS 26 flota por encima del contenido, y ese mismo
    /// `safeAreaInset` dibujaba la barra DEBAJO de ella: tapaba «Entreno»,
    /// «Rutinas» y el resto de etiquetas. `tabViewBottomAccessory` es el
    /// hueco que el sistema reserva justo encima, que es donde va.
    //
    // El `#if` es por el compilador, no por el dispositivo. `#available`
    // decide en ejecución, pero `tabViewBottomAccessory` tiene que EXISTIR al
    // compilar, y con el SDK de iOS 18 no existe: CI, que va con Xcode 16, no
    // compilaba. Así el archivo vale para las dos versiones de Xcode.
    @ViewBuilder
    func conBarraDeEntreno(
        visible: Bool,
        alTocar: @escaping () -> Void
    ) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.tabViewBottomAccessory {
                if visible {
                    BarraEntrenoActivo(alTocar: alTocar)
                }
            }
        } else {
            self.conBarraEnElMargen(visible: visible, alTocar: alTocar)
        }
        #else
        self.conBarraEnElMargen(visible: visible, alTocar: alTocar)
        #endif
    }

    /// El camino de siempre: la barra entra en el área segura inferior, que
    /// hasta iOS 18 es justo encima de la barra de pestañas.
    @ViewBuilder
    func conBarraEnElMargen(
        visible: Bool,
        alTocar: @escaping () -> Void
    ) -> some View {
        self.safeAreaInset(edge: .bottom) {
            if visible {
                BarraEntrenoActivo(alTocar: alTocar)
            }
        }
    }
}
