import SwiftUI

struct ContentView2: View {
    let store: BoardStore

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 720
            let showHints = geo.size.width > 1080

            ZStack {
                Theme.paper.ignoresSafeArea()
                BreadboardCanvas(store: store, insets: canvasInsets(compact: compact))
                hud(compact: compact, showHints: showHints)
            }
        }
        .background(Theme.paper.ignoresSafeArea())
        .background { keyboardShortcuts }
        .preferredColorScheme(.light)
        #if os(macOS)
        .frame(minWidth: 720, minHeight: 520)
        #endif
    }

    // MARK: HUD

    private func hud(compact: Bool, showHints: Bool) -> some View {
        VStack(spacing: 0) {
            header(compact: compact)

            if !compact {
                HStack(alignment: .top) {
                    SideTagline()
                    Spacer()
                    ReadoutPanel(store: store)
                }
                .padding(.top, 26)
            }

            Spacer(minLength: 0)

            footer(compact: compact, showHints: showHints)
        }
        .padding(.horizontal, compact ? 16 : 40)
        .padding(.top, topPadding(compact: compact))
        .padding(.bottom, compact ? 8 : 20)
    }

    private func header(compact: Bool) -> some View {
        VStack(spacing: 14) {
            ZStack(alignment: .top) {
                HStack(alignment: .top) {
                    BrandMark()
                    Spacer()
                    HStack(spacing: 8) {
                        if !compact {
                            RoundIconButton(system: "minus") { store.changeZoom(by: 0.8) }
                            RoundIconButton(system: "plus") { store.changeZoom(by: 1.25) }
                        }
                        RoundIconButton(system: "arrow.uturn.backward", enabled: store.canUndo) { store.undo() }
                        RoundIconButton(system: "viewfinder") { store.resetView() }
                    }
                }
                if !compact { CounterPill(store: store) }
            }
            if compact { CounterPill(store: store) }
        }
    }

    private func footer(compact: Bool, showHints: Bool) -> some View {
        ZStack(alignment: .bottom) {
            if !compact {
                HStack(alignment: .bottom) {
                    StatusBlock(store: store)
                    Spacer()
                    if showHints { HintsBlock() }
                }
            }

            VStack(spacing: 10) {
                if let selected = store.selected {
                    InspectorCard(store: store, component: selected)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let options = store.paletteOptions {
                    ColorDots(options: options, selected: store.activePaletteColor) { store.pickPaletteColor($0) }
                        .transition(.opacity)
                }
                ToolDock(store: store)
            }
        }
        .animation(.snappy(duration: 0.22), value: store.selectedID)
        .animation(.snappy(duration: 0.22), value: store.tool)
    }

    // MARK: Layout

    private func canvasInsets(compact: Bool) -> EdgeInsets {
        compact
            ? EdgeInsets(top: 150, leading: 16, bottom: 150, trailing: 16)
            : EdgeInsets(top: 170, leading: 120, bottom: 140, trailing: 120)
    }

    private func topPadding(compact: Bool) -> CGFloat {
        #if os(macOS)
        return 40   // deja espacio a los semáforos de la ventana
        #else
        return compact ? 8 : 24
        #endif
    }

    // MARK: Atajos de teclado (Mac y iPad con teclado)

    private var keyboardShortcuts: some View {
        ZStack {
            Button("") { store.cancel() }.keyboardShortcut(.cancelAction)
            Button("") { store.deleteSelected() }.keyboardShortcut(.delete, modifiers: [])
            Button("") { store.undo() }.keyboardShortcut("z", modifiers: .command)
            Button("") { store.changeZoom(by: 1.25) }.keyboardShortcut("=", modifiers: .command)
            Button("") { store.changeZoom(by: 0.8) }.keyboardShortcut("-", modifiers: .command)
            Button("") { store.resetView() }.keyboardShortcut("0", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }
}

#Preview {
    ContentView2(store: BoardStore())
}
