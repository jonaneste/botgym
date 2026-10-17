import SwiftUI

/// Una fila de serie dentro del entreno en curso.
///
/// Pensada para usarse con una mano y el móvil apoyado: la casilla de
/// completada ocupa toda la altura de la fila por el lado derecho, y el peso de
/// la serie anterior se copia tocando el texto gris de la izquierda.
struct FilaSerie: View {
    let serie: SerieRegistrada
    let ejercicio: EjercicioEntreno
    let serieAnterior: SerieValor?
    let ajustes: Ajustes

    @Environment(ControladorEntreno.self) private var controlador
    @Environment(\.dynamicTypeSize) private var tamañoTexto
    @Environment(\.colorScheme) private var esquemaColor

    /// El tamaño de la casilla de completada crece con el ajuste de texto del
    /// sistema. Con `.system(size: 30)` a pelo se quedaba igual de pequeña
    /// aunque el usuario pidiera texto grande, y es la acción que más se usa.
    @ScaledMetric(relativeTo: .title) private var ladoCasilla: CGFloat = 32

    private var tipo: TipoRegistro { ejercicio.tipoRegistro }

    var body: some View {
        HStack(spacing: 10) {
            indiceSerie

            VStack(alignment: .leading, spacing: 2) {
                campos
                textoAnterior
            }

            casillaCompletada
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(fondo, in: .rect(cornerRadius: 14))
        // El filo verde marca la serie hecha por el borde entero y no solo
        // por el color de fondo, que con poca luz en el gimnasio casi no se
        // distingue del gris.
        .overlay {
            if serie.completada {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Paleta.logrado.opacity(0.45), lineWidth: 1)
            }
        }
        .animacion(Muelles.firme, value: serie.completada)
    }

    /// Cifras que conviene mirar dos veces, con el criterio del núcleo.
    private var sospechas: [SospechaSerie] {
        RevisionSerie.sospechas(de: serie.valor, tipo: tipo)
    }

    private var repsImprobables: Bool { sospechas.contains(.repeticiones) }

    private var rirImprobable: Bool { sospechas.contains(.rir) }

    private func fondoCampo(_ sospechoso: Bool, normal: Color) -> Color {
        sospechoso ? Paleta.aviso.opacity(0.18) : normal
    }

    /// 0,14 de verde sobre blanco se ve; sobre el fondo oscuro no, y el tinte
    /// de fila entera es la pista que permite contar de un vistazo cuántas
    /// series llevas. En oscuro hace falta más cuerpo.
    private var fondo: Color {
        serie.completada
            ? Paleta.logrado.opacity(esquemaColor == .dark ? 0.22 : 0.14)
            : Color(.secondarySystemGroupedBackground)
    }

    // MARK: - Piezas

    private var indiceSerie: some View {
        Group {
            if serie.esCalentamiento {
                Image(systemName: "flame.fill")
                    .font(.footnote)
                    // Va sobre un círculo del mismo naranja al 16 %: en claro,
                    // el naranja del sistema encima de eso no se ve.
                    .foregroundStyle(Paleta.calentamientoTexto)
            } else {
                Text("\(numeroSerieEfectiva)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(serie.completada ? Paleta.logrado : .secondary)
            }
        }
        .frame(width: 30, height: 30)
        .background(
            Circle().fill(
                serie.esCalentamiento
                    ? Paleta.calentamiento.opacity(0.16)
                    : Color(.tertiarySystemFill)
            )
        )
    }

    /// Número que se muestra: las de calentamiento no cuentan.
    private var numeroSerieEfectiva: Int {
        let previas = ejercicio.seriesOrdenadas
            .prefix(while: { $0.orden < serie.orden })
            .filter { !$0.esCalentamiento }
            .count
        return previas + 1
    }

    /// Peso × repeticiones y el RIR.
    ///
    /// En una sola fila mientras caben. Los tres campos tienen anchos mínimos
    /// (62 + 56 + 46) que suman 164 pt, y con el número de serie y la casilla
    /// la fila pide unos 294 pt: entra de sobra a tamaño normal, pero en los
    /// tamaños de accesibilidad los campos usan `.title3`, que crece, y como un
    /// `HStack` no parte líneas el resultado era recortar o empujar la casilla
    /// de completada fuera de la pantalla. Ahí se pasa a dos filas.
    @ViewBuilder
    private var campos: some View {
        if tamañoTexto.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    campoPeso
                    Text("×").foregroundStyle(.secondary)
                    campoRepeticiones
                }
                campoRIR
            }
        } else {
            HStack(spacing: 8) {
                campoPeso
                Text("×").foregroundStyle(.secondary)
                campoRepeticiones
                campoRIR
            }
        }
    }

    private var campoPeso: some View {
        CampoDecimal(marcador: "kg", valor: Binding(
            get: { serie.peso },
            set: { serie.peso = $0 }
        ))
        .frame(minWidth: 62)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))
    }

    @ViewBuilder
    private var campoRepeticiones: some View {
        if tipo.esTiempo {
            CampoEntero(marcador: "s", valor: Binding(
                get: { serie.segundos ?? 0 },
                set: { serie.segundos = $0 }
            ))
            .frame(minWidth: 56)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))
        } else {
            CampoEntero(marcador: "reps", valor: Binding(
                get: { serie.repeticiones },
                set: { serie.repeticiones = $0 }
            ))
            .frame(minWidth: 56)
            .padding(.vertical, 8)
            // No se bloquea: alguien puede hacer de verdad 50 repeticiones a
            // peso corporal. Solo se señala, porque el dedazo típico —«12» que
            // sale «127»— pasaba sin que nada lo dijera y se comía la gráfica
            // del ejercicio.
            .background(
                fondoCampo(repsImprobables, normal: Color(.tertiarySystemFill)),
                in: .rect(cornerRadius: 10)
            )
            .marcaDeAviso(repsImprobables ? .repeticiones : nil)
        }
    }

    private var campoRIR: some View {
        CampoEnteroOpcional(marcador: "RIR", valor: Binding(
            get: { serie.rir },
            set: { serie.rir = $0 }
        ))
        .frame(minWidth: 46)
        .padding(.vertical, 8)
        .background(
            fondoCampo(rirImprobable, normal: Color(.quaternarySystemFill)),
            in: .rect(cornerRadius: 10)
        )
        .marcaDeAviso(rirImprobable ? .rir : nil)
    }

    @ViewBuilder
    private var textoAnterior: some View {
        if let serieAnterior {
            Button {
                controlador.copiarDeAnterior(serie, de: ejercicio)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.down")
                        .font(.caption2)
                    Text("Anterior: \(Formato.resumenSerie(peso: serieAnterior.peso, repeticiones: serieAnterior.repeticiones, segundos: serieAnterior.segundos, tipo: tipo))")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                // 44 pt de alto, no los ~24 que daban `.caption` y 4 de
                // relleno. Es el gesto que más se repite con el móvil en el
                // banco —copiar la serie anterior de un toque— y era el blanco
                // más pequeño de la pantalla, por debajo incluso del mínimo
                // absoluto de 28 pt que pide la guía de Apple.
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Copia el peso y las repeticiones de la última vez")
        }
        // Sin serie anterior no se escribe nada: la cabecera del ejercicio ya
        // lleva su pastilla de «Primera vez», y repetirlo en cada fila eran
        // cuatro líneas idénticas diciendo lo mismo.
    }

    private var casillaCompletada: some View {
        Button {
            controlador.alternarCompletada(serie, de: ejercicio, ajustes: ajustes)
        } label: {
            Image(systemName: serie.completada ? "checkmark.circle.fill" : "circle")
                .font(.system(size: ladoCasilla))
                .foregroundStyle(serie.completada ? Paleta.logrado : Color.secondary)
                .symbolEffect(.bounce, value: serie.completada)
                .frame(minWidth: 48, minHeight: 48)
                .contentShape(.rect)
        }
        .buttonStyle(BotonPulsable(escala: 0.9))
        .accessibilityLabel(serie.completada ? "Serie completada" : "Marcar serie como completada")
    }
}
