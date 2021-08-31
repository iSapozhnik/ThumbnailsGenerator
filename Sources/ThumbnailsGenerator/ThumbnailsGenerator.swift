import Cocoa
import Quartz.QuickLookUI
import QuickLookThumbnailing

final class ThumbnailsGenerator {
    private static let audioFilesExtensions: [String] = [
        "caf", "wav", "wave", "bwf", "aif", "aiff", "aifc", "cdda", "amr", "mp3", "au", "snd", "ac3", "eac3"
    ]
    
    func generateThumbnail(forURL url: URL, completion: @escaping (NSImage) -> Void) {
        let size: NSSize = .init(width: 256, height: 256)
        let scale: CGFloat = NSScreen.main?.backingScaleFactor ?? .zero

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .icon)
        
        let generator = QLThumbnailGenerator.shared
        generator.generateBestRepresentation(for: request) { thumbnail, error in
            if let image = thumbnail?.nsImage {
                completion(image)
            }
        }
    }
    
    static func previewForFile(atURL url: URL, ofSize size: CGSize, asIcon: Bool) -> NSImage {
        let dict = [
            kQLThumbnailOptionIconModeKey: NSNumber(booleanLiteral: asIcon)
        ] as CFDictionary
        
        let ref = QLThumbnailImageCreate(kCFAllocatorDefault, url as CFURL, size, dict)
        
        if !audioFilesExtensions.contains(url.pathExtension), let cgImage = ref?.takeUnretainedValue() {
            // Take advantage of NSBitmapImageRep's -initWithCGImage: initializer, new in Leopard,
            // which is a lot more efficient than copying pixel data into a brand new NSImage.
            let bitmapImageRep = NSBitmapImageRep.init(cgImage: cgImage)
            let newImage = NSImage.init(size: bitmapImageRep.size)
            newImage.addRepresentation(bitmapImageRep)
            
            ref?.release()
            return newImage
        } else {
            // If we couldn't get a Quick Look preview, fall back on the file's Finder icon.
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            
            icon.size = size
            return icon
        }
    }
    
    static func previewForFiles(atURLs urls: [URL], ofSize size: CGSize, asIcon: Bool, completion: @escaping ([NSImage]) -> Void) {
        DispatchQueue.global().async {
            var images: [NSImage] = []
            for url in urls {
                images.append(Self.previewForFile(atURL: url, ofSize: size, asIcon: asIcon))
            }
            
            DispatchQueue.main.async {
                completion(images)
            }
        }
    }
    
    func generatePreview(forURL url: URL, completion: @escaping (NSImage) -> Void) {
        DispatchQueue.global().async {
            guard let values = try? url.resourceValues(forKeys: [URLResourceKey.typeIdentifierKey]) else { return }
            if let type = values.typeIdentifier, UTTypeConformsTo(type as CFString, kUTTypeImage) {
                if let imageData = FileManager.default.contents(atPath: url.path) {
                    guard let image = NSImage(data: imageData) else { return }
                    DispatchQueue.main.async {
                        completion(image)
                    }
                }
            }
        }
    }
}
