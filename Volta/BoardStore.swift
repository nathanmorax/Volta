import SwiftUI
import Observation

@Observable
final class BoardStore {
    private(set) var components: [Component] = []
    private(set) var tool: Tool = .select
    private(set) var undoStack: [[Component]] = []

    var pendingStart: Hole?
    var hoverHole: Hole?
    var focusedHole: Hole?
    var selectedID: UUID?
    var wireColor: WireColor = .orange
    var ledColor: WireColor = .red

    // Viewport
    var zoom: CGFloat = 1
    var pan: CGSize = .zero

    @ObservationIgnored private let storageKey = "nodo.board.v1"

    init() { load() }

    // MARK: Derivados

    var selected: Component? { components.first { $0.id == selectedID } }
    var canUndo: Bool { !undoStack.isEmpty }
    var wireCount: Int { components.filter { $0.kind == .wire }.count }
    var partCount: Int { components.count - wireCount }
    var inspectedHole: Hole? { focusedHole ?? pendingStart ?? hoverHole }

    var placingKind: ComponentKind? {
        if case .place(let k) = tool { return k }
        return nil
    }

    var hint: String {
        switch tool {
        case .select:
            if selected != nil { return "pieza seleccionada" }
            if focusedHole != nil { return "nodo resaltado" }
            return "toca un orificio o una pieza"
        case .place:
            return pendingStart == nil ? "elige el primer punto" : "elige el segundo punto"
        }
    }

    /// Orificios eléctricamente unidos al punto activo (incluye saltos por cables).
    var highlightedHoles: Set<Hole> {
        var sources: [Hole] = []
        if let pendingStart { sources = [pendingStart] }
        else if let focusedHole { sources = [focusedHole] }
        else if let s = selected { sources = [s.a, s.b] }
        else if let hoverHole { sources = [hoverHole] }
        guard !sources.isEmpty else { return [] }

        let nets = connectedNets(from: Set(sources.map(Breadboard.net(of:))))
        var result = Set<Hole>()
        for n in nets { result.formUnion(Breadboard.netMap[n] ?? []) }
        return result
    }

    func connectedNets(from start: Set<String>) -> Set<String> {
        var seen = start
        var queue = Array(start)
        let wires = components.filter { $0.kind == .wire }
        while let n = queue.popLast() {
            for w in wires {
                let na = Breadboard.net(of: w.a), nb = Breadboard.net(of: w.b)
                if na == n, !seen.contains(nb) { seen.insert(nb); queue.append(nb) }
                if nb == n, !seen.contains(na) { seen.insert(na); queue.append(na) }
            }
        }
        return seen
    }

    // MARK: Paleta de color de la herramienta

    var paletteOptions: [WireColor]? {
        switch tool {
        case .place(.wire): WireColor.allCases
        case .place(.led): WireColor.ledOptions
        default: nil
        }
    }

    var activePaletteColor: WireColor {
        placingKind == .led ? ledColor : wireColor
    }

    func pickPaletteColor(_ c: WireColor) {
        if placingKind == .led { ledColor = c } else { wireColor = c }
    }

    // MARK: Interacción

    func setTool(_ t: Tool) {
        tool = t
        pendingStart = nil
        focusedHole = nil
        if t != .select { selectedID = nil }
    }

    func cancel() {
        pendingStart = nil
        selectedID = nil
        focusedHole = nil
    }

    func handleTap(at p: CGPoint) {
        let hole = Breadboard.nearestHole(to: p)
        switch tool {
        case .select:
            if let c = component(at: p) {
                selectedID = c.id
                focusedHole = nil
            } else if let hole {
                focusedHole = (focusedHole == hole) ? nil : hole
                selectedID = nil
            } else {
                cancel()
            }

        case .place(let kind):
            guard let hole else { pendingStart = nil; return }
            guard let start = pendingStart else { pendingStart = hole; return }
            if start == hole { pendingStart = nil; return }

            var c = Component(kind: kind, a: start, b: hole)
            switch kind {
            case .wire: c.color = wireColor
            case .led: c.color = ledColor
            case .capacitor: c.value = 10
            default: break
            }
            commit { $0.append(c) }
            pendingStart = nil
        }
    }

    func component(at p: CGPoint) -> Component? {
        components.reversed().first {
            Self.distance(p, Breadboard.point($0.a), Breadboard.point($0.b)) < 8
        }
    }

    func deleteSelected() {
        guard let id = selectedID else { return }
        commit { $0.removeAll { $0.id == id } }
        selectedID = nil
    }

    func clearAll() {
        guard !components.isEmpty else { return }
        commit { $0.removeAll() }
        cancel()
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        components = last
        selectedID = nil
        save()
    }

    func stepValue(_ id: UUID, by delta: Int) {
        guard let c = components.first(where: { $0.id == id }) else { return }
        let list = c.kind == .resistor ? Component.resistorValues : Component.capacitorValues
        let current = log(c.value)
        let idx = list.indices.min { abs(log(list[$0]) - current) < abs(log(list[$1]) - current) } ?? 0
        let next = min(max(idx + delta, 0), list.count - 1)
        guard next != idx else { return }
        update(id) { $0.value = list[next] }
    }

    func setColor(_ id: UUID, _ color: WireColor) {
        guard let c = components.first(where: { $0.id == id }) else { return }
        if c.kind == .led { ledColor = color } else { wireColor = color }
        update(id) { $0.color = color }
    }

    // MARK: Viewport

    func changeZoom(by factor: CGFloat) { setZoom(zoom * factor) }

    func setZoom(_ newValue: CGFloat) {
        let clamped = min(max(newValue, 0.5), 8)
        let ratio = clamped / zoom
        pan = CGSize(width: pan.width * ratio, height: pan.height * ratio)
        zoom = clamped
    }

    func resetView() {
        withAnimation(.snappy(duration: 0.3)) {
            zoom = 1
            pan = .zero
        }
    }

    // MARK: Privado

    private func update(_ id: UUID, _ change: (inout Component) -> Void) {
        guard let i = components.firstIndex(where: { $0.id == id }) else { return }
        commit { change(&$0[i]) }
    }

    private func commit(_ change: (inout [Component]) -> Void) {
        undoStack.append(components)
        if undoStack.count > 100 { undoStack.removeFirst() }
        change(&components)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(components) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([Component].self, from: data) else { return }
        components = saved
    }

    static func distance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let l2 = dx * dx + dy * dy
        guard l2 > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / l2))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}
