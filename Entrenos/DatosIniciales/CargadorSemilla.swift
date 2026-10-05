import Foundation
import SwiftData

/// Carga los datos iniciales la primera vez que se abre la app.
enum CargadorSemilla {

    /// Siembra la biblioteca y la rutina de 5 días si la base está vacía.
    ///
    /// Es idempotente: si ya hay ejercicios, no toca nada. Así no duplica
    /// datos al reinstalar la app con cuenta gratuita cada 7 días.
    @MainActor
    static func sembrarSiHaceFalta(contexto: ModelContext) {
        let repositorio = RepositorioEntrenos(contexto: contexto)
        guard !repositorio.hayDatos() else { return }

        let ajustes = Ajustes.cargar(en: contexto)
        let catalogo = sembrarEjercicios(contexto: contexto)
        sembrarRutinas(contexto: contexto, catalogo: catalogo, ajustes: ajustes)

        do {
            try contexto.save()
        } catch {
            print("Error al sembrar los datos iniciales: \(error)")
        }
    }

    /// Inserta la biblioteca y devuelve un índice por nombre normalizado.
    @discardableResult
    private static func sembrarEjercicios(contexto: ModelContext) -> [String: Ejercicio] {
        var catalogo: [String: Ejercicio] = [:]
        for definicion in SemillaEjercicios.todos {
            let ejercicio = Ejercicio(
                nombre: definicion.nombre,
                grupoPrincipal: definicion.principal,
                gruposSecundarios: definicion.secundarios,
                material: definicion.material,
                tipoRegistro: definicion.tipo,
                esPersonalizado: false
            )
            contexto.insert(ejercicio)
            catalogo[ejercicio.nombreNormalizado] = ejercicio
        }
        return catalogo
    }

    private static func sembrarRutinas(
        contexto: ModelContext,
        catalogo: [String: Ejercicio],
        ajustes: Ajustes
    ) {
        let carpeta = CarpetaRutinas(nombre: SemillaRutinas.nombreCarpeta, orden: 0)
        contexto.insert(carpeta)

        for (indiceRutina, definicion) in SemillaRutinas.rutinas.enumerated() {
            let rutina = Rutina(nombre: definicion.nombre, orden: indiceRutina)
            contexto.insert(rutina)
            rutina.carpeta = carpeta

            // Cada etiqueta de superserie de la semilla se traduce a un UUID
            // propio de esta rutina.
            var idsSuperserie: [String: UUID] = [:]

            for (indiceElemento, elementoDef) in definicion.elementos.enumerated() {
                let clave = Ejercicio.normalizar(elementoDef.ejercicio)
                guard let ejercicio = catalogo[clave] else {
                    // No debería ocurrir: la semilla de rutinas solo nombra
                    // ejercicios que están en la de la biblioteca. Si pasa,
                    // es mejor saltar el elemento que insertar uno roto.
                    print("Semilla: no se encontró el ejercicio «\(elementoDef.ejercicio)»")
                    continue
                }

                var idSuperserie: UUID?
                if let etiqueta = elementoDef.superserie {
                    if let existente = idsSuperserie[etiqueta] {
                        idSuperserie = existente
                    } else {
                        let nuevo = UUID()
                        idsSuperserie[etiqueta] = nuevo
                        idSuperserie = nuevo
                    }
                }

                let elemento = ElementoRutina(
                    ejercicio: ejercicio,
                    orden: indiceElemento,
                    seriesObjetivo: elementoDef.series,
                    objetivoMin: elementoDef.objetivoMin,
                    objetivoMax: elementoDef.objetivoMax,
                    rirMin: elementoDef.rirMin ?? ajustes.rirPorDefectoMin,
                    rirMax: elementoDef.rirMax ?? ajustes.rirPorDefectoMax,
                    descansoSegundos: elementoDef.descanso,
                    idSuperserie: idSuperserie
                )
                contexto.insert(elemento)
                elemento.rutina = rutina
            }
        }
    }
}
