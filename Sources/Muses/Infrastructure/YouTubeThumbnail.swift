import AppKit
import Foundation

/// YouTube thumbnail URLs and letterbox stripping.
///
/// Thumbnail containers may include paired black matte even at maxres size.
/// Verify uniform edges and interior contrast before removing matte at decode;
/// neither a 4:3 URL nor dark artwork alone authorizes a crop.
enum YouTubeThumbnail {
    /// Canonical stored URL (hqdefault). Display crops letterbox.
    static func urlString(videoId: String) -> String {
        "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"
    }

    static func url(videoId: String) -> URL? {
        URL(string: urlString(videoId: videoId))
    }

    /// Upgrade display-only YouTube thumbnail requests; persisted artwork URLs stay stable.
    static func displayCandidates(for url: URL, pixelSize: CGFloat) -> [URL] {
        guard pixelSize > 480,
              ["i.ytimg.com", "img.youtube.com"].contains(url.host?.lowercased() ?? ""),
              url.pathComponents.count == 4,
              ["vi", "vi_webp"].contains(url.pathComponents[1]),
              ["default", "mqdefault", "hqdefault", "sddefault"].contains(url.deletingPathExtension().lastPathComponent)
        else { return [url] }
        let directory = url.deletingLastPathComponent()
        let ext = url.pathExtension
        return [directory.appendingPathComponent("maxresdefault.\(ext)"),
                directory.appendingPathComponent("sddefault.\(ext)"), url]
            .reduce(into: [URL]()) { if !$0.contains($1) { $0.append($1) } }
    }

    static func isLetterboxed(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(),
              ["i.ytimg.com", "img.youtube.com"].contains(host) else {
            return false
        }
        let path = url.path.lowercased()
        return path.contains("hqdefault")
            || path.contains("sddefault")
            || path.hasSuffix("/default.jpg")
            || path.hasSuffix("/default.webp")
    }

    /// Crop only paired, uniform near-black matte with a clearly non-dark interior.
    /// URL shape alone is insufficient: even a maxres 16:9 frame can contain matte.
    static func cropLetterboxIfNeeded(_ image: NSImage, url: URL? = nil) -> NSImage {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
        let cropped = cropLetterboxIfNeeded(cg, url: url)
        guard cropped.width != cg.width || cropped.height != cg.height else { return image }
        return NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
    }

    static func cropLetterboxIfNeeded(_ image: CGImage, url: URL?) -> CGImage {
        if let url, !isYouTubeThumbnail(url) { return image }
        let width = image.width
        let height = image.height
        guard width >= 64, height >= 64 else { return image }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let detected: Int? = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            let data = buffer.bindMemory(to: UInt8.self)
            func isMatteRow(_ y: Int) -> Bool {
                var nonMatte = 0
                let tolerance = max(1, width / 200)
                for x in 0..<width {
                    let i = (y * width + x) * 4
                    if data[i + 3] < 250 || max(data[i], data[i + 1], data[i + 2]) > 12 {
                        nonMatte += 1
                        if nonMatte > tolerance { return false }
                    }
                }
                return true
            }
            // The same threshold is applied across each complete edge, corners included.
            // Never strip more than a quarter of either edge or crop one-sided darkness.
            let limit = height / 4
            var top = 0
            var bottom = 0
            while top < limit && isMatteRow(top) { top += 1 }
            while bottom < limit && isMatteRow(height - bottom - 1) { bottom += 1 }
            let minimum = max(2, height / 200)
            guard top >= minimum, bottom >= minimum, top < limit, bottom < limit,
                  abs(top - bottom) <= max(2, min(top, bottom) / 10) else { return nil }
            let edge = min(top, bottom)
            // Uniformly dark artwork and dark scenes are never enough evidence for matte.
            var bright = 0
            var samples = 0
            let interiorHeight = height - edge * 2
            for y in stride(from: edge, to: height - edge, by: max(1, interiorHeight / 16)) {
                for x in stride(from: width / 10, to: width * 9 / 10, by: max(1, width / 32)) {
                    let i = (y * width + x) * 4
                    samples += 1
                    if data[i + 3] >= 250 && max(data[i], data[i + 1], data[i + 2]) > 40 { bright += 1 }
                }
            }
            guard samples > 0, bright * 5 >= samples else { return nil }
            return edge
        }
        guard let edge = detected else { return image }
        return image.cropping(to: CGRect(x: 0, y: edge, width: width, height: height - edge * 2)) ?? image
    }

    private static func isYouTubeThumbnail(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(),
              host == "img.youtube.com" || host == "ytimg.com" || host.hasSuffix(".ytimg.com") else { return false }
        let parts = url.pathComponents
        guard parts.count == 4, ["vi", "vi_webp"].contains(parts[1]) else { return false }
        return ["default", "mqdefault", "hqdefault", "sddefault", "maxresdefault", "0", "1", "2", "3"]
            .contains(url.deletingPathExtension().lastPathComponent.lowercased())
    }
}
