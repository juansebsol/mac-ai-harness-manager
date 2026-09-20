import Foundation
import OSLog

actor DiscoveryCache {
    static let shared = DiscoveryCache()

    private let logger = Logger(subsystem: "com.harnessmanager.app", category: "Cache")
    private let fileManager = FileManager.default

    private var cacheDirectory: URL {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("HarnessManager", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    struct PackageManagerScan: Codable, Sendable {
        var brewFormulas: [String]
        var npmPackages: [String]
        var pnpmPackages: [String]
        var bunPackages: [String]
        var scannedAt: Date
    }

    struct VersionCacheEntry: Codable, Sendable {
        var latestVersion: String?
        var checkedAt: Date
    }

    private var packageScan: PackageManagerScan?
    private var latestVersions: [String: VersionCacheEntry] = [:]
    private var harnessSnapshots: [String: HarnessSnapshot] = [:]

    func load() {
        packageScan = loadJSON("package-scan.json")
        latestVersions = loadJSON("latest-versions.json") ?? [:]
        if let snaps: [HarnessSnapshot] = loadJSON("harness-snapshots.json") {
            harnessSnapshots = Dictionary(uniqueKeysWithValues: snaps.map { ($0.definitionId, $0) })
        }
    }

    func reset() {
        packageScan = nil
        latestVersions = [:]
        harnessSnapshots = [:]
        let urls = [
            cacheDirectory.appendingPathComponent("package-scan.json"),
            cacheDirectory.appendingPathComponent("latest-versions.json"),
            cacheDirectory.appendingPathComponent("harness-snapshots.json")
        ]
        for url in urls {
            try? fileManager.removeItem(at: url)
        }
        logger.info("Discovery cache reset")
    }

    func cachedPackageScan(maxAge: TimeInterval = 600) -> PackageManagerScan? {
        guard let packageScan else { return nil }
        guard Date().timeIntervalSince(packageScan.scannedAt) < maxAge else { return nil }
        return packageScan
    }

    func storePackageScan(_ scan: PackageManagerScan) {
        packageScan = scan
        saveJSON(scan, as: "package-scan.json")
    }

    func cachedLatestVersion(key: String, maxAge: TimeInterval = 3600 * 6) -> String? {
        guard let entry = latestVersions[key] else { return nil }
        guard Date().timeIntervalSince(entry.checkedAt) < maxAge else { return nil }
        return entry.latestVersion
    }

    func storeLatestVersion(key: String, version: String?) {
        latestVersions[key] = VersionCacheEntry(latestVersion: version, checkedAt: Date())
        saveJSON(latestVersions, as: "latest-versions.json")
    }

    func storeSnapshots(_ snapshots: [HarnessSnapshot]) {
        for snap in snapshots {
            harnessSnapshots[snap.definitionId] = snap
        }
        saveJSON(Array(harnessSnapshots.values), as: "harness-snapshots.json")
    }

    func cachedSnapshots() -> [HarnessSnapshot] {
        Array(harnessSnapshots.values)
    }

    private func loadJSON<T: Decodable>(_ name: String) -> T? {
        let url = cacheDirectory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func saveJSON<T: Encodable>(_ value: T, as name: String) {
        let url = cacheDirectory.appendingPathComponent(name)
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("Failed to write cache \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
