import XCTest
@testable import SeenAt
import SwiftData
import CryptoKit

final class StoreBackupServiceTests: XCTestCase {
    private var rootURL: URL!
    private var storeURL: URL!
    private var supportURL: URL!
    private var applicationSupportURL: URL!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("backup-\(UUID().uuidString)", isDirectory: true)
        storeURL = rootURL.appendingPathComponent("default.store")
        supportURL = rootURL.appendingPathComponent(".default_SUPPORT", isDirectory: true)
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
        XCTAssertTrue(FileManager.default.fileExists(atPath: current.appendingPathComponent("support/.default_SUPPORT/_EXTERNAL_DATA/photo.bin").path))
    }

    @MainActor
    func testBackupCapturesRealSwiftDataStore() throws {
        let configuration = ModelConfiguration(url: storeURL)
        let container = try ModelContainer(
            for: Team.self, Event.self, JerseySighting.self,
            configurations: configuration
        )
        let event = Event(title: "Yankees @ Red Sox", date: .now)
        container.mainContext.insert(event)
        try container.mainContext.save()

        let backupID = try XCTUnwrap(try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        ))
        let current = applicationSupportURL
            .appendingPathComponent(StoreBackupService.backupDirectoryName)
            .appendingPathComponent("current")
        let manifest = try XCTUnwrap(try StoreBackupService.loadManifest(at: current))

        XCTAssertEqual(manifest.backupID, backupID)
        XCTAssertTrue(FileManager.default.fileExists(atPath: current.appendingPathComponent("store/default.store").path))
    }

    func testSameSchemaRetainsExistingBackup() throws {
        try write("first", to: storeURL)
        let firstBackupID = try XCTUnwrap(try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        ))
        try StoreBackupService.completeMigrationAttempt(applicationSupportURL: applicationSupportURL)
        let current = applicationSupportURL
            .appendingPathComponent(StoreBackupService.backupDirectoryName)
            .appendingPathComponent("current")
        let firstManifest = try XCTUnwrap(try StoreBackupService.loadManifest(at: current))

        try write("second", to: storeURL)
        let secondBackupID = try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )

        let backedUpData = try Data(contentsOf: current.appendingPathComponent("store/default.store"))
        let secondManifest = try XCTUnwrap(try StoreBackupService.loadManifest(at: current))
        XCTAssertEqual(backedUpData, Data("first".utf8))
        XCTAssertEqual(secondManifest, firstManifest)
        XCTAssertNil(secondBackupID)
        XCTAssertEqual(firstBackupID, firstManifest.backupID)
    }

    func testNewSchemaReplacesBackup() throws {
        try write("first", to: storeURL)
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )
        try StoreBackupService.completeMigrationAttempt(applicationSupportURL: applicationSupportURL)

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

    func testSameSchemaRetainsExistingBackupAfterSuccessfulOpen() throws {
        try write("first", to: storeURL)
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )
        try StoreBackupService.completeMigrationAttempt(applicationSupportURL: applicationSupportURL)
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

    func testActiveAttemptResumesSameBackupID() throws {
        try write("first", to: storeURL)
        let backupID = try XCTUnwrap(try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        ))

        let resumedID = try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )

        XCTAssertEqual(resumedID, backupID)
    }

    func testStagingPromotionResumesAttemptAfterCurrentWasNotPublished() throws {
        try write("first", to: storeURL)
        let backupID = try XCTUnwrap(try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        ))
        let backupDirectory = applicationSupportURL.appendingPathComponent(StoreBackupService.backupDirectoryName, isDirectory: true)
        let current = backupDirectory.appendingPathComponent("current", isDirectory: true)
        let staging = backupDirectory.appendingPathComponent("staging-retry", isDirectory: true)
        try FileManager.default.copyItem(at: current, to: staging)
        try FileManager.default.removeItem(at: current)
        try writeMigrationAttempt(
            StoreMigrationAttempt(
                backupID: backupID,
                sourceStorePath: storeURL.path,
                targetSchemaVersion: "2.0.0",
                stagingDirectoryPath: staging.path
            )
        )

        let resumedID = try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )

        XCTAssertEqual(resumedID, backupID)
        XCTAssertTrue(FileManager.default.fileExists(atPath: current.path))
    }

    func testTargetMismatchRestoresOldAttemptThenCreatesFreshBackup() throws {
        try write("original", to: storeURL)
        let oldID = try XCTUnwrap(try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        ))
        try write("failed migration", to: storeURL)

        let newID = try XCTUnwrap(try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "3.0.0"
        ))
        let current = applicationSupportURL
            .appendingPathComponent(StoreBackupService.backupDirectoryName)
            .appendingPathComponent("current")
        let manifest = try XCTUnwrap(try StoreBackupService.loadManifest(at: current))

        XCTAssertNotEqual(newID, oldID)
        XCTAssertEqual(manifest.targetSchemaVersion, "3.0.0")
        XCTAssertEqual(try Data(contentsOf: current.appendingPathComponent("store/default.store")), Data("original".utf8))
    }

    func testSourceMismatchClearsStaleAttemptWithoutRestoringIt() throws {
        try write("current", to: storeURL)
        let backupID = try XCTUnwrap(try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        ))
        try writeMigrationAttempt(
            StoreMigrationAttempt(
                backupID: backupID,
                sourceStorePath: rootURL.appendingPathComponent("other.store").path,
                targetSchemaVersion: "2.0.0",
                stagingDirectoryPath: nil
            )
        )

        XCTAssertNil(try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        ))
        XCTAssertEqual(try Data(contentsOf: storeURL), Data("current".utf8))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: applicationSupportURL.appendingPathComponent(StoreBackupService.migrationAttemptFileName).path
        ))
    }

    func testRestoreInstallsBackupWhenStoreIsMissing() throws {
        try write("original", to: storeURL)
        let backupID = try XCTUnwrap(try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        ))
        try FileManager.default.removeItem(at: storeURL)

        try StoreBackupService.restoreCurrentBackup(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            expectedSchemaVersion: "2.0.0",
            backupID: backupID
        )

        XCTAssertEqual(try Data(contentsOf: storeURL), Data("original".utf8))
    }

    func testActiveAttemptRestoresMissingStoreBeforeReturning() throws {
        try write("original", to: storeURL)
        let backupID = try XCTUnwrap(try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        ))
        try FileManager.default.removeItem(at: storeURL)

        let resumedID = try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )

        XCTAssertEqual(resumedID, backupID)
        XCTAssertEqual(try Data(contentsOf: storeURL), Data("original".utf8))
    }

    func testRestoreReplacesStoreAndSupportArtifacts() throws {
        try write("original", to: storeURL)
        try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        try write("photo", to: supportURL.appendingPathComponent("_EXTERNAL_DATA/photo.bin"))
        let backupID = try XCTUnwrap(try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        ))

        try write("changed", to: storeURL)
        try write("changed-photo", to: supportURL.appendingPathComponent("_EXTERNAL_DATA/photo.bin"))
        try StoreBackupService.restoreCurrentBackup(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            expectedSchemaVersion: "2.0.0",
            backupID: backupID
        )

        XCTAssertEqual(try Data(contentsOf: storeURL), Data("original".utf8))
        XCTAssertEqual(
            try Data(contentsOf: supportURL.appendingPathComponent("_EXTERNAL_DATA/photo.bin")),
            Data("photo".utf8)
        )
        let failedStoreDirectories = try FileManager.default.contentsOfDirectory(
            at: applicationSupportURL,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix(StoreBackupService.failedStoreDirectoryPrefix) }
        XCTAssertEqual(failedStoreDirectories.count, 1)
        XCTAssertEqual(
            try Data(contentsOf: failedStoreDirectories[0].appendingPathComponent("default.store")),
            Data("changed".utf8)
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
                expectedSchemaVersion: "2.0.0",
                backupID: UUID()
            )
        )
    }

    func testRestoreRejectsUnexpectedBackupSymlink() throws {
        try write("store", to: storeURL)
        let backupID = try XCTUnwrap(try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        ))
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
                expectedSchemaVersion: "2.0.0",
                backupID: backupID
            )
        )
    }

    func testRestoreRequiresFreshBackupID() throws {
        try write("original", to: storeURL)
        _ = try XCTUnwrap(try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        ))
        try write("changed", to: storeURL)

        XCTAssertThrowsError(
            try StoreBackupService.restoreCurrentBackup(
                storeURL: storeURL,
                applicationSupportURL: applicationSupportURL,
                expectedSchemaVersion: "2.0.0",
                backupID: UUID()
            )
        )
        XCTAssertEqual(try Data(contentsOf: storeURL), Data("changed".utf8))
    }

    func testRestoreRejectsTamperedBackup() throws {
        try write("original", to: storeURL)
        let backupID = try XCTUnwrap(try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        ))
        let currentStore = applicationSupportURL
            .appendingPathComponent(StoreBackupService.backupDirectoryName)
            .appendingPathComponent("current/store/default.store")
        try write("tampered", to: currentStore)

        XCTAssertThrowsError(
            try StoreBackupService.restoreCurrentBackup(
                storeURL: storeURL,
                applicationSupportURL: applicationSupportURL,
                expectedSchemaVersion: "2.0.0",
                backupID: backupID
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
                expectedSchemaVersion: "2.0.0",
                backupID: UUID()
            )
        )
    }

    func testInterruptedRestoreQuarantinesSymlinkedQuarantineDirectory() throws {
        try write("store", to: storeURL)
        let (_, quarantineDirectory, _) = try makeValidInterruptedRestore()
        let targetURL = rootURL.appendingPathComponent("external-quarantine", isDirectory: true)
        try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
        try FileManager.default.removeItem(at: quarantineDirectory)
        try FileManager.default.createSymbolicLink(
            at: quarantineDirectory,
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
        XCTAssertTrue(try recoveryQuarantineExists())
    }

    func testInterruptedRestoreQuarantinesSymlinkedReplacedDirectory() throws {
        try write("store", to: storeURL)
        let (restoreDirectory, _, _) = try makeValidInterruptedRestore()
        let replacedTargetURL = rootURL.appendingPathComponent("external-replaced", isDirectory: true)
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
        XCTAssertTrue(try recoveryQuarantineExists())
    }

    func testInterruptedRestoreQuarantinesDirectoryStoreArtifact() throws {
        try write("store", to: storeURL)
        let (_, quarantineDirectory, _) = try makeValidInterruptedRestore()
        try FileManager.default.removeItem(at: quarantineDirectory.appendingPathComponent(storeURL.lastPathComponent))
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
        XCTAssertTrue(try recoveryQuarantineExists())
    }

    func testInterruptedRestoreQuarantinesSymlinkInsideSupportArtifact() throws {
        try write("store", to: storeURL)
        try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        try write("external", to: supportURL.appendingPathComponent("photo.bin"))
        let (_, quarantineDirectory, _) = try makeValidInterruptedRestore()
        let supportArtifact = quarantineDirectory.appendingPathComponent(".default_SUPPORT", isDirectory: true)
        let targetURL = rootURL.appendingPathComponent("external-support-file")
        try write("external", to: targetURL)
        try FileManager.default.removeItem(at: supportArtifact)
        try FileManager.default.createDirectory(at: supportArtifact, withIntermediateDirectories: true)
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
        XCTAssertTrue(try recoveryQuarantineExists())
    }

    func testExistingRecoveryQuarantineBlocksMigrationResume() throws {
        try write("store", to: storeURL)
        let quarantine = applicationSupportURL
            .appendingPathComponent("recovery-quarantine-existing", isDirectory: true)
        try FileManager.default.createDirectory(at: quarantine, withIntermediateDirectories: true)

        XCTAssertThrowsError(
            try StoreBackupService.prepareForMigration(
                storeURL: storeURL,
                applicationSupportURL: applicationSupportURL,
                targetSchemaVersion: "2.0.0"
            )
        ) { error in
            guard case StoreBackupService.BackupError.recoveryRequired = error else {
                return XCTFail("Expected recoveryRequired, got \(error)")
            }
        }
    }

    func testActiveAttemptRejectsSupportDirectorySymlink() throws {
        try write("store", to: storeURL)
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )
        let externalSupport = rootURL.appendingPathComponent("external-support", isDirectory: true)
        try FileManager.default.createDirectory(at: externalSupport, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: supportURL, withDestinationURL: externalSupport)

        XCTAssertThrowsError(
            try StoreBackupService.prepareForMigration(
                storeURL: storeURL,
                applicationSupportURL: applicationSupportURL,
                targetSchemaVersion: "2.0.0"
            )
        )
    }

    func testInterruptedRestoreRecoversQuarantine() throws {
        try write("live", to: storeURL)
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )
        let current = applicationSupportURL
            .appendingPathComponent(StoreBackupService.backupDirectoryName)
            .appendingPathComponent("current")
        let restoreDirectory = applicationSupportURL.appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
        let quarantineDirectory = restoreDirectory.appendingPathComponent("quarantine", isDirectory: true)
        try FileManager.default.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: current.appendingPathComponent("manifest.json"),
            to: restoreDirectory.appendingPathComponent("manifest.json")
        )
        try FileManager.default.copyItem(
            at: current.appendingPathComponent("store"),
            to: restoreDirectory.appendingPathComponent("store", isDirectory: true)
        )
        try write("live", to: quarantineDirectory.appendingPathComponent(storeURL.lastPathComponent))
        let digest = SHA256.hash(data: Data("live".utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let manifest = try XCTUnwrap(try StoreBackupService.loadManifest(at: current))
        let journal = StoreRestoreJournal(
            backupID: manifest.backupID,
            phase: .quarantining,
            artifacts: [StoreBackupArtifact(
                path: storeURL.lastPathComponent,
                byteCount: 4,
                sha256: digest
            )]
        )
        try JSONEncoder().encode(journal).write(
            to: restoreDirectory.appendingPathComponent("restore-journal.json")
        )

        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )

        XCTAssertEqual(try Data(contentsOf: storeURL), Data("live".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: restoreDirectory.path))
    }

    func testInterruptedRestoreRecoversPartialQuarantine() throws {
        let walURL = storeURL.deletingPathExtension().appendingPathExtension("store-wal")
        try write("live", to: storeURL)
        try write("wal", to: walURL)
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )

        let current = applicationSupportURL
            .appendingPathComponent(StoreBackupService.backupDirectoryName)
            .appendingPathComponent("current")
        let restoreDirectory = applicationSupportURL.appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
        let quarantineDirectory = restoreDirectory.appendingPathComponent("quarantine", isDirectory: true)
        try FileManager.default.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: current.appendingPathComponent("manifest.json"),
            to: restoreDirectory.appendingPathComponent("manifest.json")
        )
        try FileManager.default.copyItem(
            at: current.appendingPathComponent("store"),
            to: restoreDirectory.appendingPathComponent("store", isDirectory: true)
        )

        let storeDigest = SHA256.hash(data: Data("live".utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let walDigest = SHA256.hash(data: Data("wal".utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let manifest = try XCTUnwrap(try StoreBackupService.loadManifest(at: current))
        let journal = StoreRestoreJournal(
            backupID: manifest.backupID,
            phase: .quarantining,
            artifacts: [
                StoreBackupArtifact(path: storeURL.lastPathComponent, byteCount: 4, sha256: storeDigest),
                StoreBackupArtifact(path: walURL.lastPathComponent, byteCount: 3, sha256: walDigest)
            ]
        )
        try JSONEncoder().encode(journal).write(
            to: restoreDirectory.appendingPathComponent("restore-journal.json")
        )
        try FileManager.default.moveItem(
            at: storeURL,
            to: quarantineDirectory.appendingPathComponent(storeURL.lastPathComponent)
        )

        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )

        XCTAssertEqual(try Data(contentsOf: storeURL), Data("live".utf8))
        XCTAssertEqual(try Data(contentsOf: walURL), Data("wal".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: restoreDirectory.path))
    }

    func testInstallingRecoveryRemovesBackupArtifactsAbsentBeforeRestore() throws {
        try write("live", to: storeURL)
        try write("wal", to: storeURL.deletingPathExtension().appendingPathExtension("store-wal"))
        try write("shm", to: storeURL.deletingPathExtension().appendingPathExtension("store-shm"))
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )

        let current = applicationSupportURL
            .appendingPathComponent(StoreBackupService.backupDirectoryName)
            .appendingPathComponent("current")
        let restoreDirectory = applicationSupportURL.appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
        let quarantineDirectory = restoreDirectory.appendingPathComponent("quarantine", isDirectory: true)
        try FileManager.default.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: current.appendingPathComponent("manifest.json"),
            to: restoreDirectory.appendingPathComponent("manifest.json")
        )
        try FileManager.default.copyItem(
            at: current.appendingPathComponent("store"),
            to: restoreDirectory.appendingPathComponent("store", isDirectory: true)
        )
        try write("live", to: quarantineDirectory.appendingPathComponent(storeURL.lastPathComponent))
        let digest = SHA256.hash(data: Data("live".utf8)).map { String(format: "%02x", $0) }.joined()
        let manifest = try XCTUnwrap(try StoreBackupService.loadManifest(at: current))
        let journal = StoreRestoreJournal(
            backupID: manifest.backupID,
            phase: .installing,
            artifacts: [StoreBackupArtifact(
                path: storeURL.lastPathComponent,
                byteCount: 4,
                sha256: digest
            )]
        )
        try JSONEncoder().encode(journal).write(
            to: restoreDirectory.appendingPathComponent("restore-journal.json")
        )
        for name in ["default.store", "default.store-wal", "default.store-shm"] {
            let installedSource = current.appendingPathComponent("store").appendingPathComponent(name)
            try FileManager.default.removeItem(
                at: storeURL.deletingLastPathComponent().appendingPathComponent(name)
            )
            try FileManager.default.copyItem(
                at: installedSource,
                to: storeURL.deletingLastPathComponent().appendingPathComponent(name)
            )
        }

        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )

        XCTAssertEqual(try Data(contentsOf: storeURL), Data("live".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.deletingPathExtension().appendingPathExtension("store-wal").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.deletingPathExtension().appendingPathExtension("store-shm").path))
    }

    func testResetStoreDataRemovesAllPhysicalArtifacts() throws {
        try write("store", to: storeURL)
        try write("wal", to: storeURL.deletingPathExtension().appendingPathExtension("store-wal"))
        try write("shm", to: storeURL.deletingPathExtension().appendingPathExtension("store-shm"))
        try write("photo", to: supportURL.appendingPathComponent("_EXTERNAL_DATA/photo.bin"))
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )
        let restoreDirectory = applicationSupportURL.appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: restoreDirectory, withIntermediateDirectories: true)
        try Data("legacy".utf8).write(
            to: applicationSupportURL.appendingPathComponent(StoreBackupService.legacySchemaStateFileName)
        )

        try StoreBackupService.resetStoreData(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: supportURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: applicationSupportURL.appendingPathComponent(StoreBackupService.backupDirectoryName).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: restoreDirectory.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: applicationSupportURL.appendingPathComponent(StoreBackupService.legacySchemaStateFileName).path))
    }

    func testJournalLessRestoreDirectoryIsCleanedUp() throws {
        try write("store", to: storeURL)
        let restoreDirectory = applicationSupportURL.appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
        let quarantineDirectory = restoreDirectory.appendingPathComponent("quarantine", isDirectory: true)
        try FileManager.default.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true)
        try write("data", to: quarantineDirectory.appendingPathComponent(storeURL.lastPathComponent))
        try write("{}", to: restoreDirectory.appendingPathComponent("manifest.json"))

        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: restoreDirectory.path))
        XCTAssertEqual(try Data(contentsOf: storeURL), Data("store".utf8))
    }

    func testInstalledPhaseRecoveryMovesQuarantineToFailedStoreDirectory() throws {
        try write("original", to: storeURL)
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )
        let current = applicationSupportURL
            .appendingPathComponent(StoreBackupService.backupDirectoryName)
            .appendingPathComponent("current")
        let restoreDirectory = applicationSupportURL.appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
        let quarantineDirectory = restoreDirectory.appendingPathComponent("quarantine", isDirectory: true)
        try FileManager.default.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: current.appendingPathComponent("manifest.json"),
            to: restoreDirectory.appendingPathComponent("manifest.json")
        )
        try FileManager.default.copyItem(
            at: current.appendingPathComponent("store"),
            to: restoreDirectory.appendingPathComponent("store", isDirectory: true)
        )
        try write("installed-data", to: quarantineDirectory.appendingPathComponent(storeURL.lastPathComponent))
        let digest = SHA256.hash(data: Data("installed-data".utf8)).map { String(format: "%02x", $0) }.joined()
        let manifest = try XCTUnwrap(try StoreBackupService.loadManifest(at: current))
        let journal = StoreRestoreJournal(
            backupID: manifest.backupID,
            phase: .installed,
            artifacts: [StoreBackupArtifact(
                path: storeURL.lastPathComponent,
                byteCount: 14,
                sha256: digest
            )]
        )
        try JSONEncoder().encode(journal).write(
            to: restoreDirectory.appendingPathComponent("restore-journal.json")
        )

        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: restoreDirectory.path))
        let failedStores = try FileManager.default.contentsOfDirectory(
            at: applicationSupportURL,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix(StoreBackupService.failedStoreDirectoryPrefix) }
        XCTAssertEqual(failedStores.count, 1)
        XCTAssertEqual(
            try Data(contentsOf: failedStores[0].appendingPathComponent(storeURL.lastPathComponent)),
            Data("installed-data".utf8)
        )
    }

    func testRestoreDirectoryWithoutQuarantineIsCleanedUp() throws {
        try write("store", to: storeURL)
        let restoreDirectory = applicationSupportURL.appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: restoreDirectory, withIntermediateDirectories: true)
        let manifest = StoreBackupManifest(
            backupID: UUID(),
            sourceStorePath: storeURL.path,
            storeFileName: storeURL.lastPathComponent,
            targetSchemaVersion: "2.0.0",
            createdAt: .now,
            artifacts: []
        )
        try JSONEncoder().encode(manifest).write(
            to: restoreDirectory.appendingPathComponent("manifest.json")
        )

        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: restoreDirectory.path))
    }

    func testCompleteMigrationAttemptClearsMigrationAttemptFile() throws {
        try write("original", to: storeURL)
        _ = try XCTUnwrap(try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        ))
        try StoreBackupService.completeMigrationAttempt(
            applicationSupportURL: applicationSupportURL
        )

        // Simulate a second migration that will fail (e.g., ModelContainer creation fails).
        // A new migration attempt file is written before the failure.
        try writeMigrationAttempt(
            StoreMigrationAttempt(
                backupID: UUID(),
                sourceStorePath: storeURL.path,
                targetSchemaVersion: "2.0.0",
                stagingDirectoryPath: nil
            )
        )
        let attemptFile = applicationSupportURL
            .appendingPathComponent(StoreBackupService.migrationAttemptFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: attemptFile.path))

        // Simulate the recovery-loop fix: clear the migration attempt after
        // restoreCurrentBackup succeeds but ModelContainer creation fails.
        try StoreBackupService.completeMigrationAttempt(
            applicationSupportURL: applicationSupportURL
        )

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: attemptFile.path),
            "Migration attempt file must be cleared to prevent infinite recovery loop on next launch"
        )
    }

    private func recoveryQuarantineExists() throws -> Bool {
        guard FileManager.default.fileExists(atPath: applicationSupportURL.path) else { return false }
        return try FileManager.default.contentsOfDirectory(
            at: applicationSupportURL,
            includingPropertiesForKeys: nil
        ).contains { $0.lastPathComponent.hasPrefix("recovery-quarantine-") }
    }

    private func makeValidInterruptedRestore() throws -> (restore: URL, quarantine: URL, manifest: StoreBackupManifest) {
        let storeURL = try XCTUnwrap(storeURL)
        let supportURL = try XCTUnwrap(supportURL)
        let applicationSupportURL = try XCTUnwrap(applicationSupportURL)
        try StoreBackupService.prepareForMigration(
            storeURL: storeURL,
            applicationSupportURL: applicationSupportURL,
            targetSchemaVersion: "2.0.0"
        )
        let current = applicationSupportURL
            .appendingPathComponent(StoreBackupService.backupDirectoryName)
            .appendingPathComponent("current")
        let restore = applicationSupportURL.appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
        let quarantine = restore.appendingPathComponent("quarantine", isDirectory: true)
        try FileManager.default.createDirectory(at: quarantine, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: current.appendingPathComponent("manifest.json"),
            to: restore.appendingPathComponent("manifest.json")
        )
        try FileManager.default.copyItem(
            at: current.appendingPathComponent("store"),
            to: restore.appendingPathComponent("store", isDirectory: true)
        )
        if FileManager.default.fileExists(atPath: current.appendingPathComponent("support").path) {
            try FileManager.default.copyItem(
                at: current.appendingPathComponent("support"),
                to: restore.appendingPathComponent("support", isDirectory: true)
            )
        }

        let manifest = try XCTUnwrap(try StoreBackupService.loadManifest(at: current))
        let sidecars = [
            storeURL.deletingPathExtension().appendingPathExtension("store-wal"),
            storeURL.deletingPathExtension().appendingPathExtension("store-shm")
        ]
        var liveURLs = [storeURL]
        liveURLs.append(contentsOf: sidecars.filter { FileManager.default.fileExists(atPath: $0.path) })
        if FileManager.default.fileExists(atPath: supportURL.path) {
            liveURLs.append(supportURL)
        }
        let artifacts = try liveURLs.map { liveURL -> StoreBackupArtifact in
            if liveURL == supportURL {
                return StoreBackupArtifact(path: liveURL.lastPathComponent, byteCount: 0, sha256: "directory")
            }
            let data = try Data(contentsOf: liveURL, options: .mappedIfSafe)
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            return StoreBackupArtifact(path: liveURL.lastPathComponent, byteCount: Int64(data.count), sha256: digest)
        }
        for liveURL in liveURLs {
            try FileManager.default.moveItem(
                at: liveURL,
                to: quarantine.appendingPathComponent(liveURL.lastPathComponent, isDirectory: liveURL == supportURL)
            )
        }
        let journal = StoreRestoreJournal(backupID: manifest.backupID, phase: .quarantining, artifacts: artifacts)
        try JSONEncoder().encode(journal).write(to: restore.appendingPathComponent("restore-journal.json"))
        return (restore, quarantine, manifest)
    }

    private func write(_ value: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(value.utf8).write(to: url)
    }

    private func writeMigrationAttempt(_ attempt: StoreMigrationAttempt) throws {
        try FileManager.default.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(attempt).write(
            to: applicationSupportURL.appendingPathComponent(StoreBackupService.migrationAttemptFileName),
            options: .atomic
        )
    }
}
