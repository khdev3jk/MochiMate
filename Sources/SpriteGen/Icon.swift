import AppKit

// MARK: - App icon

/// The app logo: a smiling mochi with a water drop on a pink squircle. Drawn on a 1024-point canvas, y up.
private func drawAppIcon(_ ctx: CGContext) {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [rgb(0xFFD6E0), rgb(0xFF9DB8)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    // Soft ground shadow, then the mochi.
    ctx.setFillColor(rgb(0xC2385A, 0.22))
    ctx.fillEllipse(in: CGRect(x: 262, y: 218, width: 500, height: 70))

    let mochi = CGPath(roundedRect: CGRect(x: 212, y: 250, width: 600, height: 430),
                       cornerWidth: 300, cornerHeight: 190, transform: nil)
    ctx.addPath(mochi)
    ctx.setFillColor(white)
    ctx.fillPath()
    ctx.addPath(mochi)
    ctx.setStrokeColor(outline)
    ctx.setLineWidth(18)
    ctx.strokePath()

    // Face.
    ctx.setFillColor(outline)
    for x in [400.0, 624.0] { ctx.fillEllipse(in: CGRect(x: x - 26, y: 440 - 34, width: 52, height: 68)) }
    ctx.setFillColor(rgb(0xFF8FA8, 0.7))
    for x in [335.0, 689.0] { ctx.fillEllipse(in: CGRect(x: x - 42, y: 385 - 26, width: 84, height: 52)) }
    ctx.setStrokeColor(outline)
    ctx.setLineWidth(16)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: 466, y: 405))
    ctx.addQuadCurve(to: CGPoint(x: 558, y: 405), control: CGPoint(x: 512, y: 345))
    ctx.strokePath()

    // Water drop riding on top of the mochi.
    let drop = CGMutablePath()
    drop.move(to: CGPoint(x: 512, y: 850))
    drop.addCurve(to: CGPoint(x: 512, y: 690), control1: CGPoint(x: 595, y: 770), control2: CGPoint(x: 595, y: 690))
    drop.addCurve(to: CGPoint(x: 512, y: 850), control1: CGPoint(x: 429, y: 690), control2: CGPoint(x: 429, y: 770))
    ctx.addPath(drop)
    ctx.setFillColor(waterBlue)
    ctx.fillPath()
    ctx.addPath(drop)
    ctx.setStrokeColor(outline)
    ctx.setLineWidth(14)
    ctx.strokePath()
    ctx.setFillColor(white)
    ctx.fillEllipse(in: CGRect(x: 478, y: 725, width: 24, height: 40))
}

/// Writes `icon_<size>x<size>[@2x].png` for every size `iconutil -c icns` expects into `dir`.
func writeIconSet(to dir: URL) throws {
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
                       ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
        guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("no context") }
        ctx.interpolationQuality = .high
        ctx.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)
        drawAppIcon(ctx)
        let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
        try rep.representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent("icon_\(name).png"))
    }
}
