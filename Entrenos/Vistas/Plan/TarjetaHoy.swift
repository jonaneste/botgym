import SwiftUI
import SwiftData

/// Lo que toca hoy según el plan, arriba de la pantalla de entrenar.
///
/// Está aquí y no detrás de una pestaña porque es la pregunta con la que se
/// abre la app —«¿qué hago hoy?»— y porque la app tiene ya cinco pestañas: la
/// guía de Apple no deja una sexta sin meter el botón de «más», que esconde
/// justo lo que más se mira.
struct TarjetaHoy: View {
    let dia: DiaPlanificado
    /// La rutina que cubre el gimnasio de hoy, si existe en la app.
    let rutina: Rutina?
    let alEmpezar: (Rutina) -> Void

    @Environment(\.modelContext) private var contexto
    @Environment(ControladorEntreno.self) private var controlador

    @State private var mostrarCarrera = false

    private var color: Color {
        switch dia.tipo {
        case .competicion: return Paleta.record
        case .carrera, .gimnasioYCarrera: return Paleta.carrera
        case .gimnasio: return Paleta.acento
        case .descanso, .turismo: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: dia.tipo.icono)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.16), in: .rect(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 2) {
                    Text(Formato.capitalizarPrimera(Formato.nombreDiaSemana(dia.fecha)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(dia.titulo)
                        .font(.headline)
                        .strikethrough(dia.hecho, color: .secondary)
                }

                Spacer(minLength: 0)

                if dia.hecho {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Paleta.logrado)
                        .accessibilityLabel("Hecho")
                }
            }

            if let km = dia.kilometrosAEnseñar {
                Label("\(Formato.numeroCorto(km)) km", systemImage: "figure.run")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Paleta.carrera)
            }

            if !dia.notas.isEmpty {
                Text(dia.notas)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !dia.hecho {
                acciones
            }
        }
        .tarjeta()
        // El filo del color del día: lo que distingue de un vistazo un día de
        // gimnasio de una tirada larga sin tener que leer.
        .overlay(alignment: .leading) {
            Capsule()
                .fill(color)
                .frame(width: 4)
                .padding(.vertical, 10)
                .padding(.leading, 2)
        }
    }

    @ViewBuilder
    private var acciones: some View {
        HStack(spacing: 8) {
            if let rutina, controlador.entreno == nil {
                Button {
                    alEmpezar(rutina)
                } label: {
                    Label("Empezar", systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
            }

            if dia.tipo.tieneCarrera {
                Button {
                    mostrarCarrera = true
                } label: {
                    Label("Anotar carrera", systemImage: "figure.run")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)
                .tint(Paleta.carrera)
            } else if !dia.tipo.esDescanso {
                Button {
                    RepositorioPlan(contexto: contexto).marcar(dia, hecho: true)
                } label: {
                    Label("Marcar hecho", systemImage: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)
            }
        }
        .sheet(isPresented: $mostrarCarrera) {
            VistaAnotarCarrera(dia: dia) { kilometros, minutos in
                RepositorioPlan(contexto: contexto).marcar(dia, hecho: true, kilometros: kilometros)
                if minutos > 0 {
                    RepositorioCarreras(contexto: contexto).anotar(
                        fecha: dia.fecha,
                        kilometros: kilometros,
                        minutos: minutos
                    )
                }
            }
        }
    }
}
