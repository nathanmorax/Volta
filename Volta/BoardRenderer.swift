import SwiftUI

/// Copia inmutable del estado para dibujar dentro de `Canvas`.
struct RenderSnapshot {
    var components: [Component]
    var highlighted: Set<Hole>
    var pending: Hole?
    var hover: Hole?
    var selectedID: UUID?
    var previewKind: ComponentKind?
    var previewColor: WireColor

    init(store: BoardStore) {
        components = store.components
        highlighted = store.highlightedHoles
        pending = store.pendingStart
        hover = store.hoverHole
        selectedID = store.selectedID
        previewKind = store.placingKind
        previewColor = store.activePaletteColor
    }
}

enum BoardRenderer {
    private static let p = Breadboard.pitch

    static func render(_ s: RenderSnapshot, in ctx: GraphicsContext) {
        drawBoard(ctx, highlighted: s.highlighted)

        for c in s.components {
            draw(c, in: ctx, selected: c.id == s.selectedID)
        }

        if let hover = s.hover {
            ring(ctx, hover, color: s.previewKind == nil ? .white : Theme.accent, radius: 7, width: 1.4)
        }

        if let pending = s.pending {
            let c = Breadboard.point(pending)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)), with: .color(Theme.accent))
            ring(ctx, pending, color: Theme.accent, radius: 8, width: 1.6)

            if let hover = s.hover, hover != pending, let kind = s.previewKind {
                var ghost = ctx
                ghost.opacity = 0.5
                draw(Component(kind: kind, a: pending, b: hover, color: s.previewColor), in: ghost, selected: false)
            }
        }
    }

    // MARK: - Placa

    static func drawBoard(_ ctx: GraphicsContext, highlighted: Set<Hole>) {
        let size = Breadboard.size
        let rect = CGRect(origin: .zero, size: size)

        // Sombra en el piso + canto oscuro (como la mesa de la referencia)
        ctx.fill(Path(roundedRect: rect.offsetBy(dx: 18, dy: 26), cornerRadius: 10), with: .color(Theme.paperShadow))
        ctx.fill(Path(roundedRect: rect.offsetBy(dx: 0, dy: 7), cornerRadius: 8), with: .color(Theme.boardEdge))
        ctx.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(Theme.board))

        // Marco blanco
        ctx.stroke(Path(roundedRect: rect.insetBy(dx: 7, dy: 7), cornerRadius: 4), with: .color(Theme.line), lineWidth: 1.6)

        // Divisores rieles / zona de terminales
        for row in [2.0, 15.0] {
            hline(ctx, y: Breadboard.padding + CGFloat(row) * p, from: 7, to: size.width - 7, color: Theme.line, width: 1.2)
        }

        // Canal central (la "red")
        let cy = Breadboard.padding + 8.5 * p
        ctx.fill(Path(CGRect(x: 7, y: cy - p * 0.42, width: size.width - 14, height: p * 0.84)),
                 with: .color(Theme.boardEdge.opacity(0.28)))
        hline(ctx, y: cy, from: 7, to: size.width - 7, color: Theme.line.opacity(0.85), width: 1)

        // Orificios (un solo path = rápido)
        var holes = Path()
        let hs: CGFloat = 6.4
        for h in Breadboard.holes {
            let c = Breadboard.point(h)
            holes.addRoundedRect(in: CGRect(x: c.x - hs / 2, y: c.y - hs / 2, width: hs, height: hs),
                                 cornerSize: CGSize(width: 1.6, height: 1.6))
        }
        ctx.fill(holes, with: .color(Theme.hole))

        // Nodo resaltado: anillos blancos
        if !highlighted.isEmpty {
            var fills = Path()
            var rings = Path()
            for h in highlighted {
                let c = Breadboard.point(h)
                fills.addRoundedRect(in: CGRect(x: c.x - hs / 2, y: c.y - hs / 2, width: hs, height: hs),
                                     cornerSize: CGSize(width: 1.6, height: 1.6))
                rings.addEllipse(in: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12))
            }
            ctx.fill(fills, with: .color(.white.opacity(0.35)))
            ctx.stroke(rings, with: .color(.white.opacity(0.9)), lineWidth: 1.2)
        }

        // Letras de fila
        let letters = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]
        for (i, row) in (Breadboard.topRows + Breadboard.bottomRows).enumerated() {
            let y = Breadboard.padding + CGFloat(row) * p
            label(ctx, letters[i], CGPoint(x: Breadboard.padding - p * 0.95, y: y))
            label(ctx, letters[i], CGPoint(x: size.width - Breadboard.padding + p * 0.95, y: y))
        }

        // Polaridad de rieles
        for row in Breadboard.railRows {
            let plus = row == 0 || row == 16
            let y = Breadboard.padding + CGFloat(row) * p
            let color: Color = plus ? Theme.accent : .white.opacity(0.8)
            label(ctx, plus ? "+" : "−", CGPoint(x: Breadboard.padding - p * 0.95, y: y), color: color, size: 9)
            label(ctx, plus ? "+" : "−", CGPoint(x: size.width - Breadboard.padding + p * 0.95, y: y), color: color, size: 9)
        }

        // Números de columna
        for col in 0..<Breadboard.columns where col == 0 || (col + 1) % 5 == 0 {
            let x = Breadboard.padding + CGFloat(col) * p
            label(ctx, "\(col + 1)", CGPoint(x: x, y: Breadboard.padding + 2.5 * p), size: 5.5)
            label(ctx, "\(col + 1)", CGPoint(x: x, y: Breadboard.padding + 14.5 * p), size: 5.5)
        }
    }

    // MARK: - Componentes

    static func draw(_ c: Component, in ctx: GraphicsContext, selected: Bool) {
        let a = Breadboard.point(c.a), b = Breadboard.point(c.b)
        let len = hypot(b.x - a.x, b.y - a.y)
        let angle = Angle(radians: Double(atan2(b.y - a.y, b.x - a.x)))
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let seg = Path { path in path.move(to: a); path.addLine(to: b) }

        var shadow = ctx
        shadow.translateBy(x: 2, y: 3)
        let shade = GraphicsContext.Shading.color(.black.opacity(0.13))

        if selected {
            ctx.stroke(seg, with: .color(Theme.accent.opacity(0.25)), style: StrokeStyle(lineWidth: 18, lineCap: .round))
        }

        switch c.kind {
        case .wire:
            let style = StrokeStyle(lineWidth: 4.6, lineCap: .round)
            shadow.stroke(seg, with: shade, style: style)
            ctx.stroke(seg, with: .color(c.color.color), style: style)
            if c.color == .white {
                ctx.stroke(seg, with: .color(.black.opacity(0.12)), style: StrokeStyle(lineWidth: 4.6, lineCap: .round, dash: []))
                ctx.stroke(seg, with: .color(c.color.color), style: StrokeStyle(lineWidth: 3.6, lineCap: .round))
            }
            for pt in [a, b] {
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 1.4, y: pt.y - 1.4, width: 2.8, height: 2.8)),
                         with: .color(.white.opacity(0.45)))
            }

        case .resistor:
            legs(ctx, shadow, seg)
            pins(ctx, [a, b])
            let L = min(max(len - 16, 14), 30), H: CGFloat = 8.4
            let body = Path(roundedRect: CGRect(x: -L / 2, y: -H / 2, width: L, height: H), cornerRadius: H / 2)
            local(shadow, mid, angle).fill(body, with: shade)
            let lc = local(ctx, mid, angle)
            lc.fill(body, with: .color(Theme.handle))
            var clipped = lc
            clipped.clip(to: body)
            let positions: [CGFloat] = [0.24, 0.37, 0.5, 0.76]
            for (i, color) in Component.bands(for: c.value).enumerated() {
                let x = -L / 2 + L * positions[i]
                clipped.fill(Path(CGRect(x: x - 1.2, y: -H / 2, width: 2.4, height: H)), with: .color(color))
            }
            lc.stroke(body, with: .color(.black.opacity(0.08)), lineWidth: 0.6)

        case .led:
            legs(ctx, shadow, seg)
            pins(ctx, [a, b])
            let r: CGFloat = 7.5
            let circle = Path(ellipseIn: CGRect(x: mid.x - r, y: mid.y - r, width: r * 2, height: r * 2))
            ctx.fill(Path(ellipseIn: CGRect(x: mid.x - 13, y: mid.y - 13, width: 26, height: 26)),
                     with: .color(c.color.color.opacity(0.2)))
            shadow.fill(circle, with: shade)
            ctx.fill(circle, with: .color(c.color.color))
            ctx.stroke(circle, with: .color(.black.opacity(0.12)), lineWidth: 0.8)
            // Lado plano = cátodo (hacia b)
            local(ctx, mid, angle).fill(Path(CGRect(x: r - 1.8, y: -r * 0.7, width: 1.8, height: r * 1.4)),
                                        with: .color(.black.opacity(0.18)))
            ctx.fill(Path(ellipseIn: CGRect(x: mid.x - 4.2, y: mid.y - 4.6, width: 3.6, height: 3.2)),
                     with: .color(.white.opacity(0.6)))

        case .capacitor:
            legs(ctx, shadow, seg)
            pins(ctx, [a, b])
            let r: CGFloat = 7
            let rect = CGRect(x: mid.x - r, y: mid.y - r, width: r * 2, height: r * 2)
            shadow.fill(Path(ellipseIn: rect), with: shade)
            ctx.fill(Path(ellipseIn: rect), with: .color(Theme.capacitor))
            var clipped = local(ctx, mid, angle)
            clipped.clip(to: Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)))
            clipped.fill(Path(CGRect(x: r * 0.35, y: -r, width: r * 0.42, height: r * 2)), with: .color(.white.opacity(0.55)))
            ctx.stroke(Path(ellipseIn: rect.insetBy(dx: 2.5, dy: 2.5)), with: .color(.white.opacity(0.14)), lineWidth: 0.8)

        case .diode:
            legs(ctx, shadow, seg)
            pins(ctx, [a, b])
            let L = min(max(len - 18, 12), 22), H: CGFloat = 7
            let body = Path(roundedRect: CGRect(x: -L / 2, y: -H / 2, width: L, height: H), cornerRadius: H / 2)
            local(shadow, mid, angle).fill(body, with: shade)
            let lc = local(ctx, mid, angle)
            lc.fill(body, with: .color(Theme.ink))
            var clipped = lc
            clipped.clip(to: body)
            clipped.fill(Path(CGRect(x: L / 2 - 5, y: -H / 2, width: 2.4, height: H)), with: .color(Theme.metal))
        }
    }

    // MARK: - Helpers

    private static func local(_ ctx: GraphicsContext, _ p: CGPoint, _ angle: Angle) -> GraphicsContext {
        var c = ctx
        c.translateBy(x: p.x, y: p.y)
        c.rotate(by: angle)
        return c
    }

    private static func legs(_ ctx: GraphicsContext, _ shadow: GraphicsContext, _ seg: Path) {
        let style = StrokeStyle(lineWidth: 1.8, lineCap: .round)
        shadow.stroke(seg, with: .color(.black.opacity(0.12)), style: style)
        ctx.stroke(seg, with: .color(Theme.metal), style: style)
    }

    private static func pins(_ ctx: GraphicsContext, _ pts: [CGPoint]) {
        for pt in pts {
            ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 2.4, y: pt.y - 2.4, width: 4.8, height: 4.8)), with: .color(Theme.metal))
        }
    }

    private static func ring(_ ctx: GraphicsContext, _ h: Hole, color: Color, radius: CGFloat, width: CGFloat) {
        let c = Breadboard.point(h)
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)),
                   with: .color(color), lineWidth: width)
    }

    private static func hline(_ ctx: GraphicsContext, y: CGFloat, from x0: CGFloat, to x1: CGFloat, color: Color, width: CGFloat) {
        ctx.stroke(Path { path in path.move(to: CGPoint(x: x0, y: y)); path.addLine(to: CGPoint(x: x1, y: y)) },
                   with: .color(color), lineWidth: width)
    }

    private static func label(_ ctx: GraphicsContext, _ text: String, _ point: CGPoint,
                              color: Color = .white.opacity(0.7), size: CGFloat = 6) {
        ctx.draw(Text(text).font(.system(size: size, weight: .semibold, design: .rounded)).foregroundStyle(color),
                 at: point, anchor: .center)
    }
}
