import SwiftUI

struct StreamView: View {
    @ObservedObject var model: DeckModel

    @State private var viewSize: CGSize = .zero
    @State private var mouseDown = false

    private var streamSize: CGSize {
        let h = model.hello
        let w = (h?.streamWidth ?? 0) > 0 ? CGFloat(h!.streamWidth) : 1280
        let hh = (h?.streamHeight ?? 0) > 0 ? CGFloat(h!.streamHeight) : 720
        return CGSize(width: w, height: hh)
    }

    private var desktopSize: CGSize {
        let h = model.hello
        let w = (h?.desktopWidth ?? 0) > 0 ? CGFloat(h!.desktopWidth) : streamSize.width
        let hh = (h?.desktopHeight ?? 0) > 0 ? CGFloat(h!.desktopHeight) : streamSize.height
        return CGSize(width: w, height: hh)
    }

    /// Map a point in view coordinates to absolute desktop pixels,
    /// accounting for the letterboxing of scaledToFit.
    private func mapToDesktop(_ p: CGPoint) -> (Int, Int)? {
        guard viewSize.width > 0, viewSize.height > 0,
              streamSize.width > 0, streamSize.height > 0 else { return nil }
        let scale = min(viewSize.width / streamSize.width,
                        viewSize.height / streamSize.height)
        let drawW = streamSize.width * scale
        let drawH = streamSize.height * scale
        let offX = (viewSize.width - drawW) / 2
        let offY = (viewSize.height - drawH) / 2
        let sx = (p.x - offX) / drawW * streamSize.width
        let sy = (p.y - offY) / drawH * streamSize.height
        guard sx >= 0, sy >= 0, sx <= streamSize.width, sy <= streamSize.height else {
            return nil
        }
        return (Int(sx / streamSize.width * desktopSize.width),
                Int(sy / streamSize.height * desktopSize.height))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if let img = model.frame {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("Waiting for frames…")
                        .foregroundStyle(.secondary)
                }

                // Top bar
                VStack {
                    HStack {
                        Text(model.status)
                            .font(.caption)
                            .foregroundStyle(.white)
                        Spacer()
                        Button("Disconnect") { model.disconnect() }
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.6))
                    Spacer()
                }

                // Bottom controls
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ctrl("ESC") { model.key("Escape") }
                        ctrl("TAB") { model.key("Tab") }
                        ctrl("↵") { model.key("Return") }
                        ctrl("⌫") { model.key("Backspace") }
                        ctrl("◀") { model.key("ArrowLeft") }
                        ctrl("▲") { model.key("ArrowUp") }
                        ctrl("▼") { model.key("ArrowDown") }
                        ctrl("▶") { model.key("ArrowRight") }
                    }
                    .padding(8)
                    .background(.black.opacity(0.6))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard let d = mapToDesktop(value.location) else { return }
                        if !mouseDown {
                            mouseDown = true
                            model.mouseMove(x: d.0, y: d.1)
                            model.mouseButton("left", state: "down")
                        } else {
                            model.mouseMove(x: d.0, y: d.1)
                        }
                    }
                    .onEnded { _ in
                        if mouseDown {
                            mouseDown = false
                            model.mouseButton("left", state: "up")
                        }
                    }
            )
            .onAppear { viewSize = geo.size }
            .onChange(of: geo.size) { viewSize = $0 }
        }
        .ignoresSafeArea()
        .statusBarHidden()
    }

    private func ctrl(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .foregroundStyle(.white)
                .frame(minWidth: 44, minHeight: 44)
                .background(Color(white: 0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
