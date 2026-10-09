import SwiftUI

/// Lienzo con pan (arrastrar), zoom (pellizcar) y toque para colocar piezas.
/// Si el espacio es vertical (iPhone/iPad en retrato) la placa gira 90° para aprovecharlo.
struct BreadboardCanvas: View {
    let store: BoardStore
    var insets: EdgeInsets

    @State private var dragStart: CGSize?
    @State private var zoomStart: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let transform = viewTransform(in: geo.size)
            let inverse = transform.inverted()
            let snapshot = RenderSnapshot(store: store)

            Canvas { ctx, _ in
                ctx.concatenate(transform)
                BoardRenderer.render(snapshot, in: ctx)
            }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                store.handleTap(at: location.applying(inverse))
            }
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let location):
                    let hole = Breadboard.nearestHole(to: location.applying(inverse))
                    if hole != store.hoverHole { store.hoverHole = hole }
                case .ended:
                    store.hoverHole = nil
                }
            }
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        if dragStart == nil { dragStart = store.pan }
                        let start = dragStart ?? .zero
                        store.pan = CGSize(width: start.width + value.translation.width,
                                           height: start.height + value.translation.height)
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        if zoomStart == nil { zoomStart = store.zoom }
                        store.setZoom((zoomStart ?? 1) * value.magnification)
                    }
                    .onEnded { _ in zoomStart = nil }
            )
        }
    }

    private func viewTransform(in size: CGSize) -> CGAffineTransform {
        let board = Breadboard.size
        let availW = max(size.width - insets.leading - insets.trailing, 1)
        let availH = max(size.height - insets.top - insets.bottom, 1)

        let fitFlat = min(availW / board.width, availH / board.height)
        let fitRotated = min(availW / board.height, availH / board.width)
        let rotated = fitRotated > fitFlat * 1.15
        let scale = (rotated ? fitRotated : fitFlat) * store.zoom

        let cx = insets.leading + availW / 2 + store.pan.width
        let cy = insets.top + availH / 2 + store.pan.height

        var t = CGAffineTransform(translationX: cx, y: cy)
        if rotated { t = t.rotated(by: .pi / 2) }
        t = t.scaledBy(x: scale, y: scale)
        t = t.translatedBy(x: -board.width / 2, y: -board.height / 2)
        return t
    }
}
