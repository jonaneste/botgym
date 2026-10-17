import SwiftUI

/// Una figura humana con cada parte teñida según lo entrenada que va la
/// semana.
///
/// Una lista de dieciséis grupos con sus cifras dice cuánto, pero no dice
/// **dónde**: hay que leerla entera para ver que la semana se ha ido en
/// empuje. Un cuerpo se mira de un golpe, que es justo lo que se le pide a un
/// resumen semanal.
///
/// Se dibuja con formas y no con una imagen a propósito: una silueta en PNG
/// no se puede teñir por zonas, no se adapta al modo oscuro y habría que
/// mantener dos versiones.
struct MapaDelCuerpo: View {
    /// Series hechas y objetivo de cada grupo, tal y como las da el servicio
    /// de volumen.
    let grupos: [SeriesDeGrupo]

    var body: some View {
        VStack(spacing: 10) {
            Canvas { contexto, tamaño in
                let u = min(tamaño.width / 120, tamaño.height / 224)
                let centro = tamaño.width / 2

                // La cabeza no es una zona entrenable, pero sin ella la figura
                // no se lee como una persona: se queda en un montón de
                // bloques. Va en gris y no cuenta para nada.
                contexto.fill(
                    ZonaDelCuerpo.cabeza.camino(centro: centro, u: u),
                    with: .color(Color(.quaternaryLabel))
                )

                for zona in ZonaDelCuerpo.todas {
                    let camino = zona.camino(centro: centro, u: u)
                    contexto.fill(camino, with: .color(color(de: zona)))
                }
            }
            .frame(height: 224)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mapa del cuerpo")
            .accessibilityValue(descripcionAccesible)

            leyenda
        }
    }

    // MARK: - Color

    /// Verde cumplido, ámbar a medias, gris sin tocar. Los mismos tres
    /// estados que el resto de la app, y no un degradado continuo: con un
    /// degradado no se distingue «casi» de «ni la mitad» sin mirar la cifra,
    /// que es lo que esta vista evita.
    private func color(de zona: ZonaDelCuerpo) -> Color {
        let series = zona.grupos.reduce(0.0) { suma, grupo in
            suma + (self.grupos.first { $0.grupo == grupo }?.series ?? 0)
        }
        guard series > 0 else { return Color(.quaternaryLabel) }

        let objetivo = zona.grupos.reduce(0) { suma, grupo in
            suma + (self.grupos.first { $0.grupo == grupo }?.objetivo ?? 0)
        }
        guard objetivo > 0 else { return Paleta.acento.opacity(0.55) }

        let fraccion = series / Double(objetivo)
        if fraccion >= 1 { return Paleta.logrado }
        if fraccion >= 0.5 { return Paleta.aviso }
        return Paleta.insuficiente.opacity(0.75)
    }

    private var leyenda: some View {
        HStack(spacing: 14) {
            punto(Paleta.logrado, "Cumplido")
            punto(Paleta.aviso, "A medias")
            punto(Paleta.insuficiente.opacity(0.75), "Corto")
            punto(Color(.quaternaryLabel), "Nada")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func punto(_ color: Color, _ texto: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(texto)
        }
        .accessibilityElement(children: .combine)
    }

    private var descripcionAccesible: String {
        let cumplidas = ZonaDelCuerpo.todas.filter { color(de: $0) == Paleta.logrado }
        guard !cumplidas.isEmpty else { return "Ninguna zona cumplida esta semana" }
        return "Cumplido esta semana: " + cumplidas.map(\.nombre).joined(separator: ", ")
    }
}

/// Una zona dibujable de la figura, con los grupos musculares que representa.
///
/// No hay una zona por grupo: en una figura de 120 puntos de ancho, el hombro
/// anterior y el posterior caen en el mismo sitio, y pintarlos aparte sería
/// inventarse una precisión que el dibujo no tiene.
struct ZonaDelCuerpo {
    let nombre: String
    let grupos: [GrupoMuscular]
    /// En coordenadas de una figura de 120 × 220, con el centro en x = 60.
    let rectangulos: [(x: Double, y: Double, ancho: Double, alto: Double, radio: Double)]

    func camino(centro: Double, u: Double) -> Path {
        var camino = Path()
        for r in rectangulos {
            let marco = CGRect(
                x: centro + (r.x - 60) * u,
                y: r.y * u,
                width: r.ancho * u,
                height: r.alto * u
            )
            camino.addRoundedRect(in: marco, cornerSize: CGSize(width: r.radio * u, height: r.radio * u))
        }
        return camino
    }

    /// La cabeza, que no es una zona entrenable: se dibuja aparte y en gris
    /// para que la figura se lea como una persona.
    static let cabeza = ZonaDelCuerpo(
        nombre: "Cabeza",
        grupos: [],
        rectangulos: [(x: 50, y: 4, ancho: 20, alto: 24, radio: 10)]
    )

    /// De arriba abajo.
    static let todas: [ZonaDelCuerpo] = [
        ZonaDelCuerpo(
            nombre: "Hombros",
            grupos: [.hombroAnterior, .hombroLateral, .hombroPosterior, .trapecio],
            rectangulos: [
                (x: 27, y: 34, ancho: 21, alto: 19, radio: 9),
                (x: 72, y: 34, ancho: 21, alto: 19, radio: 9),
            ]
        ),
        ZonaDelCuerpo(
            nombre: "Pecho y espalda",
            grupos: [.pecho, .espalda, .dorsal],
            rectangulos: [(x: 41, y: 34, ancho: 38, alto: 46, radio: 11)]
        ),
        ZonaDelCuerpo(
            nombre: "Brazos",
            grupos: [.biceps, .triceps, .antebrazo],
            rectangulos: [
                (x: 25, y: 56, ancho: 15, alto: 56, radio: 7),
                (x: 80, y: 56, ancho: 15, alto: 56, radio: 7),
            ]
        ),
        ZonaDelCuerpo(
            nombre: "Core",
            grupos: [.core, .lumbar],
            rectangulos: [(x: 45, y: 82, ancho: 30, alto: 34, radio: 9)]
        ),
        ZonaDelCuerpo(
            nombre: "Piernas",
            grupos: [.cuadriceps, .isquios, .gluteo],
            rectangulos: [
                (x: 43, y: 118, ancho: 16, alto: 58, radio: 8),
                (x: 61, y: 118, ancho: 16, alto: 58, radio: 8),
            ]
        ),
        ZonaDelCuerpo(
            nombre: "Gemelos",
            grupos: [.gemelo],
            rectangulos: [
                (x: 44, y: 178, ancho: 14, alto: 40, radio: 7),
                (x: 62, y: 178, ancho: 14, alto: 40, radio: 7),
            ]
        ),
    ]
}
