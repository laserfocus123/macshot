import Cocoa

extension OverlayView {
    /// Editor output area: the image (`selectionRect`), grown to hold any
    /// annotation drawn past its edges plus `padding` points of margin.
    /// Outside the editor, or when everything sits on the image, this is
    /// just `selectionRect`.
    ///
    /// `boundingRect` only covers an annotation's points, not its stroke or
    /// arrowhead, so the annotations that poke out are rendered into a
    /// scratch alpha mask and the drawn pixels are measured.
    func editorOutputRect(padding: CGFloat = 6) -> NSRect {
        let image = selectionRect
        guard isEditorMode, image.width > 0, image.height > 0 else { return image }

        func roughBounds(_ ann: Annotation) -> NSRect {
            let slop = max(ann.strokeWidth * 5, 16) + 8
            return ann.boundingRect.insetBy(dx: -slop, dy: -slop)
        }
        let outside = annotations.filter {
            $0.tool != .pixelate && !image.contains(roughBounds($0))
        }
        guard !outside.isEmpty else { return image }

        var rough = image
        for ann in outside { rough = rough.union(roughBounds(ann)) }
        rough = rough.integral
        let w = Int(rough.width), h = Int(rough.height)
        // Guard against absurd sizes (e.g. an annotation dragged far away).
        guard w > 0, h > 0, w * h <= 16_000_000,
            let ctx = CGContext(
                data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return image }

        ctx.translateBy(x: -rough.origin.x, y: -rough.origin.y)
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.current = nsContext
        for ann in outside { ann.draw(in: nsContext) }
        NSGraphicsContext.restoreGraphicsState()

        guard let data = ctx.data else { return image }
        let pixels = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        var minCol = w, maxCol = -1, minRow = h, maxRow = -1
        for row in 0..<h {
            let base = row * w * 4 + 3  // alpha byte of each RGBA pixel
            for col in 0..<w where pixels[base + col * 4] > 8 {
                if col < minCol { minCol = col }
                if col > maxCol { maxCol = col }
                if row < minRow { minRow = row }
                if row > maxRow { maxRow = row }
            }
        }
        guard maxCol >= 0 else { return image }

        // Bitmap row 0 is the top (highest y) of the context.
        let drawn = NSRect(
            x: rough.minX + CGFloat(minCol),
            y: rough.maxY - CGFloat(maxRow + 1),
            width: CGFloat(maxCol - minCol + 1),
            height: CGFloat(maxRow - minRow + 1))
        if image.contains(drawn) { return image }
        return image.union(drawn.insetBy(dx: -padding, dy: -padding)).integral
    }
}
