import XCTest
@testable import SeenAt

final class StoreBackupServiceTests: XCTestCase {
    private var rootURL: URL!
    private var storeURL: URL!
    private var supportURL: URL!
    private var applicationSupportURL: URL!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("backup-\(UUID().uuidString)", isDirectory: true)
        storeURL = rootURL.appendingPathComponent("default.store")
        supportURL = rootURL.appendingPathComponent("default_SUPPORT", isDirectory: true)
        applicationSupportURL = rootURL.appendingPathComponent("ApplicationSupport", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func testBackupIncludesStoreSidecarsAndExternalStorage() throws {
        try write("store", to: storeURL)
        try write("wal", to: storeURL.deletingPathExtension().appendingPathExtension("store-wal"))
        try write("shm", to: storeURL.deletingPathExtension().appendingPathExtension("store-shm"))
        try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        try write(
            "photo",
            to: supportURL.appendingPathComponent("_EXTERNAL_DATA/photo.bin")
        )

        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )

        let current = applicationSupportURL
            .appendingPathComponent(StoreBackupService.backupDirectoryName)
            .appendingPathComponent("current")
        let manifest = try XCTUnwrap(try StoreBackupService.loadManifest(at: current))

        XCTAssertEqual(manifest.targetSchemaVersion, "2.0.0")
        XCTAssertEqual(manifest.storeFileName, "default.store")
        XCTAssertTrue(FileManager.default.fileExists(atPath: current.appendingPathComponent("store/default.store").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: current.appendingPathComponent("store/default.store-wal").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: current.appendingPathComponent("store/default.store-shm").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: current.appendingPathComponent("support/default_SUPPORT/_EXTERNAL_DATA/photo.bin").path))
    }

    func testSameSchemaRetainsExistingBackup() throws {
        try write("first", to: storeURL)
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )
        let current = applicationSupportURL
            .appendingPathComponent(StoreBackupService.backupDirectoryName)
            .appendingPathComponent("current")
        let firstManifest = try XCTUnwrap(try StoreBackupService.loadManifest(at: current))

        try write("second", to: storeURL)
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )

        let backedUpData = try Data(contentsOf: current.appendingPathComponent("store/default.store"))
        let secondManifest = try XCTUnwrap(try StoreBackupService.loadManifest(at: current))
        XCTAssertEqual(backedUpData, Data("first".utf8))
        XCTAssertEqual(secondManifest, firstManifest)
    }

    func testNewSchemaReplacesBackup() throws {
        try write("first", to: storeURL)
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )

        try write("second", to: storeURL)
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "3.0.0"
        )

        let current = applicationSupportURL
            .appendingPathComponent(StoreBackupService.backupDirectoryName)
            .appendingPathComponent("current")
        let manifest = try XCTUnwrap(try StoreBackupService.loadManifest(at: current))
        let backedUpData = try Data(contentsOf: current.appendingPathComponent("store/default.store"))
        XCTAssertEqual(manifest.targetSchemaVersion, "3.0.0")
        XCTAssertEqual(backedUpData, Data("second".utf8))
    }

    func testSchemaStateIsPersistedAtomically() throws {
        try StoreBackupService.markMigrationSucceeded(
            applicationSupportURL: applicationSupportURL,
            schemaVersion: "2.0.0"
        )

        let state = try XCTUnwrap(try StoreBackupService.loadSchemaState(at: applicationSupportURL))
        XCTAssertEqual(state.schemaVersion, "2.0.0")
    }

    func testSuccessfulSchemaStateSkipsRedundantBackup() throws {
        try write("first", to: storeURL)
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )
        try StoreBackupService.markMigrationSucceeded(
            applicationSupportURL: applicationSupportURL,
            schemaVersion: "2.0.0"
        )

        try write("second", to: storeURL)
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )

        let current = applicationSupportURL
            .appendingPathComponent(StoreBackupService.backupDirectoryName)
            .appendingPathComponent("current")
        let backedUpData = try Data(contentsOf: current.appendingPathComponent("store/default.store"))
        XCTAssertEqual(backedUpData, Data("first".utf8))
    }

    func testRestoreReplacesStoreAndSupportArtifacts() throws {
        try write("original", to: storeURL)
        try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        try write("photo", to: supportURL.appendingPathComponent("_EXTERNAL_DATA/photo.bin"))
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )

        try write("changed", to: storeURL)
        try write("changed-photo", to: supportURL.appendingPathComponent("_EXTERNAL_DATA/photo.bin"))
        try StoreBackupService.restoreCurrentBackup(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            expectedSchemaVersion: "2.0.0"
        )

        XCTAssertEqual(try Data(contentsOf: storeURL), Data("original".utf8))
        XCTAssertEqual(
            try Data(contentsOf: supportURL.appendingPathComponent("_EXTERNAL_DATA/photo.bin")),
            Data("photo".utf8)
        )
    }

    func testBackupRejectsSymlinkedSupportDirectory() throws {
        try write("store", to: storeURL)
        let targetURL = rootURL.appendingPathComponent("external-support", isDirectory: true)
        try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: supportURL, withDestinationURL: targetURL)

        XCTAssertThrowsError(
            try StoreBackupService.prepareForMigration(
                storeURL: storeURL,
                applicationSupportURL: applicationSupportURL,
                targetSchemaVersion: "2.0.0"
            )
        )
    }

    func testBackupRejectsDanglingSymlinkedSupportDirectory() throws {
        try write("store", to: storeURL)
        let missingTargetURL = rootURL.appendingPathComponent("missing-support", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: supportURL, withDestinationURL: missingTargetURL)

        XCTAssertThrowsError(
            try StoreBackupService.prepareForMigration(
                storeURL: storeURL,
                applicationSupportURL: applicationSupportURL,
                targetSchemaVersion: "2.0.0"
            )
        )
    }

    func testBackupRejectsSymlinkedCurrentDirectory() throws {
        try write("store", to: storeURL)
        let backupDirectory = applicationSupportURL.appendingPathComponent(StoreBackupService.backupDirectoryName, isDirectory: true)
        let targetURL = rootURL.appendingPathComponent("external-backup", isDirectory: true)
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: backupDirectory.appendingPathComponent("current", isDirectory: true),
            withDestinationURL: targetURL
        )

        XCTAssertThrowsError(
            try StoreBackupService.prepareForMigration(
                storeURL: storeURL,
                applicationSupportURL: applicationSupportURL,
                targetSchemaVersion: "2.0.0"
            )
        )
    }

    func testRestoreRejectsSymlinkedManifest() throws {
        try write("store", to: storeURL)
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )
        let current = applicationSupportURL
            .appendingPathComponent(StoreBackupService.backupDirectoryName)
            .appendingPathComponent("current")
        let manifestURL = current.appendingPathComponent("manifest.json")
        let targetURL = rootURL.appendingPathComponent("external-manifest.json")
        try write("{}", to: targetURL)
        try FileManager.default.removeItem(at: manifestURL)
        try FileManager.default.createSymbolicLink(at: manifestURL, withDestinationURL: targetURL)

        XCTAssertThrowsError(
            try StoreBackupService.restoreCurrentBackup(
                storeURL: storeURL,
                applicationSupportURL: applicationSupportURL,
                expectedSchemaVersion: "2.0.0"
            )
        )
    }

    func testRestoreRejectsUnexpectedBackupSymlink() throws {
        try write("store", to: storeURL)
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )
        let current = applicationSupportURL
            .appendingPathComponent(StoreBackupService.backupDirectoryName)
            .appendingPathComponent("current")
        let targetURL = rootURL.appendingPathComponent("external-backup-file")
        try write("external", to: targetURL)
        try FileManager.default.createSymbolicLink(
            at: current.appendingPathComponent("unexpected", isDirectory: true),
            withDestinationURL: targetURL
        )

        XCTAssertThrowsError(
            try StoreBackupService.restoreCurrentBackup(
                storeURL: storeURL,
                applicationSupportURL: applicationSupportURL,
                expectedSchemaVersion: "2.0.0"
            )
        )
    }

    func testRestoreRejectsSymlinkedBackupDirectory() throws {
        try write("store", to: storeURL)
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )
        let backupDirectory = applicationSupportURL.appendingPathComponent(StoreBackupService.backupDirectoryName, isDirectory: true)
        let targetURL = rootURL.appendingPathComponent("external-backup-directory", isDirectory: true)
        try FileManager.default.copyItem(at: backupDirectory, to: targetURL)
        try FileManager.default.removeItem(at: backupDirectory)
        try FileManager.default.createSymbolicLink(at: backupDirectory, withDestinationURL: targetURL)

        XCTAssertThrowsError(
            try StoreBackupService.restoreCurrentBackup(
                storeURL: storeURL,
                applicationSupportURL: applicationSupportURL,
                expectedSchemaVersion: "2.0.0"
            )
        )
    }

    func testInterruptedRestoreRejectsSymlinkedQuarantineDirectory() throws {
        try write("store", to: storeURL)
        let restoreDirectory = applicationSupportURL.appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
        let targetURL = rootURL.appendingPathComponent("external-quarantine", isDirectory: true)
        try FileManager.default.createDirectory(at: restoreDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: restoreDirectory.appendingPathComponent("quarantine", isDirectory: true),
            withDestinationURL: targetURL
        )

        XCTAssertThrowsError(
            try StoreBackupService.prepareForMigration(
                storeURL: storeURL,
                applicationSupportURL: applicationSupportURL,
                targetSchemaVersion: "2.0.0"
            )
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetURL.path))
    }

    func testInterruptedRestoreRejectsSymlinkedReplacedDirectory() throws {
        try write("store", to: storeURL)
        let restoreDirectory = applicationSupportURL.appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
        let quarantineDirectory = restoreDirectory.appendingPathComponent("quarantine", isDirectory: true)
        let replacedTargetURL = rootURL.appendingPathComponent("external-replaced", isDirectory: true)
        try FileManager.default.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: storeURL,
            to: quarantineDirectory.appendingPathComponent(storeURL.lastPathComponent)
        )
        try FileManager.default.createDirectory(at: replacedTargetURL, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: restoreDirectory.appendingPathComponent("replaced", isDirectory: true),
            withDestinationURL: replacedTargetURL
        )

        XCTAssertThrowsError(
            try StoreBackupService.prepareForMigration(
                storeURL: storeURL,
                applicationSupportURL: applicationSupportURL,
                targetSchemaVersion: "2.0.0"
            )
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: replacedTargetURL.path))
    }

    func testInterruptedRestoreRejectsDirectoryStoreArtifact() throws {
        try write("store", to: storeURL)
        let restoreDirectory = applicationSupportURL.appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
        let quarantineDirectory = restoreDirectory.appendingPathComponent("quarantine", isDirectory: true)
        try FileManager.default.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: quarantineDirectory.appendingPathComponent(storeURL.lastPathComponent, isDirectory: true),
            withIntermediateDirectories: true
        )

        XCTAssertThrowsError(
            try StoreBackupService.prepareForMigration(
                storeURL: storeURL,
                applicationSupportURL: applicationSupportURL,
                targetSchemaVersion: "2.0.0"
            )
        )
    }

    func testInterruptedRestoreRejectsSymlinkInsideSupportArtifact() throws {
        try write("store", to: storeURL)
        let restoreDirectory = applicationSupportURL.appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
        let quarantineDirectory = restoreDirectory.appendingPathComponent("quarantine", isDirectory: true)
        let supportArtifact = quarantineDirectory.appendingPathComponent("default_SUPPORT", isDirectory: true)
        let targetURL = rootURL.appendingPathComponent("external-support-file")
        try FileManager.default.createDirectory(at: supportArtifact, withIntermediateDirectories: true)
        try write("external", to: targetURL)
        try FileManager.default.createSymbolicLink(
            at: supportArtifact.appendingPathComponent("photo.bin"),
            withDestinationURL: targetURL
        )

        XCTAssertThrowsError(
            try StoreBackupService.prepareForMigration(
                storeURL: storeURL,
                applicationSupportURL: applicationSupportURL,
                targetSchemaVersion: "2.0.0"
            )
        )
    }

    private func write(_ value: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(value.utf8).write(to: url)
    }
}
