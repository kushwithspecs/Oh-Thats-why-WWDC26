import SwiftUI
import CoreMotion

// MARK: - Motion Manager
class MotionManager: ObservableObject {
    private let manager = CMMotionManager()

    @Published var gravityX: Double = 0.0
    @Published var gravityY: Double = 0.0
    @Published var gravityZ: Double = 0.0
    @Published var totalG: Double = 0.0
    @Published var userAccelX: Double = 0.0
    @Published var userAccelY: Double = 0.0
    @Published var userAccelZ: Double = 0.0
    @Published var totalUserAccel: Double = 0.0
    @Published var rotationRateX: Double = 0.0

    init() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion = motion else { return }
            self?.gravityX = motion.gravity.x
            self?.gravityY = motion.gravity.y
            self?.gravityZ = motion.gravity.z
            self?.totalG = sqrt(
                motion.gravity.x * motion.gravity.x +
                motion.gravity.y * motion.gravity.y +
                motion.gravity.z * motion.gravity.z
            )
            self?.userAccelX = motion.userAcceleration.x
            self?.userAccelY = motion.userAcceleration.y
            self?.userAccelZ = motion.userAcceleration.z
            self?.totalUserAccel = sqrt(
                motion.userAcceleration.x * motion.userAcceleration.x +
                motion.userAcceleration.y * motion.userAcceleration.y +
                motion.userAcceleration.z * motion.userAcceleration.z
            )
            self?.rotationRateX = motion.rotationRate.x
        }
    }

    deinit { manager.stopDeviceMotionUpdates() }
}

// MARK: - Stars View (used in night sky)
private struct Star: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    let twinkleDuration: Double
}

private struct TwinkleModifier: ViewModifier {
    let duration: Double
    @State private var bright: Bool = false

    func body(content: Content) -> some View {
        content
            .opacity(bright ? 1.0 : 0.15)
            .animation(
                .easeInOut(duration: duration).repeatForever(autoreverses: true),
                value: bright
            )
            .onAppear { bright = true }
    }
}

struct StarsView: View {
    private static let stars: [Star] = (0..<130).map { _ in
        Star(
            x: CGFloat.random(in: 0...1),
            y: CGFloat.random(in: 0...0.88),
            size: CGFloat.random(in: 0.8...2.6),
            opacity: Double.random(in: 0.35...0.85),
            twinkleDuration: Double.random(in: 1.6...4.5)
        )
    }

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                for star in Self.stars {
                    let rect = CGRect(
                        x: star.x * size.width - star.size / 2,
                        y: star.y * size.height - star.size / 2,
                        width: star.size,
                        height: star.size
                    )
                    context.opacity = star.opacity
                    context.fill(Path(ellipseIn: rect), with: .color(.white))
                }
            }
            .overlay(
                ForEach(Self.stars.prefix(35)) { star in
                    Circle()
                        .fill(Color.white)
                        .frame(width: star.size * 1.5, height: star.size * 1.5)
                        .position(
                            x: star.x * geo.size.width,
                            y: star.y * geo.size.height
                        )
                        .modifier(TwinkleModifier(duration: star.twinkleDuration))
                }
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Shared Background
struct SkyBackground: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.02, blue: 0.08),
                        Color(red: 0.03, green: 0.03, blue: 0.12),
                        Color(red: 0.04, green: 0.03, blue: 0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                RadialGradient(
                    colors: [Color(red: 0.80, green: 0.88, blue: 1.0).opacity(0.10), Color.clear],
                    center: .init(x: 0.82, y: 0.09),
                    startRadius: 8, endRadius: 180
                )
                .ignoresSafeArea()
                StarsView()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.83, green: 0.91, blue: 0.98),
                        Color(red: 0.95, green: 0.97, blue: 0.99),
                        Color(red: 0.97, green: 0.97, blue: 0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @StateObject private var motion = MotionManager()
    @Environment(\.colorScheme) var colorScheme
    @State private var isDarkMode: Bool = false
    @State private var ballX: CGFloat = 0.0
    @State private var ballY: CGFloat = 0.0
    @State private var velocityX: CGFloat = 0.0
    @State private var velocityY: CGFloat = 0.0
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var ballOpacity: Double = 0
    @State private var goToModes = false

    var ballColor: Color {
        isDarkMode || colorScheme == .dark
            ? Color(red: 0.92, green: 0.92, blue: 0.95)
            : Color(red: 0.10, green: 0.10, blue: 0.09)
    }

    let ballRadius: CGFloat = 28
    let boundaryRadius: CGFloat = 150
    let damping: CGFloat = 0.97
    let gravityStrength: CGFloat = 0.4
    let physicsTimer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                SkyBackground()
                // Dark mode toggle — top right
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) { isDarkMode.toggle() }
                        } label: {
                            Image(systemName: isDarkMode ? "moon.fill" : "sun.max")
                                .font(.system(size: 22, weight: .light))
                                .foregroundStyle(.primary.opacity(0.6))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .padding(.trailing, 24)
                        .padding(.top, 56)
                    }
                    Spacer()
                }
                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 10) {
                        Text("TiltLab")
                            .font(.system(size: 84, weight: .light))
                            .tracking(-2).foregroundStyle(.primary).opacity(titleOpacity)
                        Text("Feel the forces around you.")
                            .font(.system(size: 20, weight: .regular, design: .monospaced))
                            .foregroundStyle(.secondary).opacity(subtitleOpacity)
                    }
                    Spacer()
                    ZStack {
                        Circle().stroke(Color.primary.opacity(0.40), lineWidth: 2)
                            .frame(width: boundaryRadius * 2, height: boundaryRadius * 2)
                        Circle().stroke(Color.primary.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [5, 7]))
                            .frame(width: 80, height: 80)
                        Circle().fill(ballColor)
                            .frame(width: ballRadius * 2, height: ballRadius * 2)
                            .shadow(color: (isDarkMode ? Color.white : Color.black).opacity(0.18), radius: 10, x: 0, y: 5)
                            .offset(x: ballX, y: ballY)
                    }
                    .frame(width: boundaryRadius * 2, height: boundaryRadius * 2).opacity(ballOpacity)
                    Spacer()
                    Button { goToModes = true } label: {
                        Text("Begin")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(isDarkMode ? Color(red: 0.02, green: 0.02, blue: 0.08) : .white)
                            .frame(width: 260, height: 64)
                            .background(Capsule().fill(isDarkMode
                                ? Color(red: 0.65, green: 0.85, blue: 1.0)
                                : Color.primary))
                    }
                    .opacity(buttonOpacity).padding(.bottom, 60)
                    .navigationDestination(isPresented: $goToModes) { ModeSelectView() }
                }
            }
            .onAppear { runEntrance() }
            .onReceive(physicsTimer) { _ in updatePhysics() }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    func updatePhysics() {
        velocityX += CGFloat(motion.gravityX) * gravityStrength
        velocityY -= CGFloat(motion.gravityY) * gravityStrength
        velocityX *= damping; velocityY *= damping
        var nextX = ballX + velocityX; var nextY = ballY + velocityY
        let distance = sqrt(nextX * nextX + nextY * nextY)
        let maxDistance = boundaryRadius - ballRadius
        if distance > maxDistance {
            let nx = nextX / distance; let ny = nextY / distance
            let dot = velocityX * nx + velocityY * ny
            velocityX -= 2 * dot * nx * 0.6; velocityY -= 2 * dot * ny * 0.6
            nextX = nx * maxDistance; nextY = ny * maxDistance
        }
        ballX = nextX; ballY = nextY
    }

    func runEntrance() {
        withAnimation(.easeOut(duration: 0.7).delay(0.1)) { titleOpacity = 1 }
        withAnimation(.easeOut(duration: 0.7).delay(0.35)) { subtitleOpacity = 1 }
        withAnimation(.easeOut(duration: 0.8).delay(0.6)) { ballOpacity = 1 }
        withAnimation(.easeOut(duration: 0.7).delay(0.85)) { buttonOpacity = 1 }
    }
}

// MARK: - Activity Mode Model
struct ActivityMode {
    let icon: String
    let name: String
    let descriptor: String
    let color: Color
}

// MARK: - Mode Select View
struct ModeSelectView: View {
    @Environment(\.dismiss) var dismiss
    let modes: [ActivityMode] = [
        ActivityMode(icon: "scope", name: "Balance the Ball",
                     descriptor: "gravity · equilibrium · control",
                     color: Color(red: 0.29, green: 0.50, blue: 0.83)),
        ActivityMode(icon: "gauge.with.needle", name: "Hit 1g Challenge",
                     descriptor: "force · precision · measurement",
                     color: Color(red: 0.29, green: 0.72, blue: 0.48)),
        ActivityMode(icon: "sparkles", name: "Motion Art",
                     descriptor: "acceleration · motion · expression",
                     color: Color(red: 0.83, green: 0.51, blue: 0.29)),
        ActivityMode(icon: "figure.walk", name: "Pendulum Timer",
                     descriptor: "period · gravity · length",
                     color: Color(red: 0.60, green: 0.35, blue: 0.80)),
        ActivityMode(icon: "waveform.path.ecg", name: "Predict & Move",
                     descriptor: "prediction · acceleration · comparison",
                     color: Color(red: 0.85, green: 0.30, blue: 0.40))
    ]
    @State private var cardsVisible = false

    var body: some View {
        ZStack {
            SkyBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Text("Choose Activity")
                            .font(.system(size: 46, weight: .light))
                            .tracking(-0.8).foregroundStyle(.primary)
                        Text("what do you want to explore?")
                            .font(.system(size: 17, weight: .regular, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 64).padding(.bottom, 48)

                    VStack(spacing: 16) {
                        ForEach(Array(modes.enumerated()), id: \.offset) { index, mode in
                            ActivityCard(mode: mode)
                                .opacity(cardsVisible ? 1 : 0)
                                .offset(y: cardsVisible ? 0 : 24)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.12), value: cardsVisible)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .medium))
                        Text("Back").font(.system(size: 16))
                    }.foregroundStyle(.primary)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { cardsVisible = true }
        }
    }
}

// MARK: - Activity Card
struct ActivityCard: View {
    let mode: ActivityMode
    @State private var goToActivity = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button { goToActivity = true } label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(mode.color.opacity(colorScheme == .dark ? 0.25 : 0.14))
                        .frame(width: 72, height: 72)
                    Image(systemName: mode.icon)
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(mode.color)
                }
                Text(mode.name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)
                    .tracking(-0.2).multilineTextAlignment(.center)
                Text(mode.descriptor)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 28).padding(.horizontal, 20)
            .background {
                ZStack {
                    // Frosted glass base
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                    // Subtle accent tint from the card's colour
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(mode.color.opacity(colorScheme == .dark ? 0.08 : 0.05))
                    // Hairline border
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.25 : 0.70),
                                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: mode.color.opacity(colorScheme == .dark ? 0.18 : 0.10), radius: 16, x: 0, y: 6)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 8, x: 0, y: 3)
            }
        }
        .buttonStyle(CardPressStyle())
        .navigationDestination(isPresented: $goToActivity) {
            switch mode.name {
            case "Balance the Ball": BalanceGameView()
            case "Hit 1g Challenge": HitGChallengeView()
            case "Motion Art": MotionArtView()
            case "Pendulum Timer": PendulumTimerView()
            case "Predict & Move": PredictMoveView()
            default: ComingSoonView(modeName: mode.name)
            }
        }
    }
}

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ComingSoonView: View {
    let modeName: String
    var body: some View {
        ZStack {
            SkyBackground()
            VStack(spacing: 12) {
                Text(modeName).font(.system(size: 24, weight: .light)).tracking(-0.5)
                Text("coming soon").font(.system(size: 13, design: .monospaced)).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Shared Shapes
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct ArrowView: View {
    let angle: Double; let color: Color; let length: CGFloat; let label: String
    var body: some View {
        ZStack {
            Rectangle().fill(color).frame(width: 1.5, height: length).offset(y: -length / 2)
            Triangle().fill(color).frame(width: 7, height: 7).offset(y: -length)
            Text(label).font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(color).offset(y: -length - 14)
        }.rotationEffect(.radians(angle))
    }
}

struct WindParticle: Identifiable {
    let id = UUID()
    var x: CGFloat; var y: CGFloat; var opacity: Double; var size: CGFloat
}

// MARK: - Balance Game View
struct BalanceGameView: View {
    @StateObject private var motion = MotionManager()
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var ballX: CGFloat = 0; @State private var ballY: CGFloat = 0
    @State private var velX: CGFloat = 0; @State private var velY: CGFloat = 0
    @State private var windAngle: Double = 0; @State private var targetWindAngle: Double = 0
    @State private var windStrength: CGFloat = 0.08; @State private var windShiftTimer: Double = 0
    @State private var balanceTime: Double = 0; @State private var isBalanced: Bool = false
    @State private var roundComplete: Bool = false
    @State private var particles: [WindParticle] = []; @State private var particleTimer: Double = 0
    @State private var showExplanation: Bool = false; @State private var screenFlash: Double = 0
    let ballRadius: CGFloat = 30; let arenaRadius: CGFloat = 210
    let targetRadius: CGFloat = 52; let balanceRequired: Double = 5.0
    let damping: CGFloat = 0.96; let gravityStrength: CGFloat = 0.38
    let physicsTimer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()
    var balanceProgress: Double { min(balanceTime / balanceRequired, 1.0) }
    var windX: CGFloat { CGFloat(cos(windAngle)) * windStrength }
    var windY: CGFloat { CGFloat(sin(windAngle)) * windStrength }

    var body: some View {
        ZStack {
            SkyBackground()
            Color.green.opacity(screenFlash).ignoresSafeArea().allowsHitTesting(false)
            ForEach(particles) { p in
                Circle().fill(Color(red: 0.55, green: 0.75, blue: 0.95).opacity(p.opacity))
                    .frame(width: p.size, height: p.size).position(x: p.x, y: p.y).allowsHitTesting(false)
            }
            VStack(spacing: 0) {
                    HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GRAVITY").font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down").font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color(red: 0.29, green: 0.50, blue: 0.83))
                                .rotationEffect(.radians(atan2(motion.gravityX, -motion.gravityY)))
                            Text(String(format: "%.2fg", sqrt(motion.gravityX * motion.gravityX + motion.gravityY * motion.gravityY)))
                                .font(.system(size: 18, weight: .regular, design: .monospaced))
                        }
                    }
                    Spacer()
                    VStack(spacing: 4) {
                        Text(isBalanced ? String(format: "%.1fs", balanceTime) : "—")
                            .font(.system(size: 28, weight: .light, design: .monospaced))
                            .foregroundStyle(isBalanced ? Color(red: 0.29, green: 0.72, blue: 0.48) : .secondary)
                            .animation(.easeInOut(duration: 0.2), value: isBalanced)
                        Text("HOLD \(Int(balanceRequired))s").font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("WIND").font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Text(String(format: "%.0f%%", windStrength * 800)).font(.system(size: 18, weight: .regular, design: .monospaced))
                            Image(systemName: "wind").font(.system(size: 16, weight: .medium)).foregroundStyle(Color(red: 0.83, green: 0.51, blue: 0.29))
                        }
                    }
                }
                .padding(.horizontal, 36).padding(.top, 20)
                Spacer()
                ZStack {
                    // Glassy arena background disc
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: arenaRadius * 2 + 12, height: arenaRadius * 2 + 12)
                        .overlay(
                            Circle()
                                .stroke(LinearGradient(
                                    colors: [.white.opacity(colorScheme == .dark ? 0.20 : 0.60),
                                             .white.opacity(colorScheme == .dark ? 0.04 : 0.15)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 20, x: 0, y: 8)
                    Circle().stroke(Color(red: 0.29, green: 0.72, blue: 0.48).opacity(0.15), lineWidth: 3)
                        .frame(width: targetRadius * 2 + 12, height: targetRadius * 2 + 12)
                    Circle().trim(from: 0, to: balanceProgress)
                        .stroke(Color(red: 0.29, green: 0.72, blue: 0.48), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: targetRadius * 2 + 12, height: targetRadius * 2 + 12)
                        .rotationEffect(.degrees(-90)).animation(.linear(duration: 0.1), value: balanceProgress)
                    Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1.5).frame(width: arenaRadius * 2, height: arenaRadius * 2)
                    Circle().fill(Color(red: 0.29, green: 0.72, blue: 0.48).opacity(isBalanced ? 0.12 : 0.05))
                        .frame(width: targetRadius * 2, height: targetRadius * 2).animation(.easeInOut(duration: 0.3), value: isBalanced)
                    Circle().stroke(Color(red: 0.29, green: 0.72, blue: 0.48).opacity(isBalanced ? 0.5 : 0.2),
                                    style: StrokeStyle(lineWidth: 1, dash: [4, 5])).frame(width: targetRadius * 2, height: targetRadius * 2)
                    ArrowView(angle: atan2(motion.gravityX, -motion.gravityY),
                              color: Color(red: 0.55, green: 0.75, blue: 1.0), length: 40, label: "g")
                        .opacity(colorScheme == .dark ? 1.0 : 0.6)
                    ArrowView(angle: windAngle - .pi / 2, color: Color(red: 1.0, green: 0.70, blue: 0.40),
                              length: CGFloat(windStrength * 400), label: "w")
                        .opacity(colorScheme == .dark ? 1.0 : 0.6)
                    Circle()
                        .fill(colorScheme == .dark
                            ? RadialGradient(colors: [Color(red: 0.95, green: 0.95, blue: 1.0), Color(red: 0.75, green: 0.75, blue: 0.82)],
                                            center: .init(x: 0.35, y: 0.3), startRadius: 2, endRadius: CGFloat(ballRadius))
                            : RadialGradient(colors: [Color(red: 0.25, green: 0.25, blue: 0.23), Color(red: 0.08, green: 0.08, blue: 0.07)],
                                            center: .init(x: 0.35, y: 0.3), startRadius: 2, endRadius: CGFloat(ballRadius)))
                        .frame(width: ballRadius * 2, height: ballRadius * 2)
                        .shadow(color: colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.25), radius: 10, x: 0, y: 5)
                        .offset(x: ballX, y: ballY)
                }
                .frame(width: arenaRadius * 2, height: arenaRadius * 2)
                Spacer()
                Text(isBalanced ? "hold it steady..." : "tilt to centre the ball")
                    .font(.system(size: 17, weight: .regular, design: .monospaced)).foregroundStyle(.secondary)
                    .animation(.easeInOut(duration: 0.3), value: isBalanced).padding(.bottom, 56)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .medium))
                        Text("Back").font(.system(size: 16))
                    }.foregroundStyle(.primary)
                }
            }
        }
        .onReceive(physicsTimer) { _ in updatePhysics(); updateWind(); updateParticles(); checkBalance() }
        .fullScreenCover(isPresented: $showExplanation) {
            BalanceExplanationView(
                onContinue: { showExplanation = false; resetGame() },
                onBack: { showExplanation = false; dismiss() }
            )
        }
    }

    func updatePhysics() {
        velX += CGFloat(motion.gravityX) * gravityStrength; velY -= CGFloat(motion.gravityY) * gravityStrength
        velX += windX; velY += windY; velX *= damping; velY *= damping
        var nextX = ballX + velX; var nextY = ballY + velY
        let dist = sqrt(nextX * nextX + nextY * nextY); let maxDist = arenaRadius - ballRadius
        if dist > maxDist {
            let nx = nextX / dist; let ny = nextY / dist; let dot = velX * nx + velY * ny
            velX -= 2 * dot * nx * 0.55; velY -= 2 * dot * ny * 0.55
            nextX = nx * maxDist; nextY = ny * maxDist
        }
        ballX = nextX; ballY = nextY
    }

    func updateWind() {
        windShiftTimer += 1.0 / 60.0
        if windShiftTimer >= 4.0 { windShiftTimer = 0; targetWindAngle = Double.random(in: 0...(2 * .pi)); windStrength = min(windStrength + 0.01, 0.18) }
        windAngle += (targetWindAngle - windAngle) * 0.01
    }

    func updateParticles() {
        particleTimer += 1.0 / 60.0
        if particleTimer > 0.15 {
            particleTimer = 0
            let spawnAngle = windAngle + .pi; let spawnDist = arenaRadius * 0.9
            particles.append(WindParticle(
                x: UIScreen.main.bounds.width / 2 + CGFloat(cos(spawnAngle)) * spawnDist,
                y: UIScreen.main.bounds.height / 2 + CGFloat(sin(spawnAngle)) * spawnDist,
                opacity: Double.random(in: 0.2...0.5), size: CGFloat.random(in: 2...5)))
        }
        for i in particles.indices {
            particles[i].x += CGFloat(cos(windAngle)) * windStrength * 60
            particles[i].y += CGFloat(sin(windAngle)) * windStrength * 60
            particles[i].opacity -= 0.015
        }
        particles.removeAll { $0.opacity <= 0 }
    }

    func checkBalance() {
        let d = sqrt(ballX * ballX + ballY * ballY); isBalanced = d < targetRadius
        if isBalanced {
            balanceTime += 1.0 / 60.0
            if balanceTime >= balanceRequired && !roundComplete {
                roundComplete = true
                withAnimation(.easeIn(duration: 0.2)) { screenFlash = 0.3 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation { screenFlash = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showExplanation = true }
                }
            }
        } else { balanceTime = max(0, balanceTime - 0.5 / 60.0) }
    }

    func resetGame() { ballX = 0; ballY = 0; velX = 0; velY = 0; balanceTime = 0; roundComplete = false; windStrength = 0.08; windAngle = 0; particles = [] }
}

// MARK: - Balance Explanation View
struct BalanceExplanationView: View {
    let onContinue: () -> Void
    let onBack: () -> Void
    @State private var line1: Double = 0; @State private var line2: Double = 0
    @State private var line3: Double = 0; @State private var wordOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    var body: some View {
        ZStack {
            SkyBackground()
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    Circle().fill(Color(red: 0.29, green: 0.72, blue: 0.48).opacity(0.1)).frame(width: 80, height: 80)
                    Image(systemName: "checkmark").font(.system(size: 30, weight: .light)).foregroundStyle(Color(red: 0.29, green: 0.72, blue: 0.48))
                }.opacity(line1).padding(.bottom, 48)
                VStack(alignment: .leading, spacing: 20) {
                    Text("You just felt two forces cancel.")
                        .font(.system(size: 32, weight: .light)).tracking(-0.5).foregroundStyle(.primary).opacity(line1)
                    Text("Gravity pulled the ball down. Wind pushed it sideways. You tilted your phone to create a third force — and when all three balanced, the ball stopped moving.")
                        .font(.system(size: 20)).foregroundStyle(.secondary).lineSpacing(6).opacity(line2)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("That's called").font(.system(size: 20)).foregroundStyle(.secondary)
                        Text("equilibrium.").font(.system(size: 24, weight: .medium)).foregroundStyle(Color(red: 0.29, green: 0.50, blue: 0.83)).opacity(wordOpacity)
                    }.opacity(line3)
                }.padding(.horizontal, 36)
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text("PHYSICS NOTE").font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                    Text("When the net force on an object equals zero, it stays at rest. Newton called this his First Law of Motion.")
                        .font(.system(size: 16)).foregroundStyle(.secondary).lineSpacing(5)
                }
                .padding(24)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.10)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    }.shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
                }
                .padding(.horizontal, 28).opacity(buttonOpacity)
                Spacer()
                HStack(spacing: 16) {
                    Button { onBack() } label: {
                        Text("Back").font(.system(size: 20, weight: .medium)).foregroundStyle(.primary)
                            .frame(width: 140, height: 64)
                            .background(Capsule().strokeBorder(Color.primary.opacity(0.35), lineWidth: 1.5))
                    }
                    Button { onContinue() } label: {
                        Text("Try Again").font(.system(size: 20, weight: .medium)).foregroundStyle(.white)
                            .frame(width: 140, height: 64).background(Capsule().fill(Color.primary))
                    }
                }.opacity(buttonOpacity).padding(.bottom, 56)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) { line1 = 1 }
            withAnimation(.easeOut(duration: 0.7).delay(0.7)) { line2 = 1 }
            withAnimation(.easeOut(duration: 0.6).delay(1.2)) { line3 = 1 }
            withAnimation(.spring(response: 0.5).delay(1.6)) { wordOpacity = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(1.8)) { buttonOpacity = 1 }
        }
    }
}

// MARK: - Hit 1G Challenge
struct HitGChallengeView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentLevel = 1
    var body: some View {
        ZStack {
            if currentLevel == 1 {
                GLevelView(level: 1, targetG: 1.0, toleranceG: 0.08, holdSeconds: 3.0,
                           instruction: "Lay your phone flat on a surface",
                           useZAxis: false,
                           onComplete: { currentLevel = 2 }, onDismiss: { dismiss() }).id("level1")
            } else {
                GLevelView(level: 2, targetG: 0.5, toleranceG: 0.06, holdSeconds: 3.0,
                           instruction: "Tilt your phone to ~60° from flat",
                           useZAxis: true,
                           onComplete: { dismiss() }, onDismiss: { dismiss() }).id("level2")
            }
        }.animation(.easeInOut(duration: 0.4), value: currentLevel)
    }
}

struct GLevelView: View {
    @StateObject private var motion = MotionManager()
    let level: Int; let targetG: Double; let toleranceG: Double
    let holdSeconds: Double; let instruction: String
    let useZAxis: Bool
    let onComplete: () -> Void; let onDismiss: () -> Void
    @State private var holdTime: Double = 0; @State private var isInZone: Bool = false
    @State private var levelComplete: Bool = false; @State private var showExplanation: Bool = false
    @State private var screenFlash: Double = 0; @State private var smoothedG: Double = 1.0
    let physicsTimer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()
    var holdProgress: Double { min(holdTime / holdSeconds, 1.0) }
    var needleAngle: Double { (max(0, min(smoothedG, 2.0)) / 2.0) * 180.0 - 90.0 }
    var targetAngle: Double { (targetG / 2.0) * 180.0 - 90.0 }
    var toleranceAngle: Double { (toleranceG / 2.0) * 180.0 }
    var zoneColor: Color { isInZone ? Color(red: 0.29, green: 0.72, blue: 0.48) : Color(red: 0.29, green: 0.50, blue: 0.83) }

    var body: some View {
        ZStack {
            SkyBackground()
            Color.green.opacity(screenFlash).ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("LEVEL \(level)").font(.system(size: 14, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                    Text("Hit \(String(format: "%.1f", targetG))g").font(.system(size: 52, weight: .light)).tracking(-1).foregroundStyle(.primary)
                    Text(instruction).font(.system(size: 17, weight: .regular, design: .monospaced)).foregroundStyle(.secondary)
                }.padding(.top, 60)
                Spacer()
                ZStack {
                    GaugeArcShape().stroke(Color.primary.opacity(0.07), style: StrokeStyle(lineWidth: 18, lineCap: .round)).frame(width: 340, height: 180)
                    GaugeZoneShape(centerAngle: targetAngle, halfWidth: toleranceAngle)
                        .stroke(zoneColor.opacity(0.25), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .frame(width: 340, height: 180).animation(.easeInOut(duration: 0.3), value: isInZone)
                    ForEach([0.0, 0.5, 1.0, 1.5, 2.0], id: \.self) { g in
                        let angle = (g / 2.0) * 180.0 - 90.0; let rads = angle * .pi / 180.0; let r: CGFloat = 204
                        Text(String(format: "%.1f", g)).font(.system(size: 12, weight: .regular, design: .monospaced)).foregroundStyle(.secondary)
                            .position(x: 170 + r * CGFloat(cos(rads)), y: 180 + r * CGFloat(sin(rads)))
                    }
                    NeedleView(angle: needleAngle, color: zoneColor).frame(width: 340, height: 180)
                        .animation(.spring(response: 0.15, dampingFraction: 0.7), value: needleAngle)
                    Circle().fill(Color.primary).frame(width: 14, height: 14).position(x: 170, y: 180)
                    VStack(spacing: 2) {
                        Text(String(format: "%.3f", smoothedG)).font(.system(size: 44, weight: .light, design: .monospaced))
                            .foregroundStyle(zoneColor).animation(.easeInOut(duration: 0.1), value: isInZone)
                        Text("g-force").font(.system(size: 14, weight: .regular, design: .monospaced)).foregroundStyle(.secondary)
                    }.position(x: 170, y: 110)
                }.frame(width: 340, height: 220)
                Spacer()
                VStack(spacing: 10) {
                    Text(isInZone ? "hold it..." : "find the zone")
                        .font(.system(size: 17, weight: .regular, design: .monospaced)).foregroundStyle(.secondary)
                        .animation(.easeInOut(duration: 0.2), value: isInZone)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08)).frame(width: 260, height: 8)
                        RoundedRectangle(cornerRadius: 4).fill(zoneColor).frame(width: 260 * holdProgress, height: 8)
                            .animation(.linear(duration: 0.1), value: holdProgress)
                    }
                    Text(isInZone ? String(format: "%.1fs / %.0fs", holdTime, holdSeconds) : "target: \(String(format: "%.1f", targetG))g ± \(String(format: "%.2f", toleranceG))g")
                        .font(.system(size: 14, weight: .regular, design: .monospaced)).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { onDismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .medium))
                        Text("Back").font(.system(size: 16))
                    }.foregroundStyle(.primary)
                }
            }
        }
        .onReceive(physicsTimer) { _ in updateReading(); checkZone() }
        .fullScreenCover(isPresented: $showExplanation) {
            GExplanationView(level: level, targetG: targetG) { showExplanation = false; onComplete() }
        }
    }

    func updateReading() {
        let raw = useZAxis ? abs(motion.gravityZ) : motion.totalG
        smoothedG = 0.25 * raw + 0.75 * smoothedG
    }
    func checkZone() {
        isInZone = abs(smoothedG - targetG) <= toleranceG
        if isInZone {
            holdTime += 1.0 / 60.0
            if holdTime >= holdSeconds && !levelComplete {
                levelComplete = true
                withAnimation(.easeIn(duration: 0.2)) { screenFlash = 0.3 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation { screenFlash = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showExplanation = true }
                }
            }
        } else { holdTime = max(0, holdTime - 1.5 / 60.0) }
    }
}

struct GaugeArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY), radius: rect.width / 2,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        return p
    }
}

struct GaugeZoneShape: Shape {
    let centerAngle: Double; let halfWidth: Double
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY), radius: rect.width / 2,
                 startAngle: .degrees(centerAngle - halfWidth + 180),
                 endAngle: .degrees(centerAngle + halfWidth + 180), clockwise: false)
        return p
    }
}

struct NeedleView: View {
    let angle: Double; let color: Color
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height)
            let rads = (angle + 90) * .pi / 180.0; let len: CGFloat = geo.size.width / 2 - 16
            Path { p in
                p.move(to: center)
                p.addLine(to: CGPoint(x: center.x + len * CGFloat(cos(rads)), y: center.y + len * CGFloat(sin(rads))))
            }.stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
    }
}

struct GExplanationView: View {
    let level: Int; let targetG: Double; let onContinue: () -> Void
    @State private var contentOpacity: Double = 0; @State private var buttonOpacity: Double = 0
    var explanation: (title: String, body: String, note: String, keyword: String) {
        level == 1 ?
        ("You measured Earth's gravity.",
         "When your phone lies flat, the accelerometer feels the full pull of Earth beneath it. That pull is exactly 1g — 9.8 metres per second, every second.",
         "Every object on Earth's surface experiences 1g of gravitational acceleration at rest. Astronauts in orbit feel 0g. Fighter pilots can experience up to 9g.",
         "1g = 9.8 m/s²") :
        ("You isolated a force component.",
         "Tilting your phone means gravity is no longer pulling straight into the screen. The accelerometer now only measures part of gravity — the component along one axis. At 30°, that's exactly 0.5g.",
         "This is called vector decomposition. Forces have both direction and magnitude. By tilting, you changed which component your sensor could detect.",
         "vector components")
    }
    var body: some View {
        ZStack {
            SkyBackground()
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    Circle().fill(Color(red: 0.29, green: 0.72, blue: 0.48).opacity(0.1)).frame(width: 80, height: 80)
                    Image(systemName: "gauge.with.needle").font(.system(size: 24, weight: .light)).foregroundStyle(Color(red: 0.29, green: 0.72, blue: 0.48))
                }.opacity(contentOpacity).padding(.bottom, 40)
                VStack(alignment: .leading, spacing: 20) {
                    Text(explanation.title).font(.system(size: 32, weight: .light)).tracking(-0.5).foregroundStyle(.primary)
                    Text(explanation.body).font(.system(size: 20)).foregroundStyle(.secondary).lineSpacing(6)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("The key concept:").font(.system(size: 20)).foregroundStyle(.secondary)
                        Text(explanation.keyword).font(.system(size: 20, weight: .medium)).foregroundStyle(Color(red: 0.29, green: 0.50, blue: 0.83))
                    }
                }.padding(.horizontal, 36).opacity(contentOpacity)
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text("PHYSICS NOTE").font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                    Text(explanation.note).font(.system(size: 16)).foregroundStyle(.secondary).lineSpacing(5)
                }
                .padding(24)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.10)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    }.shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
                }
                .padding(.horizontal, 28).opacity(buttonOpacity)
                Spacer()
                Button { onContinue() } label: {
                    Text(level < 2 ? "Next Level →" : "Done").font(.system(size: 20, weight: .medium)).foregroundStyle(.white)
                        .frame(width: 240, height: 64).background(Capsule().fill(Color.primary))
                }.opacity(buttonOpacity).padding(.bottom, 56)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7).delay(0.2)) { contentOpacity = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.8)) { buttonOpacity = 1 }
        }
    }
}

// MARK: - Motion Art
struct TrailPoint: Identifiable {
    let id = UUID(); var x: CGFloat; var y: CGFloat
    var acceleration: Double; var age: Double; var size: CGFloat
}
struct BurstParticle: Identifiable {
    let id = UUID(); var x: CGFloat; var y: CGFloat
    var velX: CGFloat; var velY: CGFloat; var opacity: Double; var size: CGFloat; var color: Color
}

struct MotionArtView: View {
    @StateObject private var motion = MotionManager()
    @Environment(\.dismiss) var dismiss
    @State private var trailPoints: [TrailPoint] = []
    @State private var burstParticles: [BurstParticle] = []
    @State private var cursorX: CGFloat = 0; @State private var cursorY: CGFloat = 0
    @State private var sessionTime: Double = 0; @State private var peakAccel: Double = 0
    @State private var totalAccel: Double = 0; @State private var frameCount: Double = 0
    @State private var showSummary: Bool = false; @State private var sessionRunning: Bool = false
    @State private var countdown: Int = 3; @State private var countdownDone: Bool = false
    let sessionDuration: Double = 15.0
    let physicsTimer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()
    var averageAccel: Double { frameCount > 0 ? totalAccel / frameCount : 0 }
    var sessionProgress: Double { min(sessionTime / sessionDuration, 1.0) }
    var timeRemaining: Int { max(0, Int(sessionDuration - sessionTime)) }

    func accelColor(_ accel: Double) -> Color {
        let t = min(accel / 3.0, 1.0)
        switch t {
        case 0..<0.2: return Color(red: 0.40, green: 0.65, blue: 0.95)
        case 0.2..<0.4: return Color(red: 0.30, green: 0.80, blue: 0.75)
        case 0.4..<0.6: return Color(red: 0.35, green: 0.80, blue: 0.45)
        case 0.6..<0.8: return Color(red: 0.95, green: 0.78, blue: 0.25)
        case 0.8..<0.9: return Color(red: 0.95, green: 0.50, blue: 0.20)
        default: return Color(red: 0.90, green: 0.25, blue: 0.30)
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea()
                if !countdownDone {
                    VStack(spacing: 20) {
                        Text("Motion Art").font(.system(size: 42, weight: .light)).foregroundStyle(.white.opacity(0.9))
                        Text("Move your phone freely").font(.system(size: 18, weight: .regular, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
                        Spacer().frame(height: 40)
                        Text("\(countdown)").font(.system(size: 110, weight: .light, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
                            .id(countdown).transition(.scale.combined(with: .opacity))
                        Text("starting in...").font(.system(size: 16, weight: .regular, design: .monospaced)).foregroundStyle(.white.opacity(0.3))
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Canvas { context, _ in
                        for point in trailPoints {
                            let fadeAge = max(0, 1.0 - point.age / 2.5)
                            let color = accelColor(point.acceleration)
                            let rect = CGRect(x: point.x - point.size/2, y: point.y - point.size/2, width: point.size, height: point.size)
                            context.opacity = fadeAge * 0.85
                            context.fill(Path(ellipseIn: rect), with: .color(color))
                            let glowRect = rect.insetBy(dx: -point.size * 0.5, dy: -point.size * 0.5)
                            context.opacity = fadeAge * 0.2
                            context.fill(Path(ellipseIn: glowRect), with: .color(color))
                        }
                    }.ignoresSafeArea().allowsHitTesting(false)
                    ForEach(burstParticles) { p in
                        Circle().fill(p.color).frame(width: p.size, height: p.size)
                            .position(x: p.x, y: p.y).opacity(p.opacity).allowsHitTesting(false)
                    }
                    VStack(spacing: 0) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("PEAK").font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
                                Text(String(format: "%.1fg", peakAccel)).font(.system(size: 24, weight: .light, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
                            }
                            Spacer()
                            VStack(spacing: 3) {
                                Text("\(timeRemaining)s").font(.system(size: 30, weight: .light, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.1)).frame(width: 100, height: 4)
                                    RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.5)).frame(width: 100 * (1 - sessionProgress), height: 4)
                                        .animation(.linear(duration: 0.1), value: sessionProgress)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("NOW").font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
                                Text(String(format: "%.2fg", motion.totalUserAccel)).font(.system(size: 24, weight: .light, design: .monospaced))
                                    .foregroundStyle(accelColor(motion.totalUserAccel).opacity(0.9))
                            }
                        }.padding(.horizontal, 28).padding(.top, 60)
                        Spacer()
                        Text("shake for a burst").font(.system(size: 14, weight: .regular, design: .monospaced)).foregroundStyle(.white.opacity(0.2)).padding(.bottom, 56)
                    }
                }
            }
            .onAppear { cursorX = geo.size.width / 2; cursorY = geo.size.height / 2; startCountdown() }
            .onReceive(physicsTimer) { _ in if countdownDone && sessionRunning { updateSession(in: geo.size) } }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .medium))
                        Text("Back").font(.system(size: 16))
                    }.foregroundStyle(countdownDone ? .white.opacity(0.7) : .primary)
                }
            }
        }
        .fullScreenCover(isPresented: $showSummary) {
            MotionArtSummaryView(peakAccel: peakAccel, averageAccel: averageAccel,
                                 onRetry: { showSummary = false; resetSession() },
                                 onDismiss: { showSummary = false; dismiss() })
        }
    }

    func startCountdown() {
        countdown = 3
        Task { @MainActor in
            while countdown > 1 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                withAnimation(.easeInOut(duration: 0.3)) { countdown -= 1 }
            }
            withAnimation { countdownDone = true }
            sessionRunning = true
        }
    }

    func updateSession(in size: CGSize) {
        sessionTime += 1.0 / 60.0; frameCount += 1
        let accel = motion.totalUserAccel; totalAccel += accel
        if accel > peakAccel { peakAccel = accel }
        let sensitivity: CGFloat = 320.0
        cursorX += CGFloat(motion.userAccelX) * sensitivity
        cursorY -= CGFloat(motion.userAccelY) * sensitivity
        cursorX = max(0, min(size.width, cursorX)); cursorY = max(0, min(size.height, cursorY))
        trailPoints.append(TrailPoint(x: cursorX, y: cursorY, acceleration: accel, age: 0, size: CGFloat(3 + accel * 8)))
        for i in trailPoints.indices { trailPoints[i].age += 1.0 / 60.0 }
        trailPoints.removeAll { $0.age > 2.5 }
        if accel > 2.0 { spawnBurst(at: CGPoint(x: cursorX, y: cursorY), strength: accel) }
        for i in burstParticles.indices {
            burstParticles[i].x += burstParticles[i].velX; burstParticles[i].y += burstParticles[i].velY
            burstParticles[i].velX *= 0.93; burstParticles[i].velY *= 0.93; burstParticles[i].opacity -= 0.025
        }
        burstParticles.removeAll { $0.opacity <= 0 }
        if sessionTime >= sessionDuration { sessionRunning = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showSummary = true } }
    }

    func spawnBurst(at point: CGPoint, strength: Double) {
        for _ in 0..<Int(min(strength * 6, 20)) {
            let angle = Double.random(in: 0...(2 * .pi)); let speed = CGFloat.random(in: 2...8) * CGFloat(strength * 0.4)
            burstParticles.append(BurstParticle(x: point.x, y: point.y, velX: CGFloat(cos(angle)) * speed,
                velY: CGFloat(sin(angle)) * speed, opacity: Double.random(in: 0.6...1.0),
                size: CGFloat.random(in: 3...8), color: accelColor(strength)))
        }
    }

    func resetSession() {
        trailPoints = []; burstParticles = []; sessionTime = 0; peakAccel = 0; totalAccel = 0
        frameCount = 0; countdownDone = false; sessionRunning = false; startCountdown()
    }
}

struct MotionArtSummaryView: View {
    let peakAccel: Double; let averageAccel: Double
    let onRetry: () -> Void; let onDismiss: () -> Void
    @State private var contentOpacity: Double = 0; @State private var statsOpacity: Double = 0; @State private var buttonOpacity: Double = 0

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    Circle().fill(Color(red: 0.83, green: 0.51, blue: 0.29).opacity(0.15)).frame(width: 80, height: 80)
                    Image(systemName: "sparkles").font(.system(size: 28, weight: .light)).foregroundStyle(Color(red: 0.83, green: 0.51, blue: 0.29))
                }.opacity(contentOpacity).padding(.bottom, 36)
                VStack(alignment: .leading, spacing: 16) {
                    Text("You just made acceleration visible.")
                        .font(.system(size: 32, weight: .light)).tracking(-0.5).foregroundStyle(.white.opacity(0.9))
                    Text("Every colour in your drawing represents a force. Blue is calm. Red is a sudden push. The trail is a map of every moment you changed speed or direction.")
                        .font(.system(size: 19)).foregroundStyle(.white.opacity(0.5)).lineSpacing(6)
                }.padding(.horizontal, 36).opacity(contentOpacity)
                Spacer()
                VStack(spacing: 0) {
                    HStack {
                        VStack(spacing: 6) {
                            Text(String(format: "%.1fg", peakAccel)).font(.system(size: 48, weight: .light, design: .monospaced)).foregroundStyle(Color(red: 0.90, green: 0.25, blue: 0.30))
                            Text("PEAK").font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.3))
                        }
                        Spacer(); Rectangle().fill(.white.opacity(0.08)).frame(width: 1, height: 50); Spacer()
                        VStack(spacing: 6) {
                            Text(String(format: "%.1fg", averageAccel)).font(.system(size: 48, weight: .light, design: .monospaced)).foregroundStyle(Color(red: 0.40, green: 0.65, blue: 0.95))
                            Text("AVERAGE").font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.3))
                        }
                    }.padding(28)
                    Divider().background(.white.opacity(0.08))
                    Text("Acceleration = any change in speed or direction.\nEven turning feels like a force.")
                        .font(.system(size: 15, design: .monospaced)).foregroundStyle(.white.opacity(0.3))
                        .multilineTextAlignment(.center).lineSpacing(5).padding(20)
                }
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    }.shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
                }
                .padding(.horizontal, 28).opacity(statsOpacity)
                Spacer()
                HStack(spacing: 16) {
                    Button { onDismiss() } label: {
                        Text("Done").font(.system(size: 20, weight: .regular)).foregroundStyle(.white.opacity(0.6))
                            .frame(width: 130, height: 64).background(Capsule().fill(.white.opacity(0.08)))
                    }
                    Button { onRetry() } label: {
                        Text("Draw Again").font(.system(size: 20, weight: .medium)).foregroundStyle(.white)
                            .frame(width: 200, height: 64).background(Capsule().fill(Color(red: 0.83, green: 0.51, blue: 0.29)))
                    }
                }.opacity(buttonOpacity).padding(.bottom, 56)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7).delay(0.2)) { contentOpacity = 1 }
            withAnimation(.easeOut(duration: 0.6).delay(0.7)) { statsOpacity = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(1.1)) { buttonOpacity = 1 }
        }
    }
}

// MARK: - Pendulum Timer View
struct PendulumTimerView: View {
    @StateObject private var motion = MotionManager()
    @Environment(\.dismiss) var dismiss

    // Swing detection
    @State private var swingPeaks: [Double] = []       // timestamps of detected peaks
    @State private var lastPeakTime: Double = 0
    @State private var lastSignal: Double = 0
    @State private var wasPositive: Bool = false
    @State private var swingCount: Int = 0

    // Results
    @State private var period: Double = 0              // seconds per full swing
    @State private var armLength: Double = 0           // calculated in metres
    @State private var isSwinging: Bool = false
    @State private var sessionTime: Double = 0
    @State private var showExplanation: Bool = false
    @State private var peakHistory: [Double] = []      // last 6 peak values for waveform

    // Animation
    @State private var pendulumAngle: Double = 0
    @State private var pendulumDirection: Double = 1

    let physicsTimer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()
    let g: Double = 9.81

    // L = g × (T / 2π)²
    var calculatedLength: Double {
        guard period > 0 else { return 0 }
        let t = period / (2 * .pi)
        return g * t * t
    }

    var readyToShow: Bool { swingPeaks.count >= 4 }

    var body: some View {
        ZStack {
            SkyBackground()

            VStack(spacing: 0) {

                // Header
                VStack(spacing: 6) {
                    Text("PENDULUM TIMER")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("Swing your phone")
                        .font(.system(size: 46, weight: .light))
                        .tracking(-0.8).foregroundStyle(.primary)
                    Text("hold it by your side, swing like a pendulum")
                        .font(.system(size: 16, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 56)

                Spacer()

                // Pendulum visual
                ZStack(alignment: .top) {
                    // Pivot point
                    Circle()
                        .fill(Color.primary.opacity(0.3))
                        .frame(width: 14, height: 14)
                        .offset(y: 0)

                    // Rod + Bob
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.primary.opacity(0.15))
                            .frame(width: 3, height: 180)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color(red: 0.60, green: 0.35, blue: 0.80).opacity(0.9),
                                             Color(red: 0.40, green: 0.20, blue: 0.60)],
                                    center: .init(x: 0.35, y: 0.3),
                                    startRadius: 2,
                                    endRadius: 28
                                )
                            )
                            .frame(width: 52, height: 52)
                            .shadow(color: Color(red: 0.60, green: 0.35, blue: 0.80).opacity(0.4), radius: 16, x: 0, y: 6)
                    }
                    .rotationEffect(.degrees(pendulumAngle), anchor: .top)
                    .animation(.easeInOut(duration: period > 0 ? period / 2 : 0.8), value: pendulumAngle)
                }
                .frame(height: 260)

                Spacer()

                // Live waveform bars
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(peakHistory.suffix(8).enumerated()), id: \.offset) { i, val in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.60, green: 0.35, blue: 0.80).opacity(0.6 + Double(i) * 0.05))
                            .frame(width: 22, height: CGFloat(val * 80 + 10))
                            .animation(.spring(response: 0.3), value: val)
                    }
                }
                .frame(height: 80)
                .padding(.bottom, 8)

                Text(isSwinging ? "detecting swings..." : "start swinging to measure")
                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)

                // Stats cards
                HStack(spacing: 12) {
                    StatCard(
                        label: "PERIOD",
                        value: readyToShow ? String(format: "%.2fs", period) : "—",
                        unit: "per swing",
                        color: Color(red: 0.60, green: 0.35, blue: 0.80)
                    )
                    StatCard(
                        label: "ARM LENGTH",
                        value: readyToShow ? String(format: "%.0fcm", calculatedLength * 100) : "—",
                        unit: "calculated",
                        color: Color(red: 0.29, green: 0.50, blue: 0.83)
                    )
                    StatCard(
                        label: "SWINGS",
                        value: "\(swingCount)",
                        unit: "detected",
                        color: Color(red: 0.29, green: 0.72, blue: 0.48)
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                // Reveal button
                if readyToShow {
                    Button {
                        showExplanation = true
                    } label: {
                        Text("See the Physics →")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 280, height: 64)
                            .background(
                                Capsule().fill(Color(red: 0.60, green: 0.35, blue: 0.80))
                            )
                    }
                    .transition(.opacity.combined(with: .scale))
                    .padding(.bottom, 56)
                } else {
                    Text("swing at least 4 times to unlock")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .padding(.bottom, 56)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .medium))
                        Text("Back").font(.system(size: 16))
                    }.foregroundStyle(.primary)
                }
            }
        }
        .onReceive(physicsTimer) { _ in
            sessionTime += 1.0 / 60.0
            detectSwing()
            animatePendulum()
        }
        .fullScreenCover(isPresented: $showExplanation) {
            PendulumExplanationView(
                period: period,
                armLength: calculatedLength,
                swingCount: swingCount,
                onContinue: { showExplanation = false; resetSession() },
                onDismiss: { showExplanation = false; dismiss() }
            )
        }
    }

    // MARK: - Swing Detection
    // Use rotation rate X as the primary signal — it spikes at each half-swing apex
    func detectSwing() {
        let signal = motion.rotationRateX

        // Smooth to reduce noise
        let smoothed = signal * 0.3 + lastSignal * 0.7
        lastSignal = smoothed

        isSwinging = abs(smoothed) > 0.3

        // Peak detection: sign change with sufficient magnitude
        let isPos = smoothed > 0
        if isPos != wasPositive && abs(smoothed) > 0.4 {
            let now = sessionTime
            let timeSinceLast = now - lastPeakTime

            // A valid half-period is between 0.2s and 3.0s
            if timeSinceLast > 0.2 && timeSinceLast < 3.0 && lastPeakTime > 0 {
                swingPeaks.append(timeSinceLast)
                swingCount += 1
                peakHistory.append(min(abs(smoothed) / 3.0, 1.0))
                if peakHistory.count > 8 { peakHistory.removeFirst() }

                // Full period = 2 half-periods
                if swingPeaks.count >= 2 {
                    let recentHalves = swingPeaks.suffix(6)
                    let avgHalf = recentHalves.reduce(0, +) / Double(recentHalves.count)
                    period = avgHalf * 2.0
                }
            }

            lastPeakTime = now
        }
        wasPositive = isPos
    }

    func animatePendulum() {
        // Animate pendulum bob to mirror actual swing
        if isSwinging {
            let targetAngle = motion.rotationRateX * 15.0
            withAnimation(.easeInOut(duration: 0.1)) {
                pendulumAngle = targetAngle
            }
        } else {
            // Slowly return to center
            withAnimation(.easeOut(duration: 0.5)) { pendulumAngle = 0 }
        }
    }

    func resetSession() {
        swingPeaks = []; swingCount = 0; period = 0; armLength = 0
        lastPeakTime = 0; lastSignal = 0; peakHistory = []; sessionTime = 0; isSwinging = false
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 26, weight: .light, design: .monospaced))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
            Text(unit)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.55), .white.opacity(0.10)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
        }
    }
}

// MARK: - Pendulum Explanation View
struct PendulumExplanationView: View {
    let period: Double
    let armLength: Double
    let swingCount: Int
    let onContinue: () -> Void
    let onDismiss: () -> Void

    @State private var contentOpacity: Double = 0
    @State private var mathOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    var body: some View {
        ZStack {
            SkyBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    // Icon
                    ZStack {
                        Circle().fill(Color(red: 0.60, green: 0.35, blue: 0.80).opacity(0.1)).frame(width: 80, height: 80)
                        Image(systemName: "figure.walk").font(.system(size: 28, weight: .light))
                            .foregroundStyle(Color(red: 0.60, green: 0.35, blue: 0.80))
                    }
                    .opacity(contentOpacity)
                    .padding(.bottom, 36)

                    // Headline
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Your phone just measured your arm.")
                            .font(.system(size: 32, weight: .light)).tracking(-0.5).foregroundStyle(.primary)

                        Text("You swung \(swingCount) times. Each swing took \(String(format: "%.2f", period)) seconds. Using just that number and the strength of gravity, the app calculated the length of your pendulum arm.")
                            .font(.system(size: 20)).foregroundStyle(.secondary).lineSpacing(6)
                    }
                    .padding(.horizontal, 36)
                    .opacity(contentOpacity)

                    Spacer().frame(height: 36)

                    // Math card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("THE FORMULA")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)

                        // T = 2π√(L/g)
                        HStack(spacing: 0) {
                            Text("T = 2π")
                                .font(.system(size: 24, weight: .light, design: .monospaced))
                                .foregroundStyle(.primary)
                            Text("√")
                                .font(.system(size: 28, weight: .light, design: .monospaced))
                                .foregroundStyle(Color(red: 0.60, green: 0.35, blue: 0.80))
                            Text("(L/g)")
                                .font(.system(size: 24, weight: .light, design: .monospaced))
                                .foregroundStyle(.primary)
                        }

                        Divider()

                        // Your numbers
                        VStack(spacing: 12) {
                            HStack {
                                Text("T (period)").font(.system(size: 16, design: .monospaced)).foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.2f s", period)).font(.system(size: 16, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.60, green: 0.35, blue: 0.80))
                            }
                            HStack {
                                Text("g (gravity)").font(.system(size: 16, design: .monospaced)).foregroundStyle(.secondary)
                                Spacer()
                                Text("9.81 m/s²").font(.system(size: 16, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.29, green: 0.50, blue: 0.83))
                            }
                            HStack {
                                Text("L (your arm)").font(.system(size: 16, design: .monospaced)).foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.1f cm", armLength * 100)).font(.system(size: 16, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.29, green: 0.72, blue: 0.48))
                            }
                        }
                    }
                    .padding(24)
                    .background {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.10)],
                                                      startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                        }.shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                    }
                    .padding(.horizontal, 28)
                    .opacity(mathOpacity)

                    Spacer().frame(height: 24)

                    // Physics note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PHYSICS NOTE")
                            .font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                        Text("Galileo discovered that a pendulum's period depends only on its length — not its weight or how wide it swings. He used a chandelier swinging in a cathedral to measure time with just his pulse.")
                            .font(.system(size: 16)).foregroundStyle(.secondary).lineSpacing(5)
                    }
                    .padding(24)
                    .background {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.10)],
                                                      startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                        }.shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
                    }
                    .padding(.horizontal, 28)
                    .opacity(mathOpacity)

                    Spacer().frame(height: 40)

                    // Buttons
                    HStack(spacing: 16) {
                        Button { onDismiss() } label: {
                            Text("Done")
                                .font(.system(size: 20, weight: .regular)).foregroundStyle(.secondary)
                                .frame(width: 130, height: 64)
                                .background(Capsule().fill(Color.primary.opacity(0.08)))
                        }
                        Button { onContinue() } label: {
                            Text("Try Again")
                                .font(.system(size: 20, weight: .medium)).foregroundStyle(.white)
                                .frame(width: 200, height: 64)
                                .background(Capsule().fill(Color(red: 0.60, green: 0.35, blue: 0.80)))
                        }
                    }
                    .opacity(buttonOpacity)
                    .padding(.bottom, 56)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7).delay(0.2)) { contentOpacity = 1 }
            withAnimation(.easeOut(duration: 0.6).delay(0.8)) { mathOpacity = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(1.2)) { buttonOpacity = 1 }
        }
    }
}

// MARK: - Predict & Move Game

/// A single point on the graph timeline
struct GraphPoint: Identifiable {
    let id = UUID()
    var time: CGFloat   // 0…10 seconds
    var value: CGFloat   // acceleration in m/s²
}

/// Phase of the Predict & Move activity
enum PredictPhase: Int, CaseIterable {
    case predict, record, compare, reflect, annotate
}

struct PredictMoveView: View {
    @StateObject private var motion = MotionManager()
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    // Phase
    @State private var phase: PredictPhase = .predict

    // Graph data
    @State private var predictedPoints: [GraphPoint] = []
    @State private var recordedPoints: [GraphPoint] = []

    // Drawing state (prediction)
    @State private var isDrawing = false

    // Recording state
    @State private var recordingTime: Double = 0
    @State private var isRecording = false
    @State private var countdown: Int = 3
    @State private var countdownDone = false
    @State private var smoothedAccel: Double = 0

    // Reflection
    @State private var tappedRegion: Int? = nil

    // Annotation
    @State private var annotationNote: String = ""
    @State private var circledRegions: [CGPoint] = []

    // Transitions
    @State private var phaseOpacity: Double = 1

    let sessionDuration: CGFloat = 10.0
    let accelRange: CGFloat = 3.0 // ±3 m/s²
    let physicsTimer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()

    // MARK: - Body
    var body: some View {
        ZStack {
            SkyBackground()
            VStack(spacing: 0) {
                // Phase indicator
                phaseBar
                    .padding(.top, 16).padding(.horizontal, 28)

                switch phase {
                case .predict:  predictionPhaseView
                case .record:   recordingPhaseView
                case .compare:  comparisonPhaseView
                case .reflect:  reflectionPhaseView
                case .annotate: annotatePhaseView
                }
            }
            .opacity(phaseOpacity)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .medium))
                        Text("Back").font(.system(size: 16))
                    }.foregroundStyle(.primary)
                }
            }
        }
        .onReceive(physicsTimer) { _ in
            if phase == .record && isRecording { updateRecording() }
        }
    }

    // MARK: - Phase Bar
    var phaseBar: some View {
        HStack(spacing: 6) {
            ForEach(PredictPhase.allCases, id: \.rawValue) { p in
                VStack(spacing: 4) {
                    Circle()
                        .fill(p.rawValue <= phase.rawValue
                              ? Color(red: 0.85, green: 0.30, blue: 0.40)
                              : Color.primary.opacity(0.15))
                        .frame(width: 10, height: 10)
                    Text(phaseLabel(p))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(p == phase ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    func phaseLabel(_ p: PredictPhase) -> String {
        switch p {
        case .predict: return "PREDICT"
        case .record:  return "MOVE"
        case .compare: return "COMPARE"
        case .reflect: return "REFLECT"
        case .annotate: return "ANNOTATE"
        }
    }

    // MARK: - Step 1: Prediction Phase
    var predictionPhaseView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Sketch Your Prediction")
                    .font(.system(size: 32, weight: .light)).tracking(-0.5).foregroundStyle(.primary)
                Text("\"Walk forward, stop, then walk faster.\"\nWhat does the acceleration graph look like?")
                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(4)
            }.padding(.top, 32).padding(.horizontal, 28)

            Spacer()

            // Drawing canvas
            graphCanvas(
                predictedLine: predictedPoints,
                recordedLine: [],
                allowDrawing: true,
                showGrid: true
            )
            .padding(.horizontal, 24)

            Spacer()

            HStack(spacing: 16) {
                Button { predictedPoints = [] } label: {
                    Text("Clear")
                        .font(.system(size: 17, weight: .regular)).foregroundStyle(.secondary)
                        .frame(width: 100, height: 54)
                        .background(Capsule().fill(.ultraThinMaterial))
                }
                Button { advancePhase() } label: {
                    Text("Start Recording →")
                        .font(.system(size: 17, weight: .medium)).foregroundStyle(.white)
                        .frame(width: 220, height: 54)
                        .background(Capsule().fill(Color(red: 0.85, green: 0.30, blue: 0.40)))
                }
                .disabled(predictedPoints.count < 3)
                .opacity(predictedPoints.count < 3 ? 0.4 : 1)
            }
            .padding(.bottom, 48)
        }
    }

    // MARK: - Step 2: Recording Phase
    var recordingPhaseView: some View {
        VStack(spacing: 0) {
            if !countdownDone {
                Spacer()
                VStack(spacing: 20) {
                    Text("Get ready to walk")
                        .font(.system(size: 28, weight: .light)).foregroundStyle(.primary)
                    Text("Hold your phone in hand, arms by your side")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Spacer().frame(height: 24)
                    Text("\(countdown)")
                        .font(.system(size: 80, weight: .light, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.8))
                        .id(countdown).transition(.scale.combined(with: .opacity))
                }
                Spacer()
            } else {
                VStack(spacing: 6) {
                    Text("Recording...")
                        .font(.system(size: 28, weight: .light)).foregroundStyle(.primary)
                    Text(String(format: "%.1fs / %.0fs", recordingTime, sessionDuration))
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                }.padding(.top, 32)

                // Progress bar
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.1)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 0.85, green: 0.30, blue: 0.40))
                        .frame(width: max(0, CGFloat(recordingTime / Double(sessionDuration)) * (UIScreen.main.bounds.width - 56)), height: 6)
                        .animation(.linear(duration: 0.1), value: recordingTime)
                }
                .padding(.horizontal, 28).padding(.top, 16)

                Spacer()

                graphCanvas(
                    predictedLine: [],
                    recordedLine: recordedPoints,
                    allowDrawing: false,
                    showGrid: true
                )
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .onAppear { startCountdown() }
    }

    // MARK: - Step 3: Comparison Phase
    var comparisonPhaseView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Compare")
                    .font(.system(size: 32, weight: .light)).tracking(-0.5).foregroundStyle(.primary)
                Text("grey = your prediction · blue = reality")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }.padding(.top, 32)

            Spacer()

            graphCanvas(
                predictedLine: predictedPoints,
                recordedLine: recordedPoints,
                allowDrawing: false,
                showGrid: true
            )
            .padding(.horizontal, 24)

            // Accuracy score
            let score = calculateAccuracy()
            VStack(spacing: 6) {
                Text("\(Int(score * 100))%")
                    .font(.system(size: 44, weight: .light, design: .monospaced))
                    .foregroundStyle(score > 0.7 ? Color(red: 0.29, green: 0.72, blue: 0.48) : Color(red: 0.85, green: 0.30, blue: 0.40))
                Text("PREDICTION ACCURACY")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }.padding(.top, 20)

            Spacer()

            Button { advancePhase() } label: {
                Text("Understand Why →")
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(.white)
                    .frame(width: 240, height: 54)
                    .background(Capsule().fill(Color(red: 0.85, green: 0.30, blue: 0.40)))
            }.padding(.bottom, 48)
        }
    }

    // MARK: - Step 4: Reflection Phase
    var reflectionPhaseView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Tap to Explore")
                    .font(.system(size: 32, weight: .light)).tracking(-0.5).foregroundStyle(.primary)
                Text("tap on any region of the graph")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }.padding(.top, 32)

            Spacer()

            // Interactive graph
            reflectionGraph
                .padding(.horizontal, 24)

            // Explanation card
            if let region = tappedRegion {
                let explanation = regionExplanation(region)
                VStack(alignment: .leading, spacing: 8) {
                    Text(explanation.title)
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                    Text(explanation.body)
                        .font(.system(size: 15)).foregroundStyle(.secondary).lineSpacing(4)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.10)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    }
                }
                .padding(.horizontal, 28).padding(.top, 16)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()

            Button { advancePhase() } label: {
                Text("Annotate & Retry →")
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(.white)
                    .frame(width: 240, height: 54)
                    .background(Capsule().fill(Color(red: 0.85, green: 0.30, blue: 0.40)))
            }.padding(.bottom, 48)
        }
    }

    // MARK: - Step 5: Annotate Phase
    var annotatePhaseView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("What Did You Learn?")
                    .font(.system(size: 32, weight: .light)).tracking(-0.5).foregroundStyle(.primary)
                Text("write a short reflection")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }.padding(.top, 32)

            Spacer()

            graphCanvas(
                predictedLine: predictedPoints,
                recordedLine: recordedPoints,
                allowDrawing: false,
                showGrid: true
            )
            .padding(.horizontal, 24)

            // Note input
            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR NOTE")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                TextField("e.g. Forgot acceleration is zero at constant speed…", text: $annotationNote, axis: .vertical)
                    .font(.system(size: 16))
                    .lineLimit(3...5)
                    .foregroundStyle(.primary)
            }
            .padding(20)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.10)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                }
            }
            .padding(.horizontal, 28).padding(.top, 16)

            // Physics note
            VStack(alignment: .leading, spacing: 8) {
                Text("KEY INSIGHT").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                Text("Acceleration is not speed. It's the rate of change of speed. A constant velocity means zero acceleration — even if you're moving fast.")
                    .font(.system(size: 14)).foregroundStyle(.secondary).lineSpacing(4)
            }
            .padding(20)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.10)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                }
            }
            .padding(.horizontal, 28).padding(.top, 12)

            Spacer()

            HStack(spacing: 16) {
                Button { dismiss() } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .regular)).foregroundStyle(.secondary)
                        .frame(width: 100, height: 54)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
                Button { retry() } label: {
                    Text("Try Again")
                        .font(.system(size: 17, weight: .medium)).foregroundStyle(.white)
                        .frame(width: 160, height: 54)
                        .background(Capsule().fill(Color(red: 0.85, green: 0.30, blue: 0.40)))
                }
            }.padding(.bottom, 48)
        }
    }

    // MARK: - Graph Canvas
    func graphCanvas(predictedLine: [GraphPoint], recordedLine: [GraphPoint],
                     allowDrawing: Bool, showGrid: Bool) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.white.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                if showGrid {
                    // Grid lines
                    Canvas { context, size in
                        let cols = 10; let rows = 6
                        for i in 0...cols {
                            let x = CGFloat(i) / CGFloat(cols) * size.width
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                            context.stroke(path, with: .color(.primary.opacity(0.06)), lineWidth: 0.5)
                        }
                        for i in 0...rows {
                            let y = CGFloat(i) / CGFloat(rows) * size.height
                            var path = Path()
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                            context.stroke(path, with: .color(.primary.opacity(0.06)), lineWidth: 0.5)
                        }
                        // Zero line (center)
                        var zeroPath = Path()
                        zeroPath.move(to: CGPoint(x: 0, y: size.height / 2))
                        zeroPath.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                        context.stroke(zeroPath, with: .color(.primary.opacity(0.18)), lineWidth: 1)
                    }
                    .padding(16)

                    // Axis labels
                    VStack {
                        HStack {
                            Text("+\(Int(accelRange))")
                                .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                            Spacer()
                        }
                        Spacer()
                        HStack {
                            Text("0").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                            Spacer()
                        }
                        Spacer()
                        HStack {
                            Text("-\(Int(accelRange))")
                                .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    .padding(.leading, 4).padding(.vertical, 14)

                    // Time labels
                    HStack {
                        Text("0s").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                        Spacer()
                        Text("5s").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                        Spacer()
                        Text("10s").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.bottom, 2)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }

                // Predicted line (grey)
                if !predictedLine.isEmpty {
                    graphPath(points: predictedLine, in: CGSize(width: w - 32, height: h - 32))
                        .stroke(
                            colorScheme == .dark ? Color.white.opacity(0.35) : Color.primary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )
                        .padding(16)
                }

                // Recorded line (blue/red accent)
                if !recordedLine.isEmpty {
                    graphPath(points: recordedLine, in: CGSize(width: w - 32, height: h - 32))
                        .stroke(
                            Color(red: 0.30, green: 0.55, blue: 0.95),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )
                        .padding(16)
                }

                // Difference fills (only in compare/reflect/annotate)
                if !predictedLine.isEmpty && !recordedLine.isEmpty && phase != .predict && phase != .record {
                    diffOverlay(predicted: predictedLine, recorded: recordedLine,
                                size: CGSize(width: w - 32, height: h - 32))
                        .padding(16)
                }

                // Drawing gesture
                if allowDrawing {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { value in
                                    let inset: CGFloat = 16
                                    let drawW = w - inset * 2
                                    let drawH = h - inset * 2
                                    let localX = value.location.x - inset
                                    let localY = value.location.y - inset
                                    let t = max(0, min(sessionDuration, (localX / drawW) * sessionDuration))
                                    let accel = ((0.5 - localY / drawH) * 2.0) * accelRange
                                    let clamped = max(-accelRange, min(accelRange, accel))

                                    // Remove points at or after this time to allow redrawing
                                    if !isDrawing {
                                        isDrawing = true
                                        predictedPoints.removeAll { $0.time >= t - 0.05 }
                                    }
                                    // If finger hasn't moved horizontally (vertical spike), update last point in-place
                                    if let lastIdx = predictedPoints.indices.last,
                                       predictedPoints[lastIdx].time >= t - 0.08 {
                                        predictedPoints[lastIdx] = GraphPoint(time: predictedPoints[lastIdx].time, value: clamped)
                                        return
                                    }
                                    predictedPoints.append(GraphPoint(time: t, value: clamped))
                                }
                                .onEnded { _ in isDrawing = false }
                        )
                }
            }
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Graph Path Builder
    func graphPath(points: [GraphPoint], in size: CGSize) -> Path {
        let sorted = points.sorted { $0.time < $1.time }
        guard sorted.count > 1 else { return Path() }
        var path = Path()
        for (i, pt) in sorted.enumerated() {
            let x = (pt.time / sessionDuration) * size.width
            let y = size.height / 2 - (pt.value / accelRange) * (size.height / 2)
            let point = CGPoint(x: x, y: y)
            if i == 0 { path.move(to: point) }
            else {
                let prev = sorted[i - 1]
                let px = (prev.time / sessionDuration) * size.width
                let py = size.height / 2 - (prev.value / accelRange) * (size.height / 2)
                let cp1 = CGPoint(x: (px + x) / 2, y: py)
                let cp2 = CGPoint(x: (px + x) / 2, y: y)
                path.addCurve(to: point, control1: cp1, control2: cp2)
            }
        }
        return path
    }

    // MARK: - Difference Overlay
    func diffOverlay(predicted: [GraphPoint], recorded: [GraphPoint], size: CGSize) -> some View {
        Canvas { context, canvasSize in
            // Sample both curves at regular intervals and shade difference
            let steps = 60
            for i in 0..<steps {
                let t = CGFloat(i) / CGFloat(steps) * sessionDuration
                let pVal = interpolateValue(at: t, in: predicted)
                let rVal = interpolateValue(at: t, in: recorded)
                let diff = abs(pVal - rVal)
                let x = (t / sessionDuration) * size.width
                let stripWidth = size.width / CGFloat(steps) + 1

                let isClose = diff < 0.5
                let color = isClose
                    ? Color(red: 0.29, green: 0.72, blue: 0.48).opacity(Double(max(0, 0.25 - diff * 0.3)))
                    : Color(red: 0.85, green: 0.30, blue: 0.40).opacity(Double(min(0.25, diff * 0.12)))

                let rect = CGRect(x: x, y: 0, width: stripWidth, height: size.height)
                context.fill(Path(rect), with: .color(color))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Reflection Graph (tappable)
    var reflectionGraph: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Base graph
                graphCanvas(
                    predictedLine: predictedPoints,
                    recordedLine: recordedPoints,
                    allowDrawing: false,
                    showGrid: true
                )

                // Invisible tap regions (split into 5 zones)
                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { zone in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.25)) { tappedRegion = zone }
                            }
                            .overlay(
                                tappedRegion == zone
                                    ? RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color(red: 0.85, green: 0.30, blue: 0.40).opacity(0.6), lineWidth: 2)
                                        .padding(2)
                                    : nil
                            )
                    }
                }
            }
        }
        .frame(height: 260)
    }

    // MARK: - Region Explanations
    func regionExplanation(_ region: Int) -> (title: String, body: String) {
        // Map 5 zones to the walk-stop-walk scenario
        switch region {
        case 0:
            return ("Start Acceleration",
                    "You began walking. Force was applied to change velocity from zero — this is a positive acceleration spike.")
        case 1:
            return ("Constant Velocity",
                    "You were walking at a steady pace. No change in speed means zero net acceleration, even though you were moving.")
        case 2:
            return ("Deceleration (Stop)",
                    "You slowed down and stopped. Deceleration is negative acceleration — a force opposing your motion.")
        case 3:
            return ("Second Acceleration",
                    "You started walking faster. A larger force produces a larger acceleration spike — Newton's Second Law (F = ma).")
        case 4:
            return ("Final Motion",
                    "The tail end of your movement. Any non-zero reading means your speed was still changing.")
        default:
            return ("", "")
        }
    }

    // MARK: - Interpolation helper
    func interpolateValue(at time: CGFloat, in points: [GraphPoint]) -> CGFloat {
        let sorted = points.sorted { $0.time < $1.time }
        guard !sorted.isEmpty else { return 0 }
        if time <= sorted.first!.time { return sorted.first!.value }
        if time >= sorted.last!.time { return sorted.last!.value }
        for i in 0..<sorted.count - 1 {
            if sorted[i].time <= time && sorted[i + 1].time >= time {
                let frac = (time - sorted[i].time) / (sorted[i + 1].time - sorted[i].time)
                return sorted[i].value + frac * (sorted[i + 1].value - sorted[i].value)
            }
        }
        return 0
    }

    // MARK: - Accuracy
    func calculateAccuracy() -> Double {
        guard !predictedPoints.isEmpty && !recordedPoints.isEmpty else { return 0 }
        var totalDiff: Double = 0
        let samples = 50
        for i in 0..<samples {
            let t = CGFloat(i) / CGFloat(samples) * sessionDuration
            let pVal = interpolateValue(at: t, in: predictedPoints)
            let rVal = interpolateValue(at: t, in: recordedPoints)
            totalDiff += Double(abs(pVal - rVal))
        }
        let avgDiff = totalDiff / Double(samples)
        // Normalise: 0 diff → 100%, 3 diff (full range) → 0%
        return max(0, min(1, 1.0 - avgDiff / Double(accelRange)))
    }

    // MARK: - Phase Transitions
    func advancePhase() {
        guard let next = PredictPhase(rawValue: phase.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.25)) { phaseOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            phase = next
            withAnimation(.easeInOut(duration: 0.3)) { phaseOpacity = 1 }
        }
    }

    // MARK: - Recording
    func startCountdown() {
        countdown = 3; countdownDone = false
        Task { @MainActor in
            while countdown > 1 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                withAnimation(.easeInOut(duration: 0.3)) { countdown -= 1 }
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation { countdownDone = true }
            isRecording = true
        }
    }

    func updateRecording() {
        recordingTime += 1.0 / 60.0
        // Heavy low-pass filter — suppress sensor noise so recorded graph is readable
        let rawAccel = motion.userAccelY * 9.81
        // Deadzone: ignore tiny drift below 0.25 m/s²
        let deadzoned = abs(rawAccel) < 0.25 ? 0.0 : rawAccel
        smoothedAccel = 0.08 * deadzoned + 0.92 * smoothedAccel
        // Only store a point every 4 frames to keep the line clean
        let frameIndex = Int(recordingTime * 60)
        if frameIndex % 4 == 0 {
            let t = CGFloat(recordingTime)
            let val = CGFloat(max(-Double(accelRange), min(Double(accelRange), smoothedAccel)))
            recordedPoints.append(GraphPoint(time: t, value: val))
        }
        if recordingTime >= Double(sessionDuration) {
            isRecording = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { advancePhase() }
        }
    }

    // MARK: - Retry
    func retry() {
        predictedPoints = []; recordedPoints = []
        recordingTime = 0; smoothedAccel = 0
        tappedRegion = nil; annotationNote = ""
        countdownDone = false; isRecording = false
        withAnimation(.easeInOut(duration: 0.25)) { phaseOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            phase = .predict
            withAnimation(.easeInOut(duration: 0.3)) { phaseOpacity = 1 }
        }
    }
}

// MARK: - Preview
#Preview {
    HomeView()
}
