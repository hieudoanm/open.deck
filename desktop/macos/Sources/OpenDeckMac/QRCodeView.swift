import AppKit
import CoreImage
import SwiftUI

/// Renders a pairing payload (e.g. the `ws://host:port/ws?token=...` URL)
/// as a QR code using the built-in CoreImage generator.
struct QRCodeView: View {
    let payload: String
    var size: CGFloat = 180

    private var image: NSImage? {
        guard !payload.isEmpty,
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }

        // CIQRCodeGenerator emits a small image; scale it up crisply.
        let scale = size / ciImage.extent.width
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let rep = NSCIImageRep(ciImage: scaled)
        let nsImage = NSImage(size: NSSize(width: scaled.extent.width, height: scaled.extent.height))
        nsImage.addRepresentation(rep)
        return nsImage
    }

    var body: some View {
        if let image {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Rectangle()
                .fill(.quaternary)
                .frame(width: size, height: size)
                .overlay(Text("—").foregroundStyle(.secondary))
        }
    }
}
