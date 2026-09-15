// Renders the Debrowse app icon as an .iconset directory.
// Usage: swift Scripts/make-icon.swift <output.iconset>
import AppKit

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write("usage: make-icon.swift <output.iconset>\n".data(using: .utf8)!)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: arguments[1])
try? FileManager.default.removeItem(at: outputDirectory)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    // Standard macOS icon grid: 824pt shape on a 1024pt canvas, ~22.5% corner radius.
    let side = CGFloat(pixels)
    let inset = side * 100.0 / 1024.0
    let shape = NSRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)
    let radius = shape.width * 0.2256
    let path = NSBezierPath(roundedRect: shape, xRadius: radius, yRadius: radius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.16, green: 0.62, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.38, green: 0.24, blue: 0.90, alpha: 1),
    ])!
    gradient.draw(in: path, angle: -60)

    // Subtle top highlight.
    path.addClip()
    let highlight = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.0),
        NSColor.white.withAlphaComponent(0.22),
    ])!
    highlight.draw(in: NSRect(x: shape.minX, y: shape.midY, width: shape.width, height: shape.height / 2), angle: 90)

    // Globe glyph, aspect-fit inside the central 60% of the shape.
    let glyphBox = shape.insetBy(dx: shape.width * 0.20, dy: shape.height * 0.20)
    let configuration = NSImage.SymbolConfiguration(pointSize: glyphBox.height, weight: .medium)
        .applying(.init(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration) {
        let scale = min(glyphBox.width / symbol.size.width, glyphBox.height / symbol.size.height)
        let drawSize = NSSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
        let origin = NSPoint(x: glyphBox.midX - drawSize.width / 2, y: glyphBox.midY - drawSize.height / 2)
        symbol.draw(in: NSRect(origin: origin, size: drawSize), from: .zero, operation: .sourceOver, fraction: 1)
    }

    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(pixels: base).write(to: outputDirectory.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(pixels: base * 2).write(to: outputDirectory.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
