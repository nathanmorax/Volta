import SwiftUI

/// Paleta y tipografía inspiradas en la referencia: papel cálido, verde mesa, acento naranja.
enum Theme {
    static let paper       = Color(red: 0.929, green: 0.925, blue: 0.910)   // #EDECE8
    static let paperShadow = Color(red: 0.868, green: 0.862, blue: 0.842)
    static let board       = Color(red: 0.255, green: 0.553, blue: 0.459)   // #418D75
    static let boardEdge   = Color(red: 0.118, green: 0.235, blue: 0.188)   // #1E3C30
    static let hole        = Color(red: 0.145, green: 0.333, blue: 0.271)
    static let line        = Color.white.opacity(0.92)
    static let ink         = Color(red: 0.110, green: 0.110, blue: 0.110)
    static let muted       = Color(red: 0.470, green: 0.470, blue: 0.450)
    static let accent      = Color(red: 0.957, green: 0.420, blue: 0.220)   // #F46B38
    static let handle      = Color(red: 0.900, green: 0.815, blue: 0.640)
    static let metal       = Color(red: 0.760, green: 0.760, blue: 0.740)
    static let capacitor   = Color(red: 0.170, green: 0.240, blue: 0.330)
}

/// Etiqueta en mayúsculas con tracking amplio (el estilo "KEEP IT GOING").
struct TrackedLabel: View {
    let text: String
    var size: CGFloat = 8
    var color: Color = Theme.muted

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: .semibold))
            .tracking(size * 0.24)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}
