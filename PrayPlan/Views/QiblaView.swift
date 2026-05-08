import SwiftUI
import CoreLocation
import Adhan

@Observable
final class QiblaViewModel: NSObject, CLLocationManagerDelegate {
    var deviceHeading: Double = 0
    var qiblaDirection: Double = 0
    var isCalibrating: Bool = true

    private let headingManager = CLLocationManager()

    override init() {
        super.init()
        headingManager.delegate = self
    }

    func start(location: CLLocation?) {
        if let loc = location {
            let coords = Coordinates(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
            qiblaDirection = Qibla(coordinates: coords).direction
        }
        headingManager.startUpdatingHeading()
    }

    func stop() {
        headingManager.stopUpdatingHeading()
    }

    var needleAngle: Double {
        (qiblaDirection - deviceHeading + 360).truncatingRemainder(dividingBy: 360)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        deviceHeading  = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
        isCalibrating  = false
    }
}

struct QiblaView: View {
    @Environment(LocationService.self) private var locationService
    @State private var viewModel = QiblaViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                ZStack {
                    CompassRing()
                    NeedleView(angle: viewModel.needleAngle)
                }
                .frame(width: 280, height: 280)

                VStack(spacing: 8) {
                    Text(String(format: "%.1f°", viewModel.qiblaDirection))
                        .font(.system(.largeTitle, design: .rounded).bold())

                    Text(String(localized: "qibla.direction", defaultValue: "Direction de La Mecque"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if viewModel.isCalibrating {
                        Label(
                            String(localized: "qibla.calibrating", defaultValue: "Calibrage de la boussole…"),
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }

                Spacer()
            }
            .navigationTitle(String(localized: "tab.qibla", defaultValue: "Qibla"))
        }
        .onAppear { viewModel.start(location: locationService.currentLocation) }
        .onDisappear { viewModel.stop() }
        .onChange(of: locationService.currentLocation) { _, loc in
            viewModel.start(location: loc)
        }
    }
}

struct CompassRing: View {
    private let directions = ["N", "E", "S", "O"]

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: 2)

            ForEach(0..<36) { i in
                let angle = Double(i) * 10
                let isCardinal = i % 9 == 0
                Rectangle()
                    .fill(isCardinal ? Color.primary : Color.secondary.opacity(0.4))
                    .frame(width: isCardinal ? 2 : 1, height: isCardinal ? 16 : 10)
                    .offset(y: -128)
                    .rotationEffect(.degrees(angle))
            }

            ForEach(Array(directions.enumerated()), id: \.offset) { _, dir in
                Text(dir)
                    .font(.caption.bold())
                    .foregroundStyle(dir == "N" ? .red : .primary)
                    .offset(y: -108)
                    .rotationEffect(.degrees(angle(for: dir)))
            }
        }
    }

    private func angle(for direction: String) -> Double {
        switch direction {
        case "N": return 0
        case "E": return 90
        case "S": return 180
        default:  return 270
        }
    }
}

struct NeedleView: View {
    let angle: Double

    var body: some View {
        ZStack {
            Image(systemName: "location.north.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.brandGreen, .brandGreen.opacity(0.7)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        }
        .rotationEffect(.degrees(angle))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: angle)
    }
}
