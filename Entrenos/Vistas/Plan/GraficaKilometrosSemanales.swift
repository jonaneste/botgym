import SwiftUI
import Charts

/// Kilómetros por semana del plan: lo previsto detrás, lo corrido delante.
///
/// La cabecera de cada semana ya dice «18 / 25 km», pero eso es una semana.
/// Con una carrera en el calendario lo que decide es la tendencia: tres
/// semanas seguidas cortándose no se ve mirando una, y es lo que separa
/// llegar de no llegar.
///
/// Dos barras superpuestas y no apiladas: apiladas, la suma de previsto y
/// hecho daría una altura que no significa nada. Así lo previsto es el hueco
/// que hay que rellenar, y lo corrido se ve ocupándolo.
struct GraficaKilometrosSemanales: View {
    let semanas: [SemanaDeCarrera]

    var body: some View {
        Chart {
            ForEach(semanas) { semana in
                BarMark(
                    x: .value("Semana", semana.inicioSemana, unit: .weekOfYear),
                    y: .value("Previstos", semana.previstos),
                    width: .fixed(anchoDeBarra)
                )
                .foregroundStyle(Paleta.carrera.opacity(0.18))
                .cornerRadius(4)
                .accessibilityHidden(true)

                BarMark(
                    x: .value("Semana", semana.inicioSemana, unit: .weekOfYear),
                    y: .value("Hechos", semana.hechos),
                    width: .fixed(anchoDeBarra - 10)
                )
                .foregroundStyle(semana.cumplida ? Paleta.logrado : Paleta.carrera)
                .cornerRadius(3)
                // Las barras no llevan etiqueta propia y los ejes no se leen,
                // así que sin esto VoiceOver anuncia «gráfico» y nada más.
                .accessibilityLabel(Formato.diaYMes(semana.inicioSemana))
                .accessibilityValue(valorAccesible(semana))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear)) { valor in
                AxisGridLine()
                AxisValueLabel {
                    if let fecha = valor.as(Date.self) {
                        Text(Formato.diaYMes(fecha))
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .accessibilityLabel("Kilómetros por semana")
        .accessibilityValue(resumenAccesible)
    }

    /// Fijo, como en la gráfica de series: `BarMark` reparte el ancho
    /// disponible entre los pasos del eje, y con pocas semanas eso es la
    /// gráfica entera.
    private var anchoDeBarra: CGFloat { 22 }

    private func valorAccesible(_ semana: SemanaDeCarrera) -> String {
        guard semana.previstos > 0 else {
            return "\(Formato.numeroCorto(semana.hechos)) km, sin previsión"
        }
        let base = "\(Formato.numeroCorto(semana.hechos)) de \(Formato.numeroCorto(semana.previstos)) km"
        return semana.cumplida ? "\(base). Cumplida." : "\(base). Faltan \(Formato.numeroCorto(semana.faltan))."
    }

    private var resumenAccesible: String {
        let conPrevision = semanas.filter { $0.previstos > 0 }
        guard !conPrevision.isEmpty else { return "Sin kilómetros previstos" }
        let cumplidas = conPrevision.filter(\.cumplida).count
        return "\(conPrevision.count) semanas con kilómetros, \(cumplidas) cumplidas"
    }
}
