// swift-tools-version:5.9
import PackageDescription

// Este paquete existe para poder compilar y testear la lógica pura de la app
// (progresión, récords, volumen, esquema JSON) sin Xcode ni simulador:
//
//     swift test
//
// Apunta a la MISMA carpeta de fuentes que usa el target de la app
// (Entrenos/Nucleo), así que no hay código duplicado. Todo lo que viva ahí
// debe importar únicamente Foundation: ni SwiftUI, ni SwiftData, ni HealthKit.
// Herramientas/verificar-nucleo.sh lo comprueba.
let package = Package(
    name: "NucleoEntrenos",
    platforms: [.iOS(.v17), .macOS(.v13)],
    targets: [
        .target(
            name: "NucleoEntrenos",
            path: "Entrenos/Nucleo"
        ),
        .testTarget(
            name: "NucleoEntrenosTests",
            dependencies: ["NucleoEntrenos"],
            path: "Tests/NucleoEntrenosTests"
        ),
    ]
)
