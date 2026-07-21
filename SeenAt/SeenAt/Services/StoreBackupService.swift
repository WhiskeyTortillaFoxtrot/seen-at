import Foundation
import SwiftData
import CryptoKit

struct StoreBackupArtifact: Codable, Equatable {
    let path: String
    let byteCount: Int64
    let sha256: String
}

enum StoreRestorePhase: String, Codable {
    case quarantining
    case installing
    case installed
}

struct StoreRestoreJournal: Codable {
    let backupID: UUID
    var phase: StoreRestorePhase
    let artifacts: [StoreBackupArtifact]
}

struct StoreMigrationAttempt: Codable {
    let backupID: UUID
    let sourceStorePath: String
    let targetSchemaVersion: String
    let stagingDirectoryPath: String?
}

struct StoreBackupManifest: Codable, Equatable {
    let backupID: UUID
    let sourceStorePath: String
    let storeFileName: String
    let targetSchemaVersion: String
    let createdAt: Date
    let artifacts: [StoreBackupArtifact]
}

enum StoreBackupService {
    enum BackupError: LocalizedError {
        case invalidBackup(URL)
        case staleMigrationAttempt(URL)
        case migrationFinalization(URL)
        case recoveryRequired(URL)

        var errorDescription: String? {
            switch self {
            case .invalidBackup(let url):
                "The migration backup at \(url.path) is incomplete."
            case .staleMigrationAttempt:
                "An earlier migration attempt requires attention before this store can be opened."
            case .migrationFinalization(let url):
                "Migration safety state could not be finalized at \(url.path)."
            case .recoveryRequired(let url):
                "Migration recovery requires attention at \(url.path)."
            }
        }
    }

    static let backupDirectoryName = "MigrationBackup"
    static let legacySchemaStateFileName = "schema-state.json"
    static let migrationAttemptFileName = "migration-attempt.json"
    static let failedStoreDirectoryPrefix = "failed-migration-store-"
    static let recoveryQuarantineDirectoryPrefix = "recovery-quarantine-"

    static func defaultStoreURL() -> URL {
        ModelConfiguration().url
    }

    static func prepareForMigration(
        storeURL: URL,
        applicationSupportURL: URL,
        targetSchemaVersion: String,
        fileManager: FileManager = .default
    ) throws -> UUID? {
        try recoverInterruptedRestores(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            fileManager: fileManager
        )
        let backupDirectory = applicationSupportURL.appendingPathComponent(backupDirectoryName)
        let currentBackup = backupDirectory.appendingPathComponent("current", isDirectory: true)
        if isSymbolicLink(at: backupDirectory) ||
            (fileManager.fileExists(atPath: backupDirectory.path) && !isRealDirectory(at: backupDirectory)) {
            throw BackupError.invalidBackup(backupDirectory)
        }

        if let attempt = try loadMigrationAttempt(
            at: applicationSupportURL,
            fileManager: fileManager
        ) {
            let sourceMatches = attempt.sourceStorePath == storeURL.path
            let targetMatches = attempt.targetSchemaVersion == targetSchemaVersion
            if !sourceMatches {
                guard isRegularFile(at: storeURL) else {
                    throw BackupError.staleMigrationAttempt(storeURL)
                }
                try validateStoreArtifacts(storeURL: storeURL, fileManager: fileManager)
                _ = try supportDirectoryURLs(for: storeURL, fileManager: fileManager)
                try completeMigrationAttempt(applicationSupportURL: applicationSupportURL, fileManager: fileManager)
            } else if !targetMatches {
                guard let manifest = try? loadManifest(at: currentBackup, fileManager: fileManager),
                      manifest.backupID == attempt.backupID,
                      manifest.targetSchemaVersion == attempt.targetSchemaVersion,
                      isValidBackup(
                          at: currentBackup,
                          manifest: manifest,
                          storeURL: storeURL,
                          fileManager: fileManager
                      ) else {
                    throw BackupError.staleMigrationAttempt(storeURL)
                }
                try restoreCurrentBackup(
                    storeURL: storeURL,
                    applicationSupportURL: applicationSupportURL,
                    expectedSchemaVersion: attempt.targetSchemaVersion,
                    backupID: attempt.backupID,
                    fileManager: fileManager
                )
                try completeMigrationAttempt(applicationSupportURL: applicationSupportURL, fileManager: fileManager)
            } else if let manifest = try? loadManifest(at: currentBackup, fileManager: fileManager),
                      manifest.backupID == attempt.backupID,
                      manifest.targetSchemaVersion == targetSchemaVersion,
                      isValidBackup(
                          at: currentBackup,
                          manifest: manifest,
                          storeURL: storeURL,
                          fileManager: fileManager,
                          verifyChecksums: false
                      ) {
                try ensureLiveStoreForAttempt(
                    storeURL: storeURL,
                    applicationSupportURL: applicationSupportURL,
                    targetSchemaVersion: targetSchemaVersion,
                    backupID: attempt.backupID,
                    fileManager: fileManager
                )
                return attempt.backupID
            } else if let stagingDirectoryPath = attempt.stagingDirectoryPath {
                let stagingDirectory = URL(fileURLWithPath: stagingDirectoryPath, isDirectory: true)
                guard stagingDirectory.lastPathComponent.hasPrefix("staging-"),
                      stagingDirectory.deletingLastPathComponent().standardizedFileURL.path == backupDirectory.standardizedFileURL.path,
                      let manifest = try loadManifest(at: stagingDirectory, fileManager: fileManager),
                      manifest.backupID == attempt.backupID,
                      manifest.targetSchemaVersion == targetSchemaVersion,
                      isValidBackup(
                          at: stagingDirectory,
                          manifest: manifest,
                          storeURL: storeURL,
                          fileManager: fileManager,
                          verifyChecksums: false
                      ) else {
                    throw BackupError.invalidBackup(currentBackup)
                }
                try replaceCurrentBackup(
                    at: currentBackup,
                    with: stagingDirectory,
                    fileManager: fileManager
                )
                try ensureLiveStoreForAttempt(
                    storeURL: storeURL,
                    applicationSupportURL: applicationSupportURL,
                    targetSchemaVersion: targetSchemaVersion,
                    backupID: attempt.backupID,
                    fileManager: fileManager
                )
                return attempt.backupID
            } else {
                throw BackupError.invalidBackup(currentBackup)
            }
        }

        guard isRegularFile(at: storeURL) else {
            guard !fileManager.fileExists(atPath: storeURL.path) && !isSymbolicLink(at: storeURL) else {
                throw BackupError.invalidBackup(storeURL)
            }
            if storeSidecarURLs(for: storeURL).contains(where: {
                fileManager.fileExists(atPath: $0.path) || isSymbolicLink(at: $0)
            }) {
                throw BackupError.invalidBackup(storeURL)
            }
            return nil
        }
        try validateStoreArtifacts(storeURL: storeURL, fileManager: fileManager)

        if let manifest = try? loadManifest(at: currentBackup, fileManager: fileManager),
           manifest.targetSchemaVersion == targetSchemaVersion,
           isValidBackup(
               at: currentBackup,
               manifest: manifest,
               storeURL: storeURL,
               fileManager: fileManager,
               verifyChecksums: false
           ) {
            return nil
        }

        try cleanupStagingDirectories(in: backupDirectory, fileManager: fileManager)
        let stagingDirectory = backupDirectory.appendingPathComponent("staging-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        try excludeFromBackup(at: backupDirectory, fileManager: fileManager)

        var migrationAttemptWritten = false
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
                backupID: UUID(),
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

            try writeMigrationAttempt(
                StoreMigrationAttempt(
                    backupID: manifest.backupID,
                    sourceStorePath: storeURL.path,
                    targetSchemaVersion: targetSchemaVersion,
                    stagingDirectoryPath: stagingDirectory.path
                ),
                to: applicationSupportURL,
                fileManager: fileManager
            )
            migrationAttemptWritten = true
            try replaceCurrentBackup(
                at: currentBackup,
                with: stagingDirectory,
                fileManager: fileManager
            )
            return manifest.backupID
        } catch {
            if !migrationAttemptWritten {
                try? fileManager.removeItem(at: stagingDirectory)
            }
            throw error
        }
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


    static func restoreCurrentBackup(
        storeURL: URL,
        applicationSupportURL: URL,
        expectedSchemaVersion: String,
        backupID: UUID,
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
              manifest.backupID == backupID,
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
            let liveURLs = storeArtifactURLs(for: storeURL, fileManager: fileManager)
                + (try supportDirectoryURLs(for: storeURL, fileManager: fileManager))
            guard !fileManager.fileExists(atPath: storeURL.path) || isRegularFile(at: storeURL) else {
                throw BackupError.invalidBackup(storeURL)
            }
            guard !isSymbolicLink(at: storeURL) else {
                throw BackupError.invalidBackup(storeURL)
            }
            try validateStoreArtifacts(storeURL: storeURL, fileManager: fileManager)
            var journal = try makeRestoreJournal(
                backupID: manifest.backupID,
                liveURLs: liveURLs,
                storeURL: storeURL,
                fileManager: fileManager
            )
            try writeRestoreJournal(journal, to: restoreDirectory, fileManager: fileManager)

            do {
                for liveURL in liveURLs {
                    let backupURL = quarantineDirectory.appendingPathComponent(liveURL.lastPathComponent)
                    try fileManager.moveItem(at: liveURL, to: backupURL)
                    quarantined.append((liveURL, backupURL))
                }

                journal.phase = .installing
                try writeRestoreJournal(journal, to: restoreDirectory, fileManager: fileManager)

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

                journal.phase = .installed
                try writeRestoreJournal(journal, to: restoreDirectory, fileManager: fileManager)
                let failedStoreDirectory = applicationSupportURL
                    .appendingPathComponent("\(failedStoreDirectoryPrefix)\(UUID().uuidString)", isDirectory: true)
                try fileManager.moveItem(at: quarantineDirectory, to: failedStoreDirectory)
                try? excludeFromBackup(at: failedStoreDirectory, fileManager: fileManager)
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

    static func cleanupAfterSuccessfulLaunch(
        applicationSupportURL: URL,
        fileManager: FileManager = .default
    ) throws {
        guard fileManager.fileExists(atPath: applicationSupportURL.path) else { return }
        let entries = try fileManager.contentsOfDirectory(at: applicationSupportURL, includingPropertiesForKeys: nil)
        for entry in entries where entry.lastPathComponent.hasPrefix(failedStoreDirectoryPrefix) {
            try removeIfPresent(entry, fileManager: fileManager)
        }
        try removeIfPresent(
            applicationSupportURL.appendingPathComponent(legacySchemaStateFileName),
            fileManager: fileManager
        )

        let backupDirectory = applicationSupportURL.appendingPathComponent(backupDirectoryName)
        try cleanupStagingDirectories(in: backupDirectory, fileManager: fileManager)
    }

    static func completeMigrationAttempt(
        applicationSupportURL: URL,
        fileManager: FileManager = .default
    ) throws {
        do {
            try clearMigrationAttempt(at: applicationSupportURL, fileManager: fileManager)
        } catch {
            throw BackupError.migrationFinalization(
                applicationSupportURL.appendingPathComponent(migrationAttemptFileName)
            )
        }
    }

    static func resetStoreData(
        storeURL: URL,
        applicationSupportURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let baseURL = storeURL.deletingPathExtension()
        let sidecars = [
            baseURL.appendingPathExtension("\(storeURL.pathExtension)-wal"),
            baseURL.appendingPathExtension("\(storeURL.pathExtension)-shm"),
        ]
        for url in [storeURL] + sidecars {
            try removeIfPresent(url, fileManager: fileManager)
        }

        for supportURL in supportDirectoryNames(for: storeURL).map({
            storeURL.deletingLastPathComponent().appendingPathComponent($0, isDirectory: true)
        }) {
            try removeIfPresent(supportURL, fileManager: fileManager)
        }

        if fileManager.fileExists(atPath: applicationSupportURL.path) {
            let entries = try fileManager.contentsOfDirectory(at: applicationSupportURL, includingPropertiesForKeys: nil)
            for entry in entries where entry.lastPathComponent.hasPrefix("restore-") ||
                entry.lastPathComponent.hasPrefix(failedStoreDirectoryPrefix) ||
                entry.lastPathComponent.hasPrefix(recoveryQuarantineDirectoryPrefix) {
                try removeIfPresent(entry, fileManager: fileManager)
            }
        }

        try removeIfPresent(
            applicationSupportURL.appendingPathComponent(backupDirectoryName),
            fileManager: fileManager
        )
        try removeIfPresent(
            applicationSupportURL.appendingPathComponent(legacySchemaStateFileName),
            fileManager: fileManager
        )
        try removeIfPresent(
            applicationSupportURL.appendingPathComponent(migrationAttemptFileName),
            fileManager: fileManager
        )
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
            let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
            return url.path.hasPrefix(prefix) ? String(url.path.dropFirst(prefix.count)) : url.path
        }
    }

    private static func storeArtifactURLs(for storeURL: URL, fileManager: FileManager) -> [URL] {
        return ([storeURL] + storeSidecarURLs(for: storeURL)).filter {
            fileManager.fileExists(atPath: $0.path)
        }
    }

    private static func storeSidecarURLs(for storeURL: URL) -> [URL] {
        let baseURL = storeURL.deletingPathExtension()
        return [
            baseURL.appendingPathExtension("\(storeURL.pathExtension)-wal"),
            baseURL.appendingPathExtension("\(storeURL.pathExtension)-shm"),
        ]
    }

    private static func validateStoreArtifacts(
        storeURL: URL,
        fileManager: FileManager
    ) throws {
        for sidecar in storeSidecarURLs(for: storeURL) where fileManager.fileExists(atPath: sidecar.path) || isSymbolicLink(at: sidecar) {
            guard isRegularFile(at: sidecar) else {
                throw BackupError.invalidBackup(sidecar)
            }
        }
    }

    private static func ensureLiveStoreForAttempt(
        storeURL: URL,
        applicationSupportURL: URL,
        targetSchemaVersion: String,
        backupID: UUID,
        fileManager: FileManager
    ) throws {
        if fileManager.fileExists(atPath: storeURL.path) {
            guard isRegularFile(at: storeURL) else {
                throw BackupError.invalidBackup(storeURL)
            }
            _ = try supportDirectoryURLs(for: storeURL, fileManager: fileManager)
            try validateStoreArtifacts(storeURL: storeURL, fileManager: fileManager)
            return
        }
        guard !isSymbolicLink(at: storeURL) else {
            throw BackupError.invalidBackup(storeURL)
        }
        try restoreCurrentBackup(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            expectedSchemaVersion: targetSchemaVersion,
            backupID: backupID,
            fileManager: fileManager
        )
    }

    private static func supportDirectoryURLs(for storeURL: URL, fileManager: FileManager) throws -> [URL] {
        let parent = storeURL.deletingLastPathComponent()
        return try supportDirectoryNames(for: storeURL).compactMap { name in
            let url = parent.appendingPathComponent(name, isDirectory: true)
            guard fileManager.fileExists(atPath: url.path) || isSymbolicLink(at: url) else {
                return nil
            }
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true {
                throw BackupError.invalidBackup(url)
            }
            guard values.isDirectory == true else {
                throw BackupError.invalidBackup(url)
            }
            return url
        }
    }

    private static func supportDirectoryNames(for storeURL: URL) -> Set<String> {
        let baseName = storeURL.deletingPathExtension().lastPathComponent
        return [".\(baseName)_SUPPORT"]
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
        guard isSafeFileTree(at: backupDirectory.appendingPathComponent("store", isDirectory: true), fileManager: fileManager),
              isSafeFileTree(at: backupDirectory.appendingPathComponent("support", isDirectory: true), fileManager: fileManager),
              isSafeFileTree(at: backupDirectory, fileManager: fileManager),
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
        return parent.appendingPathComponent(components.dropFirst().joined(separator: "/"))
    }

    private static func restoreDestinationRoots(
        manifest: StoreBackupManifest,
        storeURL: URL
    ) -> [URL] {
        Set(manifest.artifacts.compactMap { artifact in
            let components = artifact.path.split(separator: "/").map(String.init)
            guard components.count >= 2 else { return nil }
            return destinationURL(
                for: "\(components[0])/\(components[1])",
                storeURL: storeURL
            )
        }).map { $0 }
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
        if let quarantine = try fileManager.contentsOfDirectory(
            at: applicationSupportURL,
            includingPropertiesForKeys: nil
        ).first(where: {
            $0.lastPathComponent.hasPrefix(recoveryQuarantineDirectoryPrefix) &&
            (fileManager.fileExists(atPath: $0.path) || isSymbolicLink(at: $0))
        }) {
            throw BackupError.recoveryRequired(quarantine)
        }

        for restoreDirectory in restoreDirectories {
            do {
                try recoverInterruptedRestore(
                    at: restoreDirectory,
                    storeURL: storeURL,
                    fileManager: fileManager
                )
            } catch {
                let quarantineURL = applicationSupportURL.appendingPathComponent(
                    "\(recoveryQuarantineDirectoryPrefix)\(UUID().uuidString)",
                    isDirectory: true
                )
                do {
                    try fileManager.moveItem(at: restoreDirectory, to: quarantineURL)
                } catch {
                    throw BackupError.recoveryRequired(restoreDirectory)
                }
                try? excludeFromBackup(at: quarantineURL, fileManager: fileManager)
                throw BackupError.recoveryRequired(quarantineURL)
            }
        }
    }

    private static func recoverInterruptedRestore(
        at restoreDirectory: URL,
        storeURL: URL,
        fileManager: FileManager
    ) throws {
        guard let journal = try loadRestoreJournal(at: restoreDirectory, fileManager: fileManager) else {
            try? fileManager.removeItem(at: restoreDirectory)
            return
        }
        guard let manifest = try? loadManifest(at: restoreDirectory, fileManager: fileManager),
              journal.backupID == manifest.backupID,
              isValidBackup(
                  at: restoreDirectory,
                  manifest: manifest,
                  storeURL: storeURL,
                  fileManager: fileManager,
                  verifyChecksums: true
              ) else {
            throw BackupError.invalidBackup(restoreDirectory)
        }
        let quarantineDirectory = restoreDirectory.appendingPathComponent("quarantine", isDirectory: true)
        if isSymbolicLink(at: quarantineDirectory) {
            throw BackupError.invalidBackup(restoreDirectory)
        }
        guard fileManager.fileExists(atPath: quarantineDirectory.path) else {
            try fileManager.removeItem(at: restoreDirectory)
            return
        }
        guard isRealDirectory(at: quarantineDirectory) else {
            throw BackupError.invalidBackup(restoreDirectory)
        }
        let quarantined = try fileManager.contentsOfDirectory(
            at: quarantineDirectory,
            includingPropertiesForKeys: nil
        )
        guard isValidRestoreQuarantine(
            at: quarantineDirectory,
            journal: journal,
            fileManager: fileManager,
            requireComplete: journal.phase == .installed
        ) else {
            throw BackupError.invalidBackup(restoreDirectory)
        }

        if journal.phase == .installed {
            let failedStoreDirectory = restoreDirectory.deletingLastPathComponent()
                .appendingPathComponent("\(failedStoreDirectoryPrefix)\(UUID().uuidString)", isDirectory: true)
            try fileManager.moveItem(at: quarantineDirectory, to: failedStoreDirectory)
            try? excludeFromBackup(at: failedStoreDirectory, fileManager: fileManager)
            try fileManager.removeItem(at: restoreDirectory)
            return
        }

        var restored: [(destination: URL, quarantine: URL)] = []
        if journal.phase == .installing {
            let originalNames = Set(journal.artifacts.map { artifact in
                artifact.path.split(separator: "/").dropFirst().first.map(String.init) ?? artifact.path
            })
            for destination in restoreDestinationRoots(
                manifest: manifest,
                storeURL: storeURL
            ) where !originalNames.contains(destination.lastPathComponent) {
                try removeIfPresent(destination, fileManager: fileManager)
            }
        }
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
                    guard isSafeFileTree(at: quarantinedURL, fileManager: fileManager) else {
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
        try fileManager.removeItem(at: restoreDirectory)
    }

    private static func isSafeFileTree(at directory: URL, fileManager: FileManager = .default) -> Bool {
        guard !isSymbolicLink(at: directory) else { return false }
        guard fileManager.fileExists(atPath: directory.path) else { return true }
        guard let values = try? directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              values.isDirectory == true,
              values.isSymbolicLink != true,
              let enumerator = fileManager.enumerator(
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

    private static func makeRestoreJournal(
        backupID: UUID,
        liveURLs: [URL],
        storeURL: URL,
        fileManager: FileManager
    ) throws -> StoreRestoreJournal {
        let artifacts = try liveURLs.map { url -> StoreBackupArtifact in
            if storeArtifactURLs(for: storeURL, fileManager: fileManager).contains(url) {
                guard isRegularFile(at: url) else {
                    throw BackupError.invalidBackup(url)
                }
                return try makeArtifactForFile(path: url.lastPathComponent, url: url, fileManager: fileManager)
            }
            let name = url.lastPathComponent
            if isRealDirectory(at: url) {
                return StoreBackupArtifact(path: name, byteCount: 0, sha256: "directory")
            }
            guard isRegularFile(at: url) else {
                throw BackupError.invalidBackup(url)
            }
            return try makeArtifactForFile(path: name, url: url, fileManager: fileManager)
        }
        return StoreRestoreJournal(backupID: backupID, phase: .quarantining, artifacts: artifacts)
    }

    private static func makeArtifactForFile(
        path: String,
        url: URL,
        fileManager: FileManager
    ) throws -> StoreBackupArtifact {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let digest = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
        return StoreBackupArtifact(path: path, byteCount: byteCount, sha256: digest)
    }

    private static func writeRestoreJournal(
        _ journal: StoreRestoreJournal,
        to directory: URL,
        fileManager: FileManager
    ) throws {
        let data = try JSONEncoder().encode(journal)
        try data.write(to: directory.appendingPathComponent("restore-journal.json"), options: .atomic)
    }

    private static func loadRestoreJournal(
        at directory: URL,
        fileManager: FileManager
    ) throws -> StoreRestoreJournal? {
        let url = directory.appendingPathComponent("restore-journal.json")
        guard !isSymbolicLink(at: url) else {
            throw BackupError.invalidBackup(directory)
        }
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        guard isRegularFile(at: url) else {
            throw BackupError.invalidBackup(directory)
        }
        return try JSONDecoder().decode(StoreRestoreJournal.self, from: Data(contentsOf: url))
    }

    private static func isValidRestoreQuarantine(
        at quarantineDirectory: URL,
        journal: StoreRestoreJournal,
        fileManager: FileManager,
        requireComplete: Bool
    ) -> Bool {
        guard isRealDirectory(at: quarantineDirectory),
              isSafeFileTree(at: quarantineDirectory, fileManager: fileManager) else {
            return false
        }
        let entries = (try? fileManager.contentsOfDirectory(at: quarantineDirectory, includingPropertiesForKeys: nil)) ?? []
        let entryNames = Set(entries.map(\.lastPathComponent))
        let journalNames = Set(journal.artifacts.map(\.path))
        guard entryNames.isSubset(of: journalNames),
              !requireComplete || entryNames == journalNames else {
            return false
        }
        return journal.artifacts.filter { entryNames.contains($0.path) }.allSatisfy { artifact in
            let url = quarantineDirectory.appendingPathComponent(artifact.path)
            if artifact.sha256 == "directory" {
                return isRealDirectory(at: url) && isSafeFileTree(at: url, fileManager: fileManager)
            }
            guard isRegularFile(at: url),
                  let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                  let byteCount = (attributes[.size] as? NSNumber)?.int64Value,
                  byteCount == artifact.byteCount,
                  let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
                return false
            }
            let digest = SHA256.hash(data: data)
                .map { String(format: "%02x", $0) }
                .joined()
            return digest == artifact.sha256
        }
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

    private static func excludeFromBackup(at url: URL, fileManager: FileManager) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }

    private static func removeIfPresent(_ url: URL, fileManager: FileManager) throws {
        guard fileManager.fileExists(atPath: url.path) || isSymbolicLink(at: url) else { return }
        try fileManager.removeItem(at: url)
    }

    private static func cleanupStagingDirectories(
        in backupDirectory: URL,
        fileManager: FileManager
    ) throws {
        guard fileManager.fileExists(atPath: backupDirectory.path) else { return }
        guard !isSymbolicLink(at: backupDirectory), isRealDirectory(at: backupDirectory) else {
            throw BackupError.invalidBackup(backupDirectory)
        }
        let entries = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil)
        for entry in entries where entry.lastPathComponent.hasPrefix("staging-") {
            try removeIfPresent(entry, fileManager: fileManager)
        }
    }

    private static func loadMigrationAttempt(
        at applicationSupportURL: URL,
        fileManager: FileManager
    ) throws -> StoreMigrationAttempt? {
        let url = applicationSupportURL.appendingPathComponent(migrationAttemptFileName)
        guard !isSymbolicLink(at: url) else {
            throw BackupError.invalidBackup(url)
        }
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        guard isRegularFile(at: url) else {
            throw BackupError.invalidBackup(url)
        }
        return try JSONDecoder().decode(StoreMigrationAttempt.self, from: Data(contentsOf: url))
    }

    private static func writeMigrationAttempt(
        _ attempt: StoreMigrationAttempt,
        to applicationSupportURL: URL,
        fileManager: FileManager
    ) throws {
        try fileManager.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(attempt)
        try data.write(
            to: applicationSupportURL.appendingPathComponent(migrationAttemptFileName),
            options: .atomic
        )
    }

    private static func clearMigrationAttempt(
        at applicationSupportURL: URL,
        fileManager: FileManager
    ) throws {
        try removeIfPresent(
            applicationSupportURL.appendingPathComponent(migrationAttemptFileName),
            fileManager: fileManager
        )
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
