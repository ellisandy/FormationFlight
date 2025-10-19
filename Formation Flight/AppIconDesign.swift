import SwiftUI

struct AppIconDesign: View {
    // Tunable colors
    private let bgTop = Color(red: 8/255, green: 18/255, blue: 48/255)
    private let bgBottom = Color(red: 5/255, green: 10/255, blue: 28/255)
    private let planeColor = Color.white
    private let accent = Color(hue: 0.58, saturation: 0.7, brightness: 0.9) // subtle blue accent
    private let smokeColor = Color.white.opacity(0.35)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let minSide = min(w, h)
            let margin = minSide * 0.08

            ZStack {
                // Background
                LinearGradient(gradient: Gradient(colors: [bgTop, bgBottom]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(
                        RadialGradient(gradient: Gradient(colors: [accent.opacity(0.18), .clear]), center: .top, startRadius: minSide * 0.05, endRadius: minSide * 0.9)
                    )
                    .ignoresSafeArea()

                // V-formation layout
                let centerX = w / 2
                let centerY = h / 2
                let leaderY = centerY * 0.65 // a bit above center
                let wingYOffset = minSide * 0.14
                let wingXOffset = minSide * 0.22

                // Sizes
                let leaderSize = minSide * 0.18
                let wingSize = minSide * 0.14

                // Smoke trails (behind planes)
                Group {
                    SmokeTrail(curve: .leader)
                        .stroke(smokeColor, style: StrokeStyle(lineWidth: minSide * 0.020, lineCap: .round))
                        .blur(radius: minSide * 0.010)
                        .opacity(0.9)
                        .frame(width: w - margin * 2, height: h - margin * 2)
                        .offset(x: margin, y: margin)

                    SmokeTrail(curve: .leftWing)
                        .stroke(smokeColor, style: StrokeStyle(lineWidth: minSide * 0.018, lineCap: .round))
                        .blur(radius: minSide * 0.010)
                        .opacity(0.85)
                        .frame(width: w - margin * 2, height: h - margin * 2)
                        .offset(x: margin, y: margin)

                    SmokeTrail(curve: .rightWing)
                        .stroke(smokeColor, style: StrokeStyle(lineWidth: minSide * 0.018, lineCap: .round))
                        .blur(radius: minSide * 0.010)
                        .opacity(0.85)
                        .frame(width: w - margin * 2, height: h - margin * 2)
                        .offset(x: margin, y: margin)
                }

                // Planes
                Group {
                    Triangle()
                        .fill(planeColor)
                        .frame(width: leaderSize, height: leaderSize)
                        .shadow(color: .black.opacity(0.25), radius: minSide * 0.02, x: 0, y: minSide * 0.01)
                        .position(x: centerX, y: leaderY)

                    Triangle()
                        .fill(planeColor)
                        .frame(width: wingSize, height: wingSize)
                        .shadow(color: .black.opacity(0.25), radius: minSide * 0.02, x: 0, y: minSide * 0.01)
                        .position(x: centerX - wingXOffset, y: leaderY + wingYOffset)

                    Triangle()
                        .fill(planeColor)
                        .frame(width: wingSize, height: wingSize)
                        .shadow(color: .black.opacity(0.25), radius: minSide * 0.02, x: 0, y: minSide * 0.01)
                        .position(x: centerX + wingXOffset, y: leaderY + wingYOffset)
                }

                // Subtle vignette for focus
                Rectangle()
                    .fill(
                        LinearGradient(colors: [.black.opacity(0.25), .clear, .clear, .black.opacity(0.25)], startPoint: .top, endPoint: .bottom)
                    )
                    .blendMode(.multiply)
                    .allowsHitTesting(false)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Smoke Trails
struct SmokeTrail: Shape {
    enum Curve { case leader, leftWing, rightWing }
    var curve: Curve

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let minSide = min(w, h)
        let centerX = w / 2
        let leaderY = h * 0.42

        switch curve {
        case .leader:
            // A gentle S-curve behind the leader
            let start = CGPoint(x: centerX, y: leaderY + minSide * 0.06)
            let cp1 = CGPoint(x: centerX - minSide * 0.10, y: leaderY + minSide * 0.18)
            let cp2 = CGPoint(x: centerX + minSide * 0.12, y: leaderY + minSide * 0.34)
            let end = CGPoint(x: centerX, y: h - minSide * 0.10)
            path.move(to: start)
            path.addCurve(to: end, control1: cp1, control2: cp2)

        case .leftWing:
            let start = CGPoint(x: centerX - minSide * 0.22, y: leaderY + minSide * 0.20)
            let cp1 = CGPoint(x: centerX - minSide * 0.40, y: leaderY + minSide * 0.35)
            let cp2 = CGPoint(x: centerX - minSide * 0.08, y: leaderY + minSide * 0.50)
            let end = CGPoint(x: centerX - minSide * 0.18, y: h - minSide * 0.08)
            path.move(to: start)
            path.addCurve(to: end, control1: cp1, control2: cp2)

        case .rightWing:
            let start = CGPoint(x: centerX + minSide * 0.22, y: leaderY + minSide * 0.20)
            let cp1 = CGPoint(x: centerX + minSide * 0.40, y: leaderY + minSide * 0.35)
            let cp2 = CGPoint(x: centerX + minSide * 0.08, y: leaderY + minSide * 0.50)
            let end = CGPoint(x: centerX + minSide * 0.18, y: h - minSide * 0.08)
            path.move(to: start)
            path.addCurve(to: end, control1: cp1, control2: cp2)
        }

        return path
    }
}

// MARK: - Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w/2, y: 0))           // top
        p.addLine(to: CGPoint(x: 0, y: h))          // bottom left
        p.addLine(to: CGPoint(x: w, y: h))          // bottom right
        p.closeSubpath()
        return p
    }
}

#Preview("App Icon 1024") {
    AppIconDesign()
        .frame(width: 1024, height: 1024)
        .clipped() // ensure no outside bleed
}
