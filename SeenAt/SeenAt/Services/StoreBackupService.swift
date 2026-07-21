import Foundation
import SwiftData
import CryptoKit

struct StoreBackupArtifact: Codable, Equatable {
    let path: String
    let byteCount: Int64
    let sha256: String
}

struct StoreBackupManifest: Codable, Equatable {
    let sourceStorePath: String
    let storeFileName: String
    let targetSchemaVersion: String
    let createdAt: Date
    let artifacts: [StoreBackupArtifact]
}

struct StoreSchemaState: Codable, Equatable {
    let schemaVersion: String
}

enum StoreBackupService {
    enum BackupError: LocalizedError {
        case invalidBackup(URL)

        var errorDescription: String? {
            switch self {
            case .invalidBackup(let url):
                "The migration backup at \(url.path) is incomplete."
            }
        }
    }

    static let backupDirectoryName = "MigrationBackup"
    static let schemaStateFileName = "schema-state.json"

    static func defaultStoreURL() -> URL {
        ModelConfiguration().url
    }

    static func prepareForMigration(
        storeURL: URL,
        applicationSupportURL: URL,
        targetSchemaVersion: String,
        fileManager: FileManager = .default
    ) throws {
        try recoverInterruptedRestores(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            fileManager: fileManager
        )
        guard fileManager.fileExists(atPath: storeURL.path) else {
            return
        }

        let backupDirectory = applicationSupportURL.appendingPathComponent(backupDirectoryName)
        let currentBackup = backupDirectory.appendingPathComponent("current", isDirectory: true)
        if isSymbolicLink(at: backupDirectory) ||
            (fileManager.fileExists(atPath: backupDirectory.path) && !isRealDirectory(at: backupDirectory)) {
            throw BackupError.invalidBackup(backupDirectory)
        }

        if let state = try? loadSchemaState(at: applicationSupportURL, fileManager: fileManager),
           state.schemaVersion == targetSchemaVersion {
            if let manifest = try? loadManifest(at: currentBackup, fileManager: fileManager),
               manifest.targetSchemaVersion == targetSchemaVersion,
               isValidBackup(at: currentBackup, manifest: manifest, storeURL: storeURL, fileManager: fileManager) {
                return
            }
        }

        if let manifest = try? loadManifest(at: currentBackup, fileManager: fileManager),
           manifest.targetSchemaVersion == targetSchemaVersion,
           isValidBackup(at: currentBackup, manifest: manifest, storeURL: storeURL, fileManager: fileManager) {
            return
        }

        let stagingDirectory = backupDirectory.appendingPathComponent("staging-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)

        do {
            let storeDirectory = stagingDirectory.appendingPathComponent("store", isDirectory: true)
            try fileManager.createDirectory(at: storeDirectory, withIntermediateDirectories: true)

            var artifactPaths: [String] = []
            for sourceURL in storeArtifactURLs(for: storeURL, fileManager: fileManager) {
                let destinationURL = storeDirectory.appendingPathComponent(sourceURL.lastPathComponent)
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                artifactPaths.append("store/\(sourceURL.lastPathComponent)")
            }

            for sourceURL in try supportDirectoryURLs(for: storeURL, fileManager: fileManager) {
                let supportDirectory = stagingDirectory.appendingPathComponent("support", isDirectory: true)
                try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
                let destinationURL = supportDirectory.appendingPathComponent(sourceURL.lastPathComponent, isDirectory: true)
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                artifactPaths.append(contentsOf: filePaths(
                    under: destinationURL,
                    relativeTo: stagingDirectory,
                    fileManager: fileManager
                ))
            }

            let artifacts = try artifactPaths.sorted().map {
                try makeArtifact(relativePath: $0, backupDirectory: stagingDirectory, fileManager: fileManager)
            }

            let manifest = StoreBackupManifest(
                sourceStorePath: storeURL.path,
                storeFileName: storeURL.lastPathComponent,
                targetSchemaVersion: targetSchemaVersion,
                createdAt: .now,
                artifacts: artifacts
            )
            try writeManifest(manifest, to: stagingDirectory, fileManager: fileManager)

            guard isValidBackup(at: stagingDirectory, manifest: manifest, storeURL: storeURL, fileManager: fileManager) else {
                throw BackupError.invalidBackup(stagingDirectory)
            }

            try replaceCurrentBackup(
                at: currentBackup,
                with: stagingDirectory,
                fileManager: fileManager
            )
        } catch {
            try? fileManager.removeItem(at: stagingDirectory)
            throw error
        }
    }

    static func markMigrationSucceeded(
        applicationSupportURL: URL,
        schemaVersion: String,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)
        let state = StoreSchemaState(schemaVersion: schemaVersion)
        let data = try JSONEncoder().encode(state)
        try data.write(
            to: applicationSupportURL.appendingPathComponent(schemaStateFileName),
            options: .atomic
        )
    }

    static func applicationSupportURL(for storeURL: URL) -> URL {
        storeURL.deletingLastPathComponent()
    }

    static func loadManifest(
        at backupDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> StoreBackupManifest? {
        if isSymbolicLink(at: backupDirectory) {
            throw BackupError.invalidBackup(backupDirectory)
        }
        guard fileManager.fileExists(atPath: backupDirectory.path) else { return nil }
        guard isRealDirectory(at: backupDirectory) else {
            throw BackupError.invalidBackup(backupDirectory)
        }
        let url = backupDirectory.appendingPathComponent("manifest.json")
        if isSymbolicLink(at: url) {
            throw BackupError.invalidBackup(url)
        }
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        guard isRegularFile(at: url) else {
            throw BackupError.invalidBackup(url)
        }
        return try JSONDecoder().decode(StoreBackupManifest.self, from: Data(contentsOf: url))
    }

    static func loadSchemaState(
        at applicationSupportURL: URL,
        fileManager: FileManager = .default
    ) throws -> StoreSchemaState? {
        let url = applicationSupportURL.appendingPathComponent(schemaStateFileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(StoreSchemaState.self, from: Data(contentsOf: url))
    }

    static func restoreCurrentBackup(
        storeURL: URL,
        applicationSupportURL: URL,
        expectedSchemaVersion: String,
        fileManager: FileManager = .default
    ) throws {
        let backupDirectory = applicationSupportURL.appendingPathComponent(backupDirectoryName)
        if isSymbolicLink(at: backupDirectory) ||
            (fileManager.fileExists(atPath: backupDirectory.path) && !isRealDirectory(at: backupDirectory)) {
            throw BackupError.invalidBackup(backupDirectory)
        }
        let currentBackup = backupDirectory
            .appendingPathComponent("current", isDirectory: true)
        guard let manifest = try loadManifest(at: currentBackup, fileManager: fileManager),
              manifest.targetSchemaVersion == expectedSchemaVersion,
              isValidBackup(at: currentBackup, manifest: manifest, storeURL: storeURL, fileManager: fileManager) else {
            throw BackupError.invalidBackup(currentBackup)
        }

        let restoreDirectory = applicationSupportURL
            .appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: restoreDirectory, withIntermediateDirectories: true)
        var preserveRestoreDirectory = false
        defer {
            if !preserveRestoreDirectory {
                try? fileManager.removeItem(at: restoreDirectory)
            }
        }

        do {
            for artifact in manifest.artifacts {
                let sourceURL = currentBackup.appendingPathComponent(artifact.path)
                let destinationURL = restoreDirectory.appendingPathComponent(artifact.path)
                try fileManager.createDirectory(
                    at: destinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            }
            try writeManifest(manifest, to: restoreDirectory, fileManager: fileManager)
            guard isValidBackup(at: restoreDirectory, manifest: manifest, storeURL: storeURL, fileManager: fileManager) else {
                throw BackupError.invalidBackup(restoreDirectory)
            }

            let quarantineDirectory = restoreDirectory.appendingPathComponent("quarantine", isDirectory: true)
            try fileManager.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true)
            var quarantined: [(original: URL, backup: URL)] = []
            var installed: [URL] = []

            do {
                let liveURLs = storeArtifactURLs(for: storeURL, fileManager: fileManager)
                    + (try supportDirectoryURLs(for: storeURL, fileManager: fileManager))
                for liveURL in liveURLs {
                    let backupURL = quarantineDirectory.appendingPathComponent(liveURL.lastPathComponent)
                    try fileManager.moveItem(at: liveURL, to: backupURL)
                    quarantined.append((liveURL, backupURL))
                }

                for artifact in manifest.artifacts {
                    let sourceURL = restoreDirectory.appendingPathComponent(artifact.path)
                    let destinationURL = destinationURL(for: artifact.path, storeURL: storeURL)
                    guard destinationIsContained(destinationURL, by: storeURL) else {
                        throw BackupError.invalidBackup(restoreDirectory)
                    }
                    try fileManager.createDirectory(
                        at: destinationURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                    installed.append(destinationURL)
                }

                try fileManager.removeItem(at: quarantineDirectory)
            } catch {
                var rollbackFailed = false
                for destinationURL in installed {
                    do {
                        try fileManager.removeItem(at: destinationURL)
                    } catch {
                        rollbackFailed = true
                    }
                }
                let quarantinedSupportURLs = Set(
                    quarantined
                        .filter { supportDirectoryNames(for: storeURL).contains($0.original.lastPathComponent) }
                        .map(\.original)
                )
                for supportURL in quarantinedSupportURLs {
                    if fileManager.fileExists(atPath: supportURL.path) {
                        do {
                            try fileManager.removeItem(at: supportURL)
                        } catch {
                            rollbackFailed = true
                        }
                    }
                }
                for item in quarantined.reversed() {
                    do {
                        try fileManager.moveItem(at: item.backup, to: item.original)
                    } catch {
                        rollbackFailed = true
                    }
                }
                if rollbackFailed {
                    preserveRestoreDirectory = true
                    throw BackupError.invalidBackup(restoreDirectory)
                }
                throw error
            }
        }
    }

    private static func writeManifest(
        _ manifest: StoreBackupManifest,
        to directory: URL,
        fileManager: FileManager
    ) throws {
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: directory.appendingPathComponent("manifest.json"), options: .atomic)
    }

    private static func makeArtifact(
        relativePath: String,
        backupDirectory: URL,
        fileManager: FileManager
    ) throws -> StoreBackupArtifact {
        let url = backupDirectory.appendingPathComponent(relativePath)
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let digest = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
        return StoreBackupArtifact(path: relativePath, byteCount: byteCount, sha256: digest)
    }

    private static func filePaths(
        under directory: URL,
        relativeTo root: URL,
        fileManager: FileManager
    ) -> [String] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        ) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL,
                  let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                  let isSymbolicLink = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink,
                  isDirectory == false,
                  isSymbolicLink == false else {
                return nil
            }
            return url.path.replacingOccurrences(of: root.path + "/", with: "")
        }
    }

    private static func storeArtifactURLs(for storeURL: URL, fileManager: FileManager) -> [URL] {
        let baseURL = storeURL.deletingPathExtension()
        let sidecars = [
            baseURL.appendingPathExtension("\(storeURL.pathExtension)-wal"),
            baseURL.appendingPathExtension("\(storeURL.pathExtension)-shm"),
        ]
        return ([storeURL] + sidecars).filter { fileManager.fileExists(atPath: $0.path) }
    }

    private static func supportDirectoryURLs(for storeURL: URL, fileManager: FileManager) throws -> [URL] {
        let parent = storeURL.deletingLastPathComponent()
        return try supportDirectoryNames(for: storeURL).compactMap { name in
            parent.appendingPathComponent(name, isDirectory: true)
        }.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
                return nil
            }
            if values.isSymbolicLink == true {
                throw BackupError.invalidBackup(url)
            }
            return values.isDirectory == true ? url : nil
        }
    }

    private static func supportDirectoryNames(for storeURL: URL) -> Set<String> {
        let baseName = storeURL.deletingPathExtension().lastPathComponent
        return [
            "\(baseName)_SUPPORT",
            "\(baseName).SUPPORT",
            "\(storeURL.lastPathComponent)_SUPPORT",
        ]
    }

    private static func isValidBackup(
        at backupDirectory: URL,
        manifest: StoreBackupManifest,
        storeURL: URL,
        fileManager: FileManager,
        verifyChecksums: Bool = true
    ) -> Bool {
        let manifestURL = backupDirectory.appendingPathComponent("manifest.json")
        guard isRealDirectory(at: backupDirectory),
              isRegularFile(at: manifestURL) else {
            return false
        }
        let storeBaseName = storeURL.deletingPathExtension().lastPathComponent
        let allowedStoreNames = Set([
            storeURL.lastPathComponent,
            "\(storeBaseName).\(storeURL.pathExtension)-wal",
            "\(storeBaseName).\(storeURL.pathExtension)-shm",
        ])
        let artifactPaths = manifest.artifacts.map(\.path)
        guard Set(artifactPaths).count == artifactPaths.count,
              manifest.artifacts.allSatisfy({ artifact in
                  guard artifact.path == artifact.path.split(separator: "/").map(String.init).joined(separator: "/"),
                        !artifact.path.hasPrefix("/"),
                        !artifact.path.hasSuffix("/") else {
                      return false
                  }
                  let components = artifact.path.split(separator: "/").map(String.init)
                  guard !components.contains(where: { $0 == "." || $0 == ".." }),
                        components.first == "store" || components.first == "support" else {
                      return false
                  }
                  if components.first == "store" {
                      return components.count == 2 && allowedStoreNames.contains(components[1])
                  }
                  return components.count >= 3 && supportDirectoryNames(for: storeURL).contains(components[1])
              }) else {
            return false
        }
        guard manifest.sourceStorePath == storeURL.path,
              manifest.storeFileName == storeURL.lastPathComponent,
              manifest.artifacts.contains(where: { $0.path == "store/\(manifest.storeFileName)" }) else {
            return false
        }
        let actualPaths = Set(
            filePaths(
                under: backupDirectory.appendingPathComponent("store", isDirectory: true),
                relativeTo: backupDirectory,
                fileManager: fileManager
            ) + filePaths(
                under: backupDirectory.appendingPathComponent("support", isDirectory: true),
                relativeTo: backupDirectory,
                fileManager: fileManager
            )
        )
        guard isSafeFileTree(at: backupDirectory.appendingPathComponent("store", isDirectory: true)),
              isSafeFileTree(at: backupDirectory.appendingPathComponent("support", isDirectory: true)),
              isSafeFileTree(at: backupDirectory),
              actualPaths == Set(artifactPaths) else {
            return false
        }
        return manifest.artifacts.allSatisfy { artifact in
            let url = backupDirectory.appendingPathComponent(artifact.path)
            guard fileManager.fileExists(atPath: url.path),
                  (try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]).isRegularFile) == true,
                  (try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]).isSymbolicLink) == false,
                  let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                  let byteCount = (attributes[.size] as? NSNumber)?.int64Value,
                  byteCount == artifact.byteCount else {
                return false
            }
            guard verifyChecksums else { return true }
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return false }
            let digest = SHA256.hash(data: data)
                .map { String(format: "%02x", $0) }
                .joined()
            return digest == artifact.sha256
        }
    }

    private static func destinationURL(for relativePath: String, storeURL: URL) -> URL {
        let components = relativePath.split(separator: "/").map(String.init)
        let parent = storeURL.deletingLastPathComponent()
        if components.first == "store" {
            return parent.appendingPathComponent(components.dropFirst().joined(separator: "/"))
        }
        return parent.appendingPathComponent(components.dropFirst().joined(separator: "/"))
    }

    private static func destinationIsContained(_ destinationURL: URL, by storeURL: URL) -> Bool {
        let root = storeURL.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path
        let destination = destinationURL.resolvingSymlinksInPath().standardizedFileURL.path
        return destination == root || destination.hasPrefix(root + "/")
    }

    private static func recoverInterruptedRestores(
        storeURL: URL,
        applicationSupportURL: URL,
        fileManager: FileManager
    ) throws {
        guard fileManager.fileExists(atPath: applicationSupportURL.path) else { return }
        let restoreDirectories = try fileManager.contentsOfDirectory(
            at: applicationSupportURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        ).filter { url in
            url.lastPathComponent.hasPrefix("restore-") &&
            (try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]).isDirectory) == true &&
            (try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]).isSymbolicLink) == false
        }

        for restoreDirectory in restoreDirectories {
            let quarantineDirectory = restoreDirectory.appendingPathComponent("quarantine", isDirectory: true)
            if isSymbolicLink(at: quarantineDirectory) {
                throw BackupError.invalidBackup(restoreDirectory)
            }
            guard fileManager.fileExists(atPath: quarantineDirectory.path) else {
                try fileManager.removeItem(at: restoreDirectory)
                continue
            }
            guard isRealDirectory(at: quarantineDirectory) else {
                throw BackupError.invalidBackup(restoreDirectory)
            }
            let quarantined = try fileManager.contentsOfDirectory(
                at: quarantineDirectory,
                includingPropertiesForKeys: nil
            )
            guard !quarantined.isEmpty else {
                try fileManager.removeItem(at: restoreDirectory)
                continue
            }

            var restored: [(destination: URL, quarantine: URL)] = []
            let replacedDirectory = restoreDirectory.appendingPathComponent("replaced", isDirectory: true)
            if isSymbolicLink(at: replacedDirectory) {
                throw BackupError.invalidBackup(restoreDirectory)
            }
            if fileManager.fileExists(atPath: replacedDirectory.path) {
                guard isRealDirectory(at: replacedDirectory) else {
                    throw BackupError.invalidBackup(restoreDirectory)
                }
            } else {
                try fileManager.createDirectory(at: replacedDirectory, withIntermediateDirectories: true)
            }
            var replaced: [(destination: URL, backup: URL)] = []
            do {
                for quarantinedURL in quarantined {
                    let name = quarantinedURL.lastPathComponent
                        let values = try quarantinedURL.resourceValues(
                            forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
                        )
                    let destination: URL
                    if name == storeURL.lastPathComponent ||
                        name == "\(storeURL.deletingPathExtension().lastPathComponent).\(storeURL.pathExtension)-wal" ||
                        name == "\(storeURL.deletingPathExtension().lastPathComponent).\(storeURL.pathExtension)-shm" {
                        guard values.isRegularFile == true, values.isSymbolicLink != true else {
                            throw BackupError.invalidBackup(restoreDirectory)
                        }
                        destination = storeURL.deletingLastPathComponent().appendingPathComponent(name)
                    } else if supportDirectoryNames(for: storeURL).contains(name) {
                        guard values.isDirectory == true, values.isSymbolicLink != true else {
                            throw BackupError.invalidBackup(restoreDirectory)
                        }
                        guard isSafeFileTree(at: quarantinedURL) else {
                            throw BackupError.invalidBackup(restoreDirectory)
                        }
                        destination = storeURL.deletingLastPathComponent().appendingPathComponent(name, isDirectory: true)
                    } else {
                        throw BackupError.invalidBackup(restoreDirectory)
                    }
                    if fileManager.fileExists(atPath: destination.path) {
                        let backupDestination = replacedDirectory.appendingPathComponent(name, isDirectory: values.isDirectory == true)
                        try fileManager.moveItem(at: destination, to: backupDestination)
                        replaced.append((destination, backupDestination))
                    }
                    try fileManager.moveItem(at: quarantinedURL, to: destination)
                    restored.append((destination, quarantinedURL))
                }
                try fileManager.removeItem(at: restoreDirectory)
            } catch {
                var rollbackFailed = false
                for item in restored.reversed() {
                    do {
                        if fileManager.fileExists(atPath: item.destination.path) {
                            try fileManager.moveItem(at: item.destination, to: item.quarantine)
                        }
                    } catch {
                        rollbackFailed = true
                    }
                }
                for item in replaced.reversed() {
                    do {
                        try fileManager.moveItem(at: item.backup, to: item.destination)
                    } catch {
                        rollbackFailed = true
                    }
                }
                if rollbackFailed {
                    throw BackupError.invalidBackup(restoreDirectory)
                }
                throw error
            }
        }
    }

    private static func isSafeFileTree(at directory: URL) -> Bool {
        guard !isSymbolicLink(at: directory) else { return false }
        guard FileManager.default.fileExists(atPath: directory.path) else { return true }
        guard let values = try? directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              values.isDirectory == true,
              values.isSymbolicLink != true,
              let enumerator = FileManager.default.enumerator(
                  at: directory,
                  includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey]
              ) else {
            return false
        }
        for item in enumerator {
            guard let url = item as? URL,
                  let itemValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey]),
                  itemValues.isSymbolicLink != true,
                  itemValues.isDirectory == true || itemValues.isRegularFile == true else {
                return false
            }
        }
        return true
    }

    private static func isSymbolicLink(at url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private static func isRealDirectory(at url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
            return false
        }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    private static func isRegularFile(at url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
            return false
        }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private static func replaceCurrentBackup(
        at currentBackup: URL,
        with stagingDirectory: URL,
        fileManager: FileManager
    ) throws {
        let parent = currentBackup.deletingLastPathComponent()
        if isSymbolicLink(at: parent) {
            throw BackupError.invalidBackup(parent)
        }
        if fileManager.fileExists(atPath: parent.path) {
            guard isRealDirectory(at: parent) else {
                throw BackupError.invalidBackup(parent)
            }
        }
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)

        if isSymbolicLink(at: currentBackup) {
            throw BackupError.invalidBackup(currentBackup)
        }
        if fileManager.fileExists(atPath: currentBackup.path) {
            guard isRealDirectory(at: currentBackup) else {
                throw BackupError.invalidBackup(currentBackup)
            }
            _ = try fileManager.replaceItemAt(currentBackup, withItemAt: stagingDirectory)
        } else {
            try fileManager.moveItem(at: stagingDirectory, to: currentBackup)
        }
    }
}
