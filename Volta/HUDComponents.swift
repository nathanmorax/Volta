import SwiftUI

// MARK: - Marca

struct BrandMark: View {
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack(alignment: .top) {
                HStack(spacing: 5) {
                    Capsule().fill(Theme.metal).frame(width: 2, height: 12)
                    Capsule().fill(Theme.metal).frame(width: 2, height: 9)
                }
                .offset(y: 12)
                Circle().fill(Theme.accent).frame(width: 18, height: 18)
            }
            .frame(width: 20, height: 26, alignment: .top)

            VStack(alignment: .leading, spacing: 3) {
                Text("NODO")
                    .font(.system(size: 20, weight: .heavy))
                    .tracking(-0.3)
                    .foregroundStyle(Theme.ink)
                TrackedLabel(text: "Protoboard", size: 7.5)
            }
        }
    }
}

// MARK: - Botón circular

struct RoundIconButton: View {
    let system: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(Theme.ink.opacity(0.15), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled)
    }
}

// MARK: - Marcador central (estilo "YOU / CPU")

struct CounterPill: View {
    let store: BoardStore

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 16) {
                counter("Cables", store.wireCount, Theme.accent)
                Text("/").font(.system(size: 12)).foregroundStyle(Theme.muted.opacity(0.5))
                counter("Piezas", store.partCount, Theme.ink)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.75)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.ink.opacity(0.07)))

            TrackedLabel(text: store.hint, size: 7.5)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.15), value: store.hint)
        }
    }

    private func counter(_ title: String, _ n: Int, _ color: Color) -> some View {
        VStack(spacing: 1) {
            TrackedLabel(text: title, size: 6.5)
            Text(String(format: "%02d", n))
                .font(.system(size: 22, weight: .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.snappy, value: n)
        }
    }
}

// MARK: - Laterales

struct SideTagline: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            TrackedLabel(text: "El taller de cada día", size: 7)
            TrackedLabel(text: "Una placa. Mil circuitos.", size: 7)
        }
    }
}

struct ReadoutPanel: View {
    let store: BoardStore

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let h = store.inspectedHole {
                TrackedLabel(text: "Nodo", size: 7)
                Text(Breadboard.name(h))
                    .font(.system(size: 30, weight: .light, design: .rounded))
                    .foregroundStyle(Theme.ink)
                TrackedLabel(text: "\(store.highlightedHoles.count) puntos unidos", size: 6.5)
            } else {
                TrackedLabel(text: "Componentes", size: 7)
                Text("\(store.components.count)")
                    .font(.system(size: 30, weight: .light, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                TrackedLabel(text: "830 puntos disponibles", size: 6.5)
            }
        }
        .frame(minWidth: 120, alignment: .trailing)
    }
}

struct StatusBlock: View {
    let store: BoardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle().fill(Theme.accent).frame(width: 4, height: 4)
                TrackedLabel(text: "Modo \(store.tool.title)", size: 7, color: Theme.ink)
            }
            TrackedLabel(text: "830 puntos · 63 columnas", size: 6)
        }
    }
}

struct HintsBlock: View {
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TrackedLabel(text: "Respira. Conecta otro punto.", size: 6.5)
            HStack(spacing: 10) {
                hint("V W R L", "Herramientas")
                hint("⌫", "Borrar")
                hint("⌘Z", "Deshacer")
                hint("esc", "Cancelar")
            }
        }
    }

    private func hint(_ key: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.ink.opacity(0.18)))
            Text(text).font(.system(size: 8, weight: .medium)).foregroundStyle(Theme.muted)
        }
    }
}

// MARK: - Dock de herramientas

struct ToolDock: View {
    let store: BoardStore

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Tool.all, id: \.self) { tool in
                let active = store.tool == tool
                Button { store.setTool(tool) } label: {
                    ToolGlyph(tool: tool, tint: active ? .white : Theme.ink)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(active ? Theme.ink : .clear))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(tool.shortcut, modifiers: [])
                .help(tool.title)
            }
        }
        .padding(5)
        .background(Capsule().fill(.white.opacity(0.85)))
        .overlay(Capsule().stroke(Theme.ink.opacity(0.07)))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
        .animation(.snappy(duration: 0.2), value: store.tool)
    }
}

struct ToolGlyph: View {
    let tool: Tool
    let tint: Color

    var body: some View {
        switch tool {
        case .select:
            Image(systemName: "arrow.up.left")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
        case .place(let kind):
            Canvas { ctx, size in
                let w = size.width, h = size.height, y = h / 2
                let leg = Path { p in p.move(to: CGPoint(x: 1, y: y)); p.addLine(to: CGPoint(x: w - 1, y: y)) }
                switch kind {
                case .wire:
                    var p = Path()
                    p.move(to: CGPoint(x: 3, y: h - 4))
                    p.addCurve(to: CGPoint(x: w - 3, y: 4),
                               control1: CGPoint(x: w * 0.25, y: 0),
                               control2: CGPoint(x: w * 0.75, y: h))
                    ctx.stroke(p, with: .color(tint), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                case .resistor:
                    ctx.stroke(leg, with: .color(tint), lineWidth: 1.2)
                    ctx.fill(Path(roundedRect: CGRect(x: 5, y: y - 3.5, width: w - 10, height: 7), cornerRadius: 3.5),
                             with: .color(tint))
                case .led:
                    ctx.stroke(leg, with: .color(tint), lineWidth: 1.2)
                    ctx.fill(Path(ellipseIn: CGRect(x: w / 2 - 5.5, y: y - 5.5, width: 11, height: 11)), with: .color(tint))
                case .capacitor:
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: 1, y: y)); p.addLine(to: CGPoint(x: w / 2 - 2.5, y: y))
                        p.move(to: CGPoint(x: w / 2 + 2.5, y: y)); p.addLine(to: CGPoint(x: w - 1, y: y))
                        p.move(to: CGPoint(x: w / 2 - 2.5, y: y - 6)); p.addLine(to: CGPoint(x: w / 2 - 2.5, y: y + 6))
                        p.move(to: CGPoint(x: w / 2 + 2.5, y: y - 6)); p.addLine(to: CGPoint(x: w / 2 + 2.5, y: y + 6))
                    }, with: .color(tint), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                case .diode:
                    ctx.stroke(leg, with: .color(tint), lineWidth: 1.2)
                    let tri = Path { p in
                        p.move(to: CGPoint(x: w / 2 - 4, y: y - 5))
                        p.addLine(to: CGPoint(x: w / 2 + 3, y: y))
                        p.addLine(to: CGPoint(x: w / 2 - 4, y: y + 5))
                        p.closeSubpath()
                    }
                    ctx.fill(tri, with: .color(tint))
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: w / 2 + 4, y: y - 5)); p.addLine(to: CGPoint(x: w / 2 + 4, y: y + 5))
                    }, with: .color(tint), lineWidth: 1.6)
                }
            }
            .frame(width: 20, height: 20)
        }
    }
}

// MARK: - Colores

struct ColorDots: View {
    let options: [WireColor]
    let selected: WireColor
    let onPick: (WireColor) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                Button { onPick(option) } label: {
                    Circle()
                        .fill(option.color)
                        .overlay(Circle().stroke(Theme.ink.opacity(option == .white ? 0.25 : 0), lineWidth: 1))
                        .frame(width: 14, height: 14)
                        .padding(4)
                        .overlay(Circle().stroke(option == selected ? Theme.ink : .clear, lineWidth: 1.2))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(.white.opacity(0.85)))
        .overlay(Capsule().stroke(Theme.ink.opacity(0.07)))
    }
}

// MARK: - Inspector de pieza

struct InspectorCard: View {
    let store: BoardStore
    let component: Component

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                TrackedLabel(text: component.kind.title, size: 7.5, color: Theme.ink)
                Text("\(Breadboard.name(component.a)) → \(Breadboard.name(component.b))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.muted)
            }

            Rectangle().fill(Theme.ink.opacity(0.08)).frame(width: 1, height: 26)

            switch component.kind {
            case .resistor, .capacitor:
                HStack(spacing: 10) {
                    stepButton("minus", -1)
                    Text(component.valueLabel ?? "")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                        .frame(minWidth: 58)
                    stepButton("plus", 1)
                }
            case .wire, .led:
                ColorDots(options: component.kind == .led ? WireColor.ledOptions : WireColor.allCases,
                          selected: component.color) { store.setColor(component.id, $0) }
                    .background(Capsule().fill(.clear))
            case .diode:
                Text(component.valueLabel ?? "")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.muted)
            }

            Rectangle().fill(Theme.ink.opacity(0.08)).frame(width: 1, height: 26)

            Button { store.deleteSelected() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(Capsule().fill(.white.opacity(0.92)))
        .overlay(Capsule().stroke(Theme.ink.opacity(0.07)))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }

    private func stepButton(_ system: String, _ delta: Int) -> some View {
        Button { store.stepValue(component.id, by: delta) } label: {
            Image(systemName: system)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(Theme.ink.opacity(0.15)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
