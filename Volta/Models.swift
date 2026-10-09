import SwiftUI

// MARK: - Orificio

/// Un orificio de la protoboard. `row` está en unidades de paso (0…17), `col` en 0…62.
struct Hole: Hashable, Codable {
    var row: Int
    var col: Int
}

// MARK: - Geometría de la protoboard (830 puntos)

enum Breadboard {
    static let columns = 63
    static let pitch: CGFloat = 18          // 2.54 mm representados como 18 pt
    static let padding: CGFloat = 30
    static let railRows = [0, 1, 16, 17]    // 0/16 = +, 1/17 = −
    static let topRows = [3, 4, 5, 6, 7]    // a–e
    static let bottomRows = [10, 11, 12, 13, 14] // f–j
    static let lastRow = 17

    static let size = CGSize(
        width: padding * 2 + CGFloat(columns - 1) * pitch,
        height: padding * 2 + CGFloat(lastRow) * pitch
    )

    /// Rieles: 10 grupos de 5 orificios, centrados.
    static func isRailColumn(_ col: Int) -> Bool {
        (2...60).contains(col) && (col - 2) % 6 != 5
    }

    static let holes: [Hole] = {
        var result: [Hole] = []
        for row in railRows {
            for col in 0..<columns where isRailColumn(col) { result.append(Hole(row: row, col: col)) }
        }
        for row in topRows + bottomRows {
            for col in 0..<columns { result.append(Hole(row: row, col: col)) }
        }
        return result
    }()

    static let holeSet = Set(holes)
    static let netMap: [String: [Hole]] = Dictionary(grouping: holes, by: { Breadboard.net(of: $0) })

    static func point(_ h: Hole) -> CGPoint {
        CGPoint(x: padding + CGFloat(h.col) * pitch, y: padding + CGFloat(h.row) * pitch)
    }

    static func nearestHole(to p: CGPoint, tolerance: CGFloat = 11) -> Hole? {
        let col = Int(((p.x - padding) / pitch).rounded())
        let row = Int(((p.y - padding) / pitch).rounded())
        let h = Hole(row: row, col: col)
        guard holeSet.contains(h) else { return nil }
        let c = point(h)
        return hypot(c.x - p.x, c.y - p.y) <= tolerance ? h : nil
    }

    /// Nodo eléctrico interno: columnas a–e y f–j unidas, rieles unidos a lo largo.
    static func net(of h: Hole) -> String {
        switch h.row {
        case 3...7:   return "T\(h.col)"
        case 10...14: return "B\(h.col)"
        default:      return "R\(h.row)"
        }
    }

    static func name(_ h: Hole) -> String {
        let n = h.col + 1
        switch h.row {
        case 0, 16:   return "+\(n)"
        case 1, 17:   return "−\(n)"
        case 3...7:   return ["a", "b", "c", "d", "e"][h.row - 3] + "\(n)"
        case 10...14: return ["f", "g", "h", "i", "j"][h.row - 10] + "\(n)"
        default:      return "?"
        }
    }
}

// MARK: - Componentes

enum ComponentKind: String, Codable, CaseIterable, Hashable {
    case wire, resistor, led, capacitor, diode

    var title: String {
        switch self {
        case .wire: "Cable"
        case .resistor: "Resistencia"
        case .led: "LED"
        case .capacitor: "Capacitor"
        case .diode: "Diodo"
        }
    }
}

enum WireColor: String, Codable, CaseIterable, Hashable {
    case orange, ink, red, blue, yellow, white

    static let ledOptions: [WireColor] = [.red, .orange, .yellow, .blue, .white]

    var color: Color {
        switch self {
        case .orange: Theme.accent
        case .ink:    Color(red: 0.16, green: 0.16, blue: 0.16)
        case .red:    Color(red: 0.86, green: 0.24, blue: 0.22)
        case .blue:   Color(red: 0.22, green: 0.43, blue: 0.80)
        case .yellow: Color(red: 0.96, green: 0.78, blue: 0.25)
        case .white:  Color(red: 0.98, green: 0.97, blue: 0.94)
        }
    }
}

struct Component: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: ComponentKind
    var a: Hole
    var b: Hole
    var value: Double = 220            // Ω para resistencia, µF para capacitor
    var color: WireColor = .orange     // cable / LED

    static let resistorValues: [Double] = [10, 22, 47, 100, 220, 330, 470, 1_000, 2_200, 4_700,
                                           10_000, 22_000, 47_000, 100_000, 1_000_000]
    static let capacitorValues: [Double] = [0.001, 0.01, 0.1, 1, 10, 47, 100, 470, 1_000]

    var valueLabel: String? {
        switch kind {
        case .resistor:  Format.ohms(value)
        case .capacitor: Format.farads(value)
        case .diode:     "1N4148"
        default:         nil
        }
    }

    // Código de colores (4 bandas)
    static let bandPalette: [Color] = [
        Color(red: 0.10, green: 0.10, blue: 0.10), Color(red: 0.45, green: 0.27, blue: 0.15),
        Color(red: 0.82, green: 0.20, blue: 0.18), Color(red: 0.95, green: 0.50, blue: 0.15),
        Color(red: 0.97, green: 0.82, blue: 0.20), Color(red: 0.25, green: 0.60, blue: 0.30),
        Color(red: 0.20, green: 0.38, blue: 0.75), Color(red: 0.50, green: 0.30, blue: 0.65),
        Color(red: 0.55, green: 0.55, blue: 0.55), Color(white: 0.97)
    ]
    static let gold = Color(red: 0.78, green: 0.63, blue: 0.30)

    static func bands(for ohms: Double) -> [Color] {
        guard ohms >= 10 else { return [bandPalette[0], bandPalette[0], bandPalette[0], gold] }
        let exp = Int(floor(log10(ohms))) - 1
        let sig = Int((ohms / pow(10, Double(exp))).rounded())
        let d1 = min(max(sig / 10, 0), 9)
        let d2 = min(max(sig % 10, 0), 9)
        return [bandPalette[d1], bandPalette[d2], bandPalette[min(max(exp, 0), 9)], gold]
    }
}

enum Format {
    static func trim(_ v: Double) -> String {
        abs(v - v.rounded()) < 1e-6 ? String(Int(v.rounded())) : String(format: "%.1f", v)
    }
    static func ohms(_ v: Double) -> String {
        if v >= 1_000_000 { return trim(v / 1_000_000) + " MΩ" }
        if v >= 1_000 { return trim(v / 1_000) + " kΩ" }
        return trim(v) + " Ω"
    }
    static func farads(_ v: Double) -> String {
        v < 1 ? trim(v * 1_000) + " nF" : trim(v) + " µF"
    }
}

// MARK: - Herramientas

enum Tool: Hashable {
    case select
    case place(ComponentKind)

    static let all: [Tool] = [Tool.select] + ComponentKind.allCases.map { Tool.place($0) }

    var title: String {
        switch self {
        case .select: "Selección"
        case .place(let k): k.title
        }
    }

    var shortcut: KeyEquivalent {
        switch self {
        case .select: "v"
        case .place(.wire): "w"
        case .place(.resistor): "r"
        case .place(.led): "l"
        case .place(.capacitor): "c"
        case .place(.diode): "d"
        }
    }
}
