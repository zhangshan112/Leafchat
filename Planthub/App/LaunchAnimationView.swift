import SwiftUI

// MARK: - LaunchAnimationView

/// Sketched tree launch animation.
///
/// Growth is physically accurate: branches sprout from the trunk exactly when
/// the trunk tip passes their attachment height, just as a real tree grows.
///
/// Trunk travels from y = 0.96 → 0.28  (Δy = 0.68 of canvas height, over 1.8 s)
///   Lower branch junction  y = 0.72  → trunk fraction 0.353 → fires at 0.64 s
///   Main  branch junction  y = 0.56  → trunk fraction 0.588 → fires at 1.06 s
///   Crown branch junction  y = 0.38  → trunk fraction 0.853 → fires at 1.54 s
struct LaunchAnimationView: View {
    let onFinished: () -> Void

    @State private var trunkProgress: CGFloat = 0
    @State private var lowerBranchProgress: CGFloat = 0
    @State private var mainBranchProgress: CGFloat = 0
    @State private var crownProgress: CGFloat = 0
    @State private var subBranchProgress: CGFloat = 0
    @State private var leafProgress: CGFloat = 0
    @State private var textOpacity: CGFloat = 0
    @State private var hasStarted = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    ZStack {
                        // Stage 1 — trunk, thick, slight sway upward
                        TreeTrunk(w: w, h: h)
                            .trim(from: 0, to: trunkProgress)
                            .stroke(Color(hex: "#1A0E04"),
                                    style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))

                        // Bark texture shadow line
                        TreeTrunkTexture(w: w, h: h)
                            .trim(from: 0, to: trunkProgress)
                            .stroke(Color(hex: "#1A0E04").opacity(0.20),
                                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                        // Stage 2 — lower side branches (trunk at y ≈ 0.72)
                        LowerBranches(w: w, h: h)
                            .trim(from: 0, to: lowerBranchProgress)
                            .stroke(Color(hex: "#1A0E04"),
                                    style: StrokeStyle(lineWidth: 5.5, lineCap: .round, lineJoin: .round))

                        // Stage 3 — main left & right branches (trunk at y ≈ 0.56)
                        MainBranches(w: w, h: h)
                            .trim(from: 0, to: mainBranchProgress)
                            .stroke(Color(hex: "#1A0E04"),
                                    style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))

                        // Stage 4 — crown center branch (trunk near top, y ≈ 0.38)
                        CrownBranch(w: w, h: h)
                            .trim(from: 0, to: crownProgress)
                            .stroke(Color(hex: "#1A0E04"),
                                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))

                        // Stage 5 — twigs (after all main branches extended)
                        SubBranches(w: w, h: h)
                            .trim(from: 0, to: subBranchProgress)
                            .stroke(Color(hex: "#1A0E04"),
                                    style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

                        // Stage 6 — leaves, slowest (the payoff moment)
                        LeafCluster(w: w, h: h, progress: leafProgress)
                    }
                }
                .frame(height: 320)

                Spacer(minLength: 24)

                VStack(spacing: 7) {
                    Text("LeafChat")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.accentBlack)
                    Text("Where every leaf tells a story.")
                        .font(.system(size: 14, weight: .light))
                        .italic()
                        .foregroundStyle(Color.textSecondary)
                }
                .opacity(textOpacity)

                Spacer(minLength: 70)
            }
            .padding(.horizontal, 28)
        }
        .onAppear(perform: startAnimation)
    }

    private func startAnimation() {
        guard !hasStarted else { return }
        hasStarted = true

        // Trunk grows upward: 1.8 s total
        withAnimation(.easeInOut(duration: 1.8)) { trunkProgress = 1 }

        // Lower branches sprout as trunk passes y = 0.72 (at t = 0.64 s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.64) {
            withAnimation(.easeOut(duration: 0.85)) { lowerBranchProgress = 1 }
        }

        // Main branches sprout as trunk passes y = 0.56 (at t = 1.06 s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.06) {
            withAnimation(.easeOut(duration: 0.95)) { mainBranchProgress = 1 }
        }

        // Crown branch sprouts as trunk nears top y = 0.38 (at t = 1.54 s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.54) {
            withAnimation(.easeOut(duration: 0.80)) { crownProgress = 1 }
        }

        // Twigs extend after all main branches finish: 1.06 + 0.95 = 2.01 s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.05) {
            withAnimation(.easeOut(duration: 1.05)) { subBranchProgress = 1 }
        }

        // App name fades in as the skeleton completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.10) {
            withAnimation(.easeIn(duration: 0.9)) { textOpacity = 1 }
        }

        // Leaves unfurl slowly on every twig tip
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 2.2)) { leafProgress = 1 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.8) { onFinished() }
    }
}

// MARK: - Trunk

private struct TreeTrunk: Shape {
    let w: CGFloat, h: CGFloat
    func path(in _: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: w * 0.500, y: h * 0.96))
        p.addCurve(
            to:       CGPoint(x: w * 0.500, y: h * 0.28),
            control1: CGPoint(x: w * 0.490, y: h * 0.72),
            control2: CGPoint(x: w * 0.512, y: h * 0.48)
        )
        return p
    }
}

private struct TreeTrunkTexture: Shape {
    let w: CGFloat, h: CGFloat
    func path(in _: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: w * 0.522, y: h * 0.96))
        p.addCurve(
            to:       CGPoint(x: w * 0.522, y: h * 0.29),
            control1: CGPoint(x: w * 0.513, y: h * 0.72),
            control2: CGPoint(x: w * 0.532, y: h * 0.48)
        )
        return p
    }
}

// MARK: - Lower Branches  (junction y ≈ 0.72)

private struct LowerBranches: Shape {
    let w: CGFloat, h: CGFloat
    func path(in _: CGRect) -> Path {
        var p = Path()
        // Left — sweeps outward and slightly upward
        p.move(to:   CGPoint(x: w * 0.490, y: h * 0.72))
        p.addQuadCurve(
            to:      CGPoint(x: w * 0.21, y: h * 0.54),
            control: CGPoint(x: w * 0.31, y: h * 0.61)
        )
        // Right
        p.move(to:   CGPoint(x: w * 0.510, y: h * 0.72))
        p.addQuadCurve(
            to:      CGPoint(x: w * 0.79, y: h * 0.54),
            control: CGPoint(x: w * 0.69, y: h * 0.61)
        )
        return p
    }
}

// MARK: - Main Branches  (junction y ≈ 0.56)

private struct MainBranches: Shape {
    let w: CGFloat, h: CGFloat
    func path(in _: CGRect) -> Path {
        var p = Path()
        // Left — long diagonal sweep up-left
        p.move(to:   CGPoint(x: w * 0.487, y: h * 0.56))
        p.addQuadCurve(
            to:      CGPoint(x: w * 0.12, y: h * 0.22),
            control: CGPoint(x: w * 0.23, y: h * 0.35)
        )
        // Right
        p.move(to:   CGPoint(x: w * 0.513, y: h * 0.56))
        p.addQuadCurve(
            to:      CGPoint(x: w * 0.88, y: h * 0.22),
            control: CGPoint(x: w * 0.77, y: h * 0.35)
        )
        return p
    }
}

// MARK: - Crown Branch  (junction y ≈ 0.38)

private struct CrownBranch: Shape {
    let w: CGFloat, h: CGFloat
    func path(in _: CGRect) -> Path {
        var p = Path()
        p.move(to:   CGPoint(x: w * 0.500, y: h * 0.38))
        p.addQuadCurve(
            to:      CGPoint(x: w * 0.500, y: h * 0.07),
            control: CGPoint(x: w * 0.468, y: h * 0.22)
        )
        return p
    }
}

// MARK: - Sub-branches (twigs from every branch tip)
// Ordered lower → main → crown so trim reveals bottom layers first.

private struct SubBranches: Shape {
    let w: CGFloat, h: CGFloat
    func path(in _: CGRect) -> Path {
        var p = Path()

        // From lower-left tip (0.21, 0.54)
        let ll = CGPoint(x: w * 0.21, y: h * 0.54)
        p.move(to: ll); p.addQuadCurve(to: CGPoint(x: w * 0.09, y: h * 0.43), control: CGPoint(x: w * 0.13, y: h * 0.50))
        p.move(to: ll); p.addQuadCurve(to: CGPoint(x: w * 0.17, y: h * 0.39), control: CGPoint(x: w * 0.17, y: h * 0.48))

        // From lower-right tip (0.79, 0.54)
        let lr = CGPoint(x: w * 0.79, y: h * 0.54)
        p.move(to: lr); p.addQuadCurve(to: CGPoint(x: w * 0.83, y: h * 0.39), control: CGPoint(x: w * 0.83, y: h * 0.48))
        p.move(to: lr); p.addQuadCurve(to: CGPoint(x: w * 0.91, y: h * 0.43), control: CGPoint(x: w * 0.87, y: h * 0.50))

        // From main-left tip (0.12, 0.22)
        let ml = CGPoint(x: w * 0.12, y: h * 0.22)
        p.move(to: ml); p.addQuadCurve(to: CGPoint(x: w * 0.03, y: h * 0.10), control: CGPoint(x: w * 0.06, y: h * 0.17))
        p.move(to: ml); p.addQuadCurve(to: CGPoint(x: w * 0.20, y: h * 0.08), control: CGPoint(x: w * 0.14, y: h * 0.15))

        // From main-right tip (0.88, 0.22)
        let mr = CGPoint(x: w * 0.88, y: h * 0.22)
        p.move(to: mr); p.addQuadCurve(to: CGPoint(x: w * 0.80, y: h * 0.08), control: CGPoint(x: w * 0.86, y: h * 0.15))
        p.move(to: mr); p.addQuadCurve(to: CGPoint(x: w * 0.97, y: h * 0.10), control: CGPoint(x: w * 0.94, y: h * 0.17))

        // From crown tip (0.50, 0.07)
        let ct = CGPoint(x: w * 0.50, y: h * 0.07)
        p.move(to: ct); p.addQuadCurve(to: CGPoint(x: w * 0.38, y: h * 0.02), control: CGPoint(x: w * 0.42, y: h * 0.05))
        p.move(to: ct); p.addQuadCurve(to: CGPoint(x: w * 0.62, y: h * 0.02), control: CGPoint(x: w * 0.58, y: h * 0.05))

        return p
    }
}

// MARK: - Leaf Shapes

/// Solid fill outline only (no vein), used as the leaf body.
private struct LeafFillShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        let tip  = CGPoint(x: w * 0.50, y: 0)
        let base = CGPoint(x: w * 0.50, y: h)
        p.move(to: tip)
        p.addCurve(to: base, control1: CGPoint(x: w, y: h * 0.10), control2: CGPoint(x: w, y: h * 0.80))
        p.addCurve(to: tip,  control1: CGPoint(x: 0, y: h * 0.80), control2: CGPoint(x: 0, y: h * 0.10))
        p.closeSubpath()
        return p
    }
}

/// Stroke path ordered to animate like a pencil drawing the leaf from its
/// attachment point (base) outward:
///   1. Center vein   — base → tip   (grows away from branch)
///   2. Right outline — tip  → base  (right lobe traces outward then back)
///   3. Left outline  — base → tip   (left lobe closes the shape)
/// Using `.trim(from: 0, to: t)` on this path unfurls the leaf from the stem.
private struct LeafStrokeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        let tip  = CGPoint(x: w * 0.50, y: 0)
        let base = CGPoint(x: w * 0.50, y: h)
        // 1. Vein
        p.move(to: base)
        p.addLine(to: tip)
        // 2. Right lobe
        p.move(to: tip)
        p.addCurve(to: base, control1: CGPoint(x: w, y: h * 0.10), control2: CGPoint(x: w, y: h * 0.80))
        // 3. Left lobe
        p.move(to: base)
        p.addCurve(to: tip, control1: CGPoint(x: 0, y: h * 0.80), control2: CGPoint(x: 0, y: h * 0.10))
        return p
    }
}

// MARK: - Leaf Cluster

private struct LeafCluster: View {
    let w: CGFloat, h: CGFloat, progress: CGFloat

    // (branchTipX, branchTipY, rotation°, relativeScale)
    // Each (x,y) is the BRANCH TIP where the leaf stem attaches.
    // The leaf center is offset so the base sits exactly on this point.
    private let leaves: [(CGFloat, CGFloat, Double, CGFloat)] = [
        // Crown twigs
        (0.38, 0.02, -20, 0.88),
        (0.50, 0.07,   0, 1.00),
        (0.62, 0.02,  20, 0.88),
        // Main-left branch & its twigs
        (0.12, 0.22, -45, 0.85),
        (0.03, 0.10, -62, 0.80),
        (0.20, 0.08, -18, 0.78),
        // Main-right branch & its twigs
        (0.88, 0.22,  45, 0.85),
        (0.80, 0.08,  18, 0.78),
        (0.97, 0.10,  62, 0.80),
        // Lower-left branch & its twigs
        (0.21, 0.54, -38, 0.80),
        (0.09, 0.43, -58, 0.75),
        (0.17, 0.39, -30, 0.75),
        // Lower-right branch & its twigs
        (0.79, 0.54,  38, 0.80),
        (0.83, 0.39,  30, 0.75),
        (0.91, 0.43,  58, 0.75),
    ]

    var body: some View {
        ZStack {
            ForEach(Array(leaves.enumerated()), id: \.offset) { idx, leaf in
                let lw: CGFloat = 16 * leaf.3
                let lh: CGFloat = 22 * leaf.3
                let halfH: CGFloat = lh * 0.5

                // Compute leaf center so the BASE sits at the branch tip.
                // For a CW rotation θ, the base offset from center in screen coords is
                // (halfH·sin θ, halfH·cos θ), so center = tipPos − that offset.
                let rad: Double = leaf.2 * .pi / 180.0
                let cx: CGFloat = w * leaf.0 - CGFloat(sin(rad)) * halfH
                let cy: CGFloat = h * leaf.1 - CGFloat(cos(rad)) * halfH

                // Each leaf has its own draw window, staggered by 4% of total progress.
                let stagger: CGFloat = CGFloat(idx) * 0.04
                let window:  CGFloat = 0.45
                let lp: CGFloat = max(0, min(1, (progress - stagger) / window))

                ZStack {
                    // Fill appears after the outline is ~40% drawn
                    LeafFillShape()
                        .fill(Color.launchLeafGreen.opacity(0.28))
                        .opacity(max(0, Double((lp - 0.4) / 0.6)))
                    // Stroke draws itself from the stem outward via trim
                    LeafStrokeShape()
                        .trim(from: 0, to: lp)
                        .stroke(
                            Color.launchLeafGreen.opacity(0.82),
                            style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round)
                        )
                }
                .frame(width: lw, height: lh)
                .rotationEffect(.degrees(leaf.2))
                .position(x: cx, y: cy)
            }
        }
    }
}

private extension Color {
    /// Launch animation leaf green — used only on the sketched tree payoff.
    static let launchLeafGreen = Color(hex: "#22C55E")
}
