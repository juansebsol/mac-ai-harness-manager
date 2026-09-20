import AppKit
import SwiftUI

/// Bundled brand artwork first, installed app artwork second, legible initials last.
struct HarnessLogoView: View {
    let snapshot: HarnessSnapshot
    var size: CGFloat = 48

    private var artwork: NSImage? {
        if let bundled = NSImage(named: "Logo-\(snapshot.definitionId)") { return bundled }
        return LocalAppArtwork.image(at: snapshot.applicationPath)
    }

    var body: some View {
        Group {
            if let artwork {
                Image(nsImage: artwork).resizable().interpolation(.high).scaledToFit()
            } else {
                Text(initials).font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: size * 0.22))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true) // The adjacent tool name supplies the accessible label.
    }

    private var initials: String {
        let words = snapshot.name.split(separator: " ")
        return words.count > 1 ? words.prefix(2).compactMap(\.first).map(String.init).joined() : String(snapshot.name.prefix(2)).uppercased()
    }
}

@MainActor private enum LocalAppArtwork {
    static var cache: [String: NSImage] = [:]
    static var missing: Set<String> = []

    static func image(at path: String?) -> NSImage? {
        guard let path else { return nil }
        if let image = cache[path] { return image }
        guard !missing.contains(path) else { return nil }
        if let bundle = Bundle(path: path), let filename = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String {
            let name = (filename as NSString).deletingPathExtension
            let ext = (filename as NSString).pathExtension.isEmpty ? "icns" : (filename as NSString).pathExtension
            if let url = bundle.url(forResource: name, withExtension: ext), let image = NSImage(contentsOf: url) {
                cache[path] = image
                return image
            }
        }
        missing.insert(path)
        return nil
    }
}
