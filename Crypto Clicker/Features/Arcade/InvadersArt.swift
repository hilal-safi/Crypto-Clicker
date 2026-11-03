import SwiftUI
import CryptoClickerKit

/// Scam Invaders' pictures, drawn in code so they stay crisp at any size: the three invaders (each
/// with two poses for the march), the whale, the Bear, the ship in each of its looks, and the
/// firewall blocks. The game's field, the help sheet and the Style sheet all draw with these.
enum InvadersArt {
    // MARK: Invaders

    static func colors(for kind: InvadersGame.InvaderKind) -> (light: Color, dark: Color) {
        switch kind {
        case .memeCoin: (Color(red: 1.0, green: 0.86, blue: 0.3), Color(red: 0.93, green: 0.5, blue: 0.08))
        case .pumpBot: (Color(red: 0.42, green: 0.95, blue: 0.55), Color(red: 0.08, green: 0.58, blue: 0.32))
        case .rugPuller: (Color(red: 0.98, green: 0.45, blue: 0.85), Color(red: 0.58, green: 0.12, blue: 0.62))
        }
    }

    /// The color an invader bursts into when shot.
    static func burst(for kind: InvadersGame.InvaderKind, golden: Bool) -> Color {
        golden ? Theme.gold : colors(for: kind).light
    }

    /// One invader filling `rect`, in pose 0 or 1. A golden one glows and sparkles.
    static func drawInvader(_ kind: InvadersGame.InvaderKind, golden: Bool, pose: Int, in rect: CGRect,
                            context: inout GraphicsContext, time: TimeInterval = 0) {
        var layer = context
        if golden { layer.addFilter(.shadow(color: Theme.gold.opacity(0.95), radius: rect.width * 0.22)) }
        let tint = golden ? (light: Color(red: 1.0, green: 0.93, blue: 0.55), dark: Color(red: 0.85, green: 0.6, blue: 0.05)) : colors(for: kind)
        switch kind {
        case .memeCoin: drawMemeCoin(tint, pose: pose, in: rect, context: &layer)
        case .pumpBot: drawPumpBot(tint, pose: pose, in: rect, context: &layer, time: time)
        case .rugPuller: drawRugPuller(tint, pose: pose, in: rect, context: &layer)
        }
        if golden {
            let twinkle = 0.6 + 0.4 * sin(time * 6)
            drawSparkle(at: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + rect.height * 0.12),
                        size: rect.width * 0.26 * twinkle, context: &context)
        }
    }

    /// A gold coin with an angry face, stomping along on two feet.
    private static func drawMemeCoin(_ tint: (light: Color, dark: Color), pose: Int, in rect: CGRect, context: inout GraphicsContext) {
        let radius = min(rect.width, rect.height) * 0.43
        let center = CGPoint(x: rect.midX, y: rect.minY + radius + rect.height * 0.02)
        // Feet, apart in one pose and together in the other.
        let spread = rect.width * (pose == 0 ? 0.27 : 0.16)
        for side in [-1.0, 1.0] {
            let foot = CGRect(x: center.x + side * spread - rect.width * 0.09, y: rect.maxY - rect.height * 0.2,
                              width: rect.width * 0.18, height: rect.height * 0.18)
            context.fill(Path(ellipseIn: foot), with: .color(tint.dark))
        }
        let body = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.fill(body, with: .radialGradient(Gradient(colors: [tint.light, tint.dark]),
                                                 center: CGPoint(x: center.x - radius * 0.35, y: center.y - radius * 0.4),
                                                 startRadius: 0, endRadius: radius * 1.5))
        context.stroke(body, with: .color(tint.dark.mix(with: .black, by: 0.25)), lineWidth: max(1, radius * 0.12))
        drawEyes(at: center, radius: radius, look: pose == 0 ? -1 : 1, context: &context)
        // Angry brows.
        var brows = Path()
        for side in [-1.0, 1.0] {
            brows.move(to: CGPoint(x: center.x + side * radius * 0.7, y: center.y - radius * 0.55))
            brows.addLine(to: CGPoint(x: center.x + side * radius * 0.12, y: center.y - radius * 0.32))
        }
        context.stroke(brows, with: .color(.black.opacity(0.8)), style: StrokeStyle(lineWidth: max(1, radius * 0.16), lineCap: .round))
    }

    /// A boxy green bot with an antenna, pumping its arms, an arrow up its front.
    private static func drawPumpBot(_ tint: (light: Color, dark: Color), pose: Int, in rect: CGRect,
                                    context: inout GraphicsContext, time: TimeInterval) {
        let head = CGRect(x: rect.midX - rect.width * 0.32, y: rect.minY + rect.height * 0.24,
                          width: rect.width * 0.64, height: rect.height * 0.62)
        // Arms: up in one pose, down in the other.
        var arms = Path()
        for side in [-1.0, 1.0] {
            let shoulder = CGPoint(x: side < 0 ? head.minX : head.maxX, y: head.midY)
            arms.move(to: shoulder)
            arms.addLine(to: CGPoint(x: shoulder.x + side * rect.width * 0.16,
                                     y: shoulder.y + (pose == 0 ? -1 : 1) * rect.height * 0.28))
        }
        context.stroke(arms, with: .color(tint.dark), style: StrokeStyle(lineWidth: max(1.2, rect.width * 0.08), lineCap: .round))
        // Antenna with a light that blinks with the march.
        var antenna = Path()
        antenna.move(to: CGPoint(x: head.midX, y: head.minY))
        antenna.addLine(to: CGPoint(x: head.midX, y: rect.minY + rect.height * 0.08))
        context.stroke(antenna, with: .color(tint.dark), lineWidth: max(1, rect.width * 0.05))
        let bulb = rect.width * 0.07
        context.fill(Path(ellipseIn: CGRect(x: head.midX - bulb, y: rect.minY + rect.height * 0.08 - bulb, width: bulb * 2, height: bulb * 2)),
                     with: .color(pose == 0 ? Color(red: 1, green: 0.3, blue: 0.3) : Color(red: 1, green: 0.85, blue: 0.3)))
        let shell = Path(roundedRect: head, cornerRadius: head.width * 0.22)
        context.fill(shell, with: .linearGradient(Gradient(colors: [tint.light, tint.dark]),
                                                  startPoint: CGPoint(x: head.midX, y: head.minY), endPoint: CGPoint(x: head.midX, y: head.maxY)))
        context.stroke(shell, with: .color(tint.dark.mix(with: .black, by: 0.3)), lineWidth: max(1, rect.width * 0.04))
        // Square eyes and an arrow pointing up.
        let eye = head.width * 0.17
        for side in [-1.0, 1.0] {
            context.fill(Path(CGRect(x: head.midX + side * head.width * 0.2 - eye / 2, y: head.minY + head.height * 0.2,
                                     width: eye, height: eye)), with: .color(Color(red: 0.75, green: 1, blue: 1)))
        }
        var arrow = Path()
        let tip = CGPoint(x: head.midX, y: head.minY + head.height * 0.52)
        arrow.move(to: CGPoint(x: tip.x - head.width * 0.18, y: tip.y + head.height * 0.24))
        arrow.addLine(to: tip)
        arrow.addLine(to: CGPoint(x: tip.x + head.width * 0.18, y: tip.y + head.height * 0.24))
        context.stroke(arrow, with: .color(.white), style: StrokeStyle(lineWidth: max(1, head.width * 0.09), lineCap: .round, lineJoin: .round))
    }

    /// A flying rug with sly eyes and fringed ends, rippling as it goes.
    private static func drawRugPuller(_ tint: (light: Color, dark: Color), pose: Int, in rect: CGRect, context: inout GraphicsContext) {
        let rug = CGRect(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.22,
                         width: rect.width * 0.76, height: rect.height * 0.56)
        // The ripple: the rug's top and bottom edges wave, in opposite phase each pose.
        let wave = rect.height * 0.07 * (pose == 0 ? 1 : -1)
        var cloth = Path()
        cloth.move(to: CGPoint(x: rug.minX, y: rug.minY))
        cloth.addQuadCurve(to: CGPoint(x: rug.maxX, y: rug.minY), control: CGPoint(x: rug.midX, y: rug.minY - wave * 2))
        cloth.addLine(to: CGPoint(x: rug.maxX, y: rug.maxY))
        cloth.addQuadCurve(to: CGPoint(x: rug.minX, y: rug.maxY), control: CGPoint(x: rug.midX, y: rug.maxY - wave * 2))
        cloth.closeSubpath()
        context.fill(cloth, with: .linearGradient(Gradient(colors: [tint.light, tint.dark]),
                                                  startPoint: CGPoint(x: rug.minX, y: rug.minY), endPoint: CGPoint(x: rug.maxX, y: rug.maxY)))
        // A stripe across, and the fringe at each end.
        var stripe = Path()
        stripe.move(to: CGPoint(x: rug.minX + rug.width * 0.08, y: rug.maxY - rug.height * 0.24))
        stripe.addQuadCurve(to: CGPoint(x: rug.maxX - rug.width * 0.08, y: rug.maxY - rug.height * 0.24),
                            control: CGPoint(x: rug.midX, y: rug.maxY - rug.height * 0.24 - wave * 2))
        context.stroke(stripe, with: .color(Theme.gold.opacity(0.9)), lineWidth: max(1, rect.height * 0.06))
        var fringe = Path()
        for index in 0..<4 {
            let y = rug.minY + rug.height * (0.15 + 0.23 * Double(index))
            fringe.move(to: CGPoint(x: rug.minX, y: y))
            fringe.addLine(to: CGPoint(x: rug.minX - rect.width * 0.1, y: y + wave))
            fringe.move(to: CGPoint(x: rug.maxX, y: y))
            fringe.addLine(to: CGPoint(x: rug.maxX + rect.width * 0.1, y: y - wave))
        }
        context.stroke(fringe, with: .color(tint.light), style: StrokeStyle(lineWidth: max(0.8, rect.width * 0.035), lineCap: .round))
        // Narrow eyes, glancing the way it's about to pull.
        let eyeY = rug.minY + rug.height * 0.38
        for side in [-1.0, 1.0] {
            let eye = CGRect(x: rug.midX + side * rug.width * 0.18 - rug.width * 0.11, y: eyeY - rug.height * 0.1,
                             width: rug.width * 0.22, height: rug.height * 0.2)
            context.fill(Path(ellipseIn: eye), with: .color(.white))
            let pupil = rug.height * 0.09
            let offset = (pose == 0 ? -1.0 : 1.0) * eye.width * 0.22
            context.fill(Path(ellipseIn: CGRect(x: eye.midX + offset - pupil, y: eye.midY - pupil, width: pupil * 2, height: pupil * 2)),
                         with: .color(.black))
        }
    }

    private static func drawEyes(at center: CGPoint, radius: CGFloat, look: CGFloat, context: inout GraphicsContext) {
        for side in [-1.0, 1.0] {
            let eye = CGRect(x: center.x + side * radius * 0.36 - radius * 0.24, y: center.y - radius * 0.32,
                             width: radius * 0.48, height: radius * 0.48)
            context.fill(Path(ellipseIn: eye), with: .color(.white))
            let pupil = radius * 0.13
            context.fill(Path(ellipseIn: CGRect(x: eye.midX + look * radius * 0.07 - pupil, y: eye.midY - pupil * 0.6,
                                                width: pupil * 2, height: pupil * 2)), with: .color(.black))
        }
    }

    static func drawSparkle(at point: CGPoint, size: CGFloat, context: inout GraphicsContext) {
        guard size > 0 else { return }
        var star = Path()
        star.move(to: CGPoint(x: point.x, y: point.y - size))
        star.addQuadCurve(to: CGPoint(x: point.x + size, y: point.y), control: point)
        star.addQuadCurve(to: CGPoint(x: point.x, y: point.y + size), control: point)
        star.addQuadCurve(to: CGPoint(x: point.x - size, y: point.y), control: point)
        star.addQuadCurve(to: CGPoint(x: point.x, y: point.y - size), control: point)
        context.fill(star, with: .color(.white))
    }

    // MARK: The whale and the Bear

    /// A whale filling `rect`, facing right or left, with a spout.
    static func drawWhale(in rect: CGRect, facingRight: Bool, context: inout GraphicsContext, time: TimeInterval = 0) {
        var layer = context
        if !facingRight {
            layer.translateBy(x: rect.midX * 2, y: 0)
            layer.scaleBy(x: -1, y: 1)
        }
        let body = CGRect(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.25,
                          width: rect.width * 0.72, height: rect.height * 0.62)
        // The tail, behind.
        var tail = Path()
        let root = CGPoint(x: body.minX + body.width * 0.08, y: body.midY)
        tail.move(to: root)
        tail.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.22), control: CGPoint(x: rect.minX + rect.width * 0.1, y: body.midY))
        tail.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.06, y: body.midY), control: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.4))
        tail.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.12), control: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY - rect.height * 0.3))
        tail.addQuadCurve(to: root, control: CGPoint(x: rect.minX + rect.width * 0.1, y: body.midY))
        layer.fill(tail, with: .color(Color(red: 0.12, green: 0.4, blue: 0.85)))
        let shape = Path(ellipseIn: body)
        layer.fill(shape, with: .linearGradient(Gradient(colors: [Color(red: 0.35, green: 0.68, blue: 1), Color(red: 0.1, green: 0.35, blue: 0.82)]),
                                                startPoint: CGPoint(x: body.midX, y: body.minY), endPoint: CGPoint(x: body.midX, y: body.maxY)))
        // A pale belly and an eye.
        layer.fill(Path(ellipseIn: CGRect(x: body.minX + body.width * 0.25, y: body.midY + body.height * 0.05,
                                          width: body.width * 0.62, height: body.height * 0.38)),
                   with: .color(Color(red: 0.8, green: 0.92, blue: 1).opacity(0.9)))
        let eye = body.height * 0.12
        layer.fill(Path(ellipseIn: CGRect(x: body.maxX - body.width * 0.22 - eye, y: body.midY - body.height * 0.18 - eye,
                                          width: eye * 2, height: eye * 2)), with: .color(.white))
        layer.fill(Path(ellipseIn: CGRect(x: body.maxX - body.width * 0.2 - eye * 0.5, y: body.midY - body.height * 0.17 - eye * 0.5,
                                          width: eye, height: eye)), with: .color(.black))
        // The spout, puffing.
        let puff = 0.5 + 0.5 * sin(time * 5)
        for (index, dx) in [-0.06, 0, 0.06].enumerated() {
            let size = rect.height * (0.1 + 0.05 * puff) * (index == 1 ? 1.2 : 1)
            let center = CGPoint(x: body.maxX - body.width * 0.3 + rect.width * dx, y: rect.minY + rect.height * (0.1 - 0.06 * puff))
            layer.fill(Path(ellipseIn: CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)),
                       with: .color(Color(red: 0.7, green: 0.95, blue: 1).opacity(0.85)))
        }
    }

    /// The Bear: a bear-market bot with ears, glaring eyes, gritted teeth and a falling chart on
    /// its chest. It flashes white when hit.
    static func drawBear(in rect: CGRect, flash: Double, context: inout GraphicsContext) {
        let fur = [Color(red: 0.55, green: 0.2, blue: 0.16), Color(red: 0.28, green: 0.07, blue: 0.08)]
        let ear = rect.height * 0.32
        for x in [rect.minX + rect.width * 0.14, rect.maxX - rect.width * 0.14] {
            let frame = CGRect(x: x - ear / 2, y: rect.minY - ear * 0.35, width: ear, height: ear)
            context.fill(Path(ellipseIn: frame), with: .color(fur[0]))
            context.fill(Path(ellipseIn: frame.insetBy(dx: ear * 0.22, dy: ear * 0.22)), with: .color(Color(red: 0.9, green: 0.45, blue: 0.45)))
        }
        let body = Path(roundedRect: rect, cornerRadius: rect.height * 0.3)
        context.fill(body, with: .linearGradient(Gradient(colors: fur), startPoint: CGPoint(x: rect.midX, y: rect.minY),
                                                 endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
        context.stroke(body, with: .color(.black.opacity(0.5)), lineWidth: 2)
        // Glowing eyes under a scowl.
        for side in [-1.0, 1.0] {
            let eye = CGRect(x: rect.midX + side * rect.width * 0.2 - rect.height * 0.1, y: rect.minY + rect.height * 0.22,
                             width: rect.height * 0.2, height: rect.height * 0.16)
            var glow = context
            glow.addFilter(.shadow(color: .red, radius: 4))
            glow.fill(Path(ellipseIn: eye), with: .color(Color(red: 1, green: 0.25, blue: 0.2)))
            var brow = Path()
            brow.move(to: CGPoint(x: rect.midX + side * rect.width * 0.32, y: rect.minY + rect.height * 0.14))
            brow.addLine(to: CGPoint(x: rect.midX + side * rect.width * 0.08, y: rect.minY + rect.height * 0.24))
            context.stroke(brow, with: .color(.black), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        // Teeth.
        var teeth = Path()
        let mouthY = rect.minY + rect.height * 0.5
        let left = rect.midX - rect.width * 0.16, step = rect.width * 0.32 / 6
        teeth.move(to: CGPoint(x: left, y: mouthY))
        for index in 1...6 {
            teeth.addLine(to: CGPoint(x: left + step * Double(index), y: mouthY + (index % 2 == 1 ? rect.height * 0.08 : 0)))
        }
        context.stroke(teeth, with: .color(.white), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        // A chart heading down, ending in an arrow.
        var chart = Path()
        let chartTop = rect.minY + rect.height * 0.66
        let points = [0.0, 0.25, 0.1, 0.55, 0.45, 0.85].enumerated().map { index, depth in
            CGPoint(x: rect.minX + rect.width * (0.2 + 0.12 * Double(index)), y: chartTop + rect.height * 0.22 * depth)
        }
        chart.addLines(points)
        context.stroke(chart, with: .color(Color(red: 1, green: 0.35, blue: 0.3)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        if let last = points.last {
            var head = Path()
            head.move(to: CGPoint(x: last.x - 6, y: last.y - 1))
            head.addLine(to: CGPoint(x: last.x + 2, y: last.y + 2))
            head.addLine(to: CGPoint(x: last.x - 1, y: last.y - 7))
            context.stroke(head, with: .color(Color(red: 1, green: 0.35, blue: 0.3)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
        if flash > 0 {
            context.fill(body, with: .color(.white.opacity(0.7 * flash)))
        }
    }

    // MARK: The ship

    /// The ship's colors in each look: its hull from top to bottom, the cockpit, the trim and an
    /// optional glow.
    static func shipColors(_ look: Cosmetic) -> (hull: [Color], cockpit: Color, trim: Color, glow: Color?) {
        switch look {
        case .shipNeon:
            ([Color(red: 0.1, green: 0.1, blue: 0.22), Color(red: 0.04, green: 0.04, blue: 0.12)],
             Color(red: 0.95, green: 0.35, blue: 1), Color(red: 0.2, green: 1, blue: 0.95), Color(red: 0.2, green: 1, blue: 0.95))
        case .shipGold:
            ([Color(red: 1, green: 0.95, blue: 0.7), Color(red: 0.85, green: 0.62, blue: 0.12)],
             Color(red: 0.55, green: 0.85, blue: 1), Color(red: 0.6, green: 0.38, blue: 0.02), Theme.gold)
        default:
            ([Color(red: 0.92, green: 0.94, blue: 1), Color(red: 0.55, green: 0.6, blue: 0.72)],
             Color(red: 0.35, green: 0.85, blue: 1), Theme.bitcoin, nil)
        }
    }

    /// The ship filling `rect`: a hull with swept wings, a cockpit and an engine flame.
    static func drawShip(_ look: Cosmetic, in rect: CGRect, context: inout GraphicsContext, time: TimeInterval = 0, flame: Bool = true) {
        let colors = shipColors(look)
        var layer = context
        if let glow = colors.glow { layer.addFilter(.shadow(color: glow.opacity(0.8), radius: rect.width * 0.08)) }
        if flame {
            let flicker = 0.75 + 0.25 * sin(time * 30)
            var fire = Path()
            fire.move(to: CGPoint(x: rect.midX - rect.width * 0.1, y: rect.maxY - rect.height * 0.12))
            fire.addQuadCurve(to: CGPoint(x: rect.midX + rect.width * 0.1, y: rect.maxY - rect.height * 0.12),
                              control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.45 * flicker))
            context.fill(fire, with: .linearGradient(Gradient(colors: [.yellow, .orange, .red.opacity(0)]),
                                                     startPoint: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.12),
                                                     endPoint: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.45)))
        }
        // Wings.
        var wings = Path()
        wings.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.35))
        wings.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.05))
        wings.addLine(to: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.maxY - rect.height * 0.2))
        wings.addLine(to: CGPoint(x: rect.midX - rect.width * 0.18, y: rect.maxY - rect.height * 0.2))
        wings.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.05))
        wings.closeSubpath()
        layer.fill(wings, with: .color(colors.trim))
        // Hull: a rounded dart.
        var hull = Path()
        hull.move(to: CGPoint(x: rect.midX, y: rect.minY))
        hull.addQuadCurve(to: CGPoint(x: rect.midX + rect.width * 0.2, y: rect.maxY - rect.height * 0.12),
                          control: CGPoint(x: rect.midX + rect.width * 0.24, y: rect.minY + rect.height * 0.3))
        hull.addLine(to: CGPoint(x: rect.midX - rect.width * 0.2, y: rect.maxY - rect.height * 0.12))
        hull.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                          control: CGPoint(x: rect.midX - rect.width * 0.24, y: rect.minY + rect.height * 0.3))
        layer.fill(hull, with: .linearGradient(Gradient(colors: colors.hull), startPoint: CGPoint(x: rect.midX, y: rect.minY),
                                               endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
        layer.stroke(hull, with: .color(colors.trim), lineWidth: max(1, rect.width * 0.025))
        // Cockpit.
        let cockpit = CGRect(x: rect.midX - rect.width * 0.07, y: rect.minY + rect.height * 0.3,
                             width: rect.width * 0.14, height: rect.height * 0.26)
        context.fill(Path(ellipseIn: cockpit), with: .color(colors.cockpit))
        context.fill(Path(ellipseIn: cockpit.insetBy(dx: cockpit.width * 0.3, dy: cockpit.height * 0.3)
                            .offsetBy(dx: -cockpit.width * 0.12, dy: -cockpit.height * 0.15)), with: .color(.white.opacity(0.8)))
    }

    // MARK: Firewalls

    /// One firewall block: a glowing brick, orange to red.
    static func drawBlock(in rect: CGRect, context: inout GraphicsContext) {
        context.fill(Path(roundedRect: rect.insetBy(dx: 0.3, dy: 0.3), cornerRadius: min(rect.width, rect.height) * 0.2),
                     with: .linearGradient(Gradient(colors: [Color(red: 1, green: 0.62, blue: 0.2), Color(red: 0.85, green: 0.18, blue: 0.1)]),
                                           startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
    }
}

/// The help sheet's pictures for Scam Invaders, by guide item id: the real sprites on a night sky.
struct InvadersGuideIcon: View {
    enum Look {
        case invader(InvadersGame.InvaderKind, golden: Bool)
        case whale, firewall, boss
    }

    let look: Look

    init?(guideID: String) {
        switch guideID {
        case "invaders.memeCoin": look = .invader(.memeCoin, golden: false)
        case "invaders.pumpBot": look = .invader(.pumpBot, golden: false)
        case "invaders.rugPuller": look = .invader(.rugPuller, golden: false)
        case "invaders.golden": look = .invader(.memeCoin, golden: true)
        case "invaders.whale": look = .whale
        case "invaders.firewall": look = .firewall
        case "invaders.boss": look = .boss
        default: return nil
        }
    }

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let frame = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side)
            context.fill(Path(roundedRect: frame, cornerRadius: side * 0.22),
                         with: .linearGradient(Gradient(colors: [Color(red: 0.08, green: 0.05, blue: 0.22), Color(red: 0.02, green: 0.02, blue: 0.08)]),
                                               startPoint: CGPoint(x: frame.midX, y: frame.minY), endPoint: CGPoint(x: frame.midX, y: frame.maxY)))
            let inner = frame.insetBy(dx: side * 0.16, dy: side * 0.2)
            switch look {
            case .invader(let kind, let golden):
                InvadersArt.drawInvader(kind, golden: golden, pose: 0, in: inner, context: &context, time: 1)
            case .whale:
                InvadersArt.drawWhale(in: frame.insetBy(dx: side * 0.1, dy: side * 0.26), facingRight: true, context: &context, time: 1)
            case .firewall:
                let block = inner.width / 4
                for row in 0..<3 {
                    for column in 0..<4 where !(row == 0 && (column == 0 || column == 3)) && !(row == 2 && (1...2).contains(column)) {
                        InvadersArt.drawBlock(in: CGRect(x: inner.minX + CGFloat(column) * block, y: inner.minY + inner.height * 0.2 + CGFloat(row) * block,
                                                         width: block, height: block), context: &context)
                    }
                }
            case .boss:
                InvadersArt.drawBear(in: frame.insetBy(dx: side * 0.14, dy: side * 0.28).offsetBy(dx: 0, dy: side * 0.06), flash: 0, context: &context)
            }
        }
        .accessibilityHidden(true)
    }
}
