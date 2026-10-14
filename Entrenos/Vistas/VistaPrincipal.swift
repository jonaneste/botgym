import SwiftUI
import SwiftData

/// Las cinco pestañas de la app.
struct VistaPrincipal: View {
    @Environment(ControladorEntreno.self) private var controlador
    @Environment(\.modelContext) private var contexto
    @Environment(\.scenePhase) private var fase

    @State private var pestaña: Pestaña = .entreno
    @State private var avisoImportacion: ImportadorAutomatico.Resumen?

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
        .overlay(alignment: .top) {
            if let avisoImportacion {
                AvisoImportacion(resumen: avisoImportacion) {
                    withAnimation { self.avisoImportacion = nil }
                } alVerlas: {
                    withAnimation {
                        self.avisoImportacion = nil
                        pestaña = .rutinas
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: avisoImportacion)
        .task {
            revisarPropuestas()
            ExportadorAutomatico.compartido.exportarAlCambiarDeEstado(contexto: contexto)
        }
        // También al volver del fondo: la rutina puede haber llegado por
        // iCloud con la app abierta, y entonces no hay arranque que la pille.
        .onChange(of: fase) { _, nueva in
            switch nueva {
            case .active:
                revisarPropuestas()
                // Y se vuelca al abrir: si se corrigió algo con la app
                // cerrada —o en otra pantalla que no termina un entreno—, el
                // archivo del Mac estaba viejo y nadie lo decía.
                ExportadorAutomatico.compartido.exportarAlCambiarDeEstado(contexto: contexto)
            case .background:
                // Al salir, que es cuando se acaba de tocar algo. No hace
                // falta esperar al siguiente entreno terminado.
                ExportadorAutomatico.compartido.exportarAlCambiarDeEstado(contexto: contexto)
            default:
                break
            }
        }
    }

    private func revisarPropuestas() {
        guard let resumen = ImportadorAutomatico.revisar(contexto: contexto) else { return }
        withAnimation { avisoImportacion = resumen }
    }
}

/// Aviso de que han entrado rutinas solas.
///
/// Se queda hasta que lo cierras, a diferencia del de récord que se va a los
/// seis segundos: aquí ha cambiado algo en tus datos, y enterarte no puede
/// depender de que estuvieras mirando la pantalla.
struct AvisoImportacion: View {
    let resumen: ImportadorAutomatico.Resumen
    let alCerrar: () -> Void
    let alVerlas: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: huboError ? "exclamationmark.triangle.fill" : "sparkles")
                .font(.title3)
                .foregroundStyle(huboError ? Paleta.aviso : Color.accentColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(titulo)
                    .font(.subheadline.weight(.bold))
                if !resumen.rutinas.isEmpty {
                    Text(resumen.rutinas.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let plan = resumen.plan {
                    Text(resumen.diasDePlan == 1
                         ? "Plan «\(plan)»: 1 día"
                         : "Plan «\(plan)»: \(resumen.diasDePlan) días")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if resumen.borrado.huboAlgo {
                    Text(textoDelBorrado)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if resumen.ejerciciosCreados > 0 {
                    Text(resumen.ejerciciosCreados == 1
                         ? "Y un ejercicio nuevo en la biblioteca"
                         : "Y \(resumen.ejerciciosCreados) ejercicios nuevos en la biblioteca")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if !resumen.fallidos.isEmpty {
                    Text("No pude leer: \(resumen.fallidos.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(Paleta.aviso)
                }
                if !resumen.rutinas.isEmpty {
                    Button("Verlas", action: alVerlas)
                        .font(.caption.weight(.semibold))
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            Button(action: alCerrar) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cerrar aviso")
        }
        .padding(14)
        .background(.regularMaterial, in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .padding(.horizontal, 12)
    }

    /// Solo se pinta como error cuando NO entró nada: un archivo ilegible
    /// junto a una rutina que sí entró no puede teñir el aviso entero de
    /// naranja, porque lo que el usuario lee primero es que algo falló.
    private var huboError: Bool {
        resumen.rutinas.isEmpty && resumen.plan == nil && !resumen.borrado.huboAlgo
    }

    /// Qué se borró, dicho entero: un borrado tiene que poder auditarse de un
    /// vistazo, porque es lo único que no se puede deshacer.
    private var textoDelBorrado: String {
        var partes: [String] = []
        if !resumen.borrado.carpetas.isEmpty {
            partes.append("Carpetas: \(resumen.borrado.carpetas.joined(separator: ", "))")
        }
        if !resumen.borrado.rutinas.isEmpty {
            partes.append("Rutinas: \(resumen.borrado.rutinas.joined(separator: ", "))")
        }
        if !resumen.borrado.ejercicios.isEmpty {
            partes.append("Ejercicios repetidos: \(resumen.borrado.ejercicios.joined(separator: ", "))")
        }
        if resumen.borrado.entrenos > 0 {
            partes.append(
                resumen.borrado.entrenos == 1
                    ? "Y un entreno sin series"
                    : "Y \(resumen.borrado.entrenos) entrenos sin series"
            )
        }
        return partes.joined(separator: " · ")
    }

    private var titulo: String {
        if huboError { return "Llegó algo que no pude leer" }
        if resumen.rutinas.isEmpty, resumen.plan == nil, resumen.borrado.huboAlgo {
            return "Claude hizo limpieza"
        }
        if resumen.rutinas.isEmpty, let plan = resumen.plan {
            return "Claude cargó el plan «\(plan)»"
        }
        let cuantas = resumen.rutinas.count
        let donde = resumen.carpetas.sorted().first
        let base = cuantas == 1 ? "Claude añadió una rutina" : "Claude añadió \(cuantas) rutinas"
        let conCarpeta = donde.map { "\(base) en \($0)" } ?? base
        return resumen.plan == nil ? conCarpeta : "\(conCarpeta), y el plan"
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
