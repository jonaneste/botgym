import SwiftUI

/// Sugerencia de doble progresión bajo el nombre del ejercicio.
///
/// Si propone una carga o un tiempo concretos, toda la fila es un botón que lo
/// aplica a las series pendientes. Con el móvil en el banco, eso es un toque en
/// lugar de teclear el peso cuatro veces.
struct VistaSugerencia: View {
    let sugerencia: SugerenciaProgresion
    let ejercicio: EjercicioEntreno

    @Environment(ControladorEntreno.self) private var controlador

    var body: some View {
        switch sugerencia.accion {
        case .subirPeso(let nuevoPeso):
            fila(
                icono: "arrow.up.circle.fill",
                titulo: "Sube a \(Formato.peso(nuevoPeso))",
                accion: { controlador.aplicarPeso(nuevoPeso, a: ejercicio) }
            )

        case .subirTiempo(let segundos):
            fila(
                icono: "arrow.up.circle.fill",
                titulo: "Sube a \(segundos) s",
                accion: { controlador.aplicarSegundos(segundos, a: ejercicio) }
            )

        case .mantener(let peso, let objetivo):
            fila(
                icono: "equal.circle.fill",
                titulo: peso > 0
                    ? "Mantén \(Formato.peso(peso)), busca \(objetivo)"
                    : "Busca \(objetivo)",
                accion: peso > 0 ? { controlador.aplicarPeso(peso, a: ejercicio) } : nil
            )

        case .ampliarRango:
            fila(icono: "arrow.up.left.and.arrow.down.right.circle.fill",
                 titulo: "Toca ampliar el rango", accion: nil)

        case .primeraVez:
            fila(icono: "sparkles", titulo: "Primera vez", accion: nil)

        case .sinRango:
            EmptyView()
        }
    }

    @ViewBuilder
    private func fila(icono: String, titulo: String, accion: (() -> Void)?) -> some View {
        let contenido = HStack(spacing: 6) {
            Image(systemName: icono)
                .font(.caption)
                .foregroundStyle(Paleta.progresion)
            Text(titulo)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
            if accion != nil {
                Text("· aplicar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Paleta.progresion.opacity(0.12), in: .rect(cornerRadius: 8))

        if let accion {
            Button(action: accion) { contenido }
                .buttonStyle(.plain)
                .accessibilityHint(sugerencia.motivo)
        } else {
            contenido
                .accessibilityHint(sugerencia.motivo)
        }
    }
}

/// Aviso flotante de récord batido.
struct VistaAvisoRecord: View {
    let aviso: AvisoRecord
    let alCerrar: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundStyle(Paleta.record)

            VStack(alignment: .leading, spacing: 2) {
                Text(aviso.titulo)
                    .font(.subheadline.weight(.bold))
                Text(aviso.nombreEjercicio)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(aviso.detalle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                .strokeBorder(.yellow.opacity(0.5), lineWidth: 1)
        }
        .shadow(radius: 8, y: 4)
        .padding(.horizontal, 12)
    }
}
