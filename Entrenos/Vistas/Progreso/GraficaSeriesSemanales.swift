import SwiftUI
import Charts

/// Barras de series totales por semana, partidas por región del cuerpo.
///
/// La pregunta que se le hace a esta gráfica no es solo «¿cuántas series?»,
/// es «¿de qué?». Con una barra de un solo color, una semana de treinta series
/// que son todas de torso se veía igual que una repartida, y lo que hay que
/// ver es justo la diferencia.
struct GraficaSeriesSemanales: View {
    let datos: [SeriesDeSemana]
    /// Los tramos de cada barra. Si llega vacío —no hay nada clasificado— se
    /// pinta la barra entera del color de acento.
    var porRegion: [SeriesDeSemanaYRegion] = []

    var body: some View {
        Chart {
            if porRegion.isEmpty {
                ForEach(datos) { semana in
                    BarMark(
                        x: .value("Semana", semana.inicioSemana, unit: .weekOfYear),
                        y: .value("Series", semana.series),
                        width: .fixed(anchoDeBarra)
                    )
                    .foregroundStyle(Paleta.acento.gradient)
                    .cornerRadius(4)
                    // Sin esto VoiceOver anuncia «gráfico» y nada más: las
                    // barras no llevan etiqueta propia y los ejes no se leen.
                    // Con ella se pueden recorrer una a una en vez de oír solo
                    // el resumen.
                    .accessibilityLabel(Formato.diaYMes(semana.inicioSemana))
                    .accessibilityValue("\(Formato.numeroCorto(semana.series)) series")
                }
            } else {
                ForEach(porRegion) { tramo in
                    BarMark(
                        x: .value("Semana", tramo.inicioSemana, unit: .weekOfYear),
                        y: .value("Series", tramo.series),
                        width: .fixed(anchoDeBarra)
                    )
                    .foregroundStyle(by: .value("Región", tramo.region.nombre))
                    .cornerRadius(3)
                    .accessibilityLabel("\(Formato.diaYMes(tramo.inicioSemana)), \(tramo.region.nombre)")
                    .accessibilityValue("\(tramo.series) series")
                }
            }
        }
        // La escala se declara a mano para que cada región lleve SIEMPRE su
        // color: con la paleta automática, el color de una región cambiaba
        // según qué otras regiones hubiera esa semana.
        .chartForegroundStyleScale(escalaDeColores)
        .chartLegend(porRegion.isEmpty ? .hidden : .automatic)
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear)) { valor in
                AxisGridLine()
                AxisValueLabel {
                    if let fecha = valor.as(Date.self) {
                        // Ocho semanas de «13 oct» a `.caption2` caben justas
                        // en el ancho de un móvil; al crecer el texto chocaban
                        // unas con otras en lugar de encogerse.
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
        .accessibilityLabel("Series por semana")
        .accessibilityValue(resumenAccesible)
    }

    /// El ancho de barra se fija, no se deja al automático.
    ///
    /// `BarMark` reparte el ancho disponible entre los pasos del eje, y con
    /// una sola semana de datos eso es **toda la gráfica**: un bloque de color
    /// de borde a borde que no se lee como una barra. Con un ancho fijo, una
    /// semana sola se ve como lo que es.
    private var anchoDeBarra: CGFloat { 24 }

    /// Cada región con su color, siempre el mismo.
    private var escalaDeColores: KeyValuePairs<String, Color> {
        // `KeyValuePairs` no se puede construir en un bucle, así que van
        // enumeradas. Son cinco y no van a crecer: una región es una parte
        // del cuerpo.
        [
            RegionCorporal.torso.nombre: Paleta.region(.torso),
            RegionCorporal.hombro.nombre: Paleta.region(.hombro),
            RegionCorporal.brazo.nombre: Paleta.region(.brazo),
            RegionCorporal.pierna.nombre: Paleta.region(.pierna),
            RegionCorporal.sinClasificar.nombre: Paleta.region(.sinClasificar),
        ]
    }

    private var resumenAccesible: String {
        guard let ultima = datos.last else { return "Sin datos todavía" }
        let total = datos.reduce(0.0) { $0 + $1.series }
        let media = total / Double(datos.count)
        return "\(datos.count) semanas, esta semana \(Formato.numeroCorto(ultima.series)) series, media \(Formato.numeroCorto(media))"
    }
}
