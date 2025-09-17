//
//  CloudSyncManager.swift
//  Rideshare Tracker
//
//  Created by George Knaggs with Claude AI assistance on 8/30/25.
//

import Foundation
import UIKit

// MARK: - Storage Protocol

protocol SyncStorageProtocol: Sendable {
    var isAvailable: Bool { get }
    var documentsURL: URL? { get }
    
    func writeData(_ data: Data, to fileName: String) async throws
    func readData(from fileName: String) async throws -> Data?
    func fileExists(_ fileName: String) -> Bool
    func createDirectoryIfNeeded() async throws
    func startDownloadIfNeeded(fileName: String) async throws
    func waitForUpload(fileName: String, timeout: TimeInterval) async throws
    func waitForDownload(fileName: String, timeout: TimeInterval) async throws
}

// MARK: - Storage Implementations

class CloudSyncStorage: SyncStorageProtocol, @unchecked Sendable {
    private let fileManager = FileManager.default
    
    var isAvailable: Bool {
        // Temporarily disabled - iCloud capability not available in development environment
        return false
        // return documentsURL != nil
    }
    
    var documentsURL: URL? {
        fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    }
    
    func writeData(_ data: Data, to fileName: String) async throws {
        guard let url = documentsURL?.appendingPathComponent(fileName) else {
            throw CloudSyncError.iCloudUnavailable
        }
        try data.write(to: url)
    }
    
    func readData(from fileName: String) async throws -> Data? {
        guard let url = documentsURL?.appendingPathComponent(fileName) else {
            throw CloudSyncError.iCloudUnavailable
        }
        
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        
        return try Data(contentsOf: url)
    }
    
    func fileExists(_ fileName: String) -> Bool {
        guard let url = documentsURL?.appendingPathComponent(fileName) else {
            return false
        }
        return fileManager.fileExists(atPath: url.path)
    }
    
    func createDirectoryIfNeeded() async throws {
        guard let url = documentsURL else {
            throw CloudSyncError.iCloudUnavailable
        }
        
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    func startDownloadIfNeeded(fileName: String) async throws {
        guard let url = documentsURL?.appendingPathComponent(fileName) else {
            throw CloudSyncError.iCloudUnavailable
        }
        
        do {
            _ = try fileManager.startDownloadingUbiquitousItem(at: url)
        } catch {
            // If startDownloadingUbiquitousItem fails, the file might not be in iCloud yet
            throw CloudSyncError.downloadFailed
        }
    }
    
    func waitForUpload(fileName: String, timeout: TimeInterval = 30) async throws {
        guard let url = documentsURL?.appendingPathComponent(fileName) else {
            throw CloudSyncError.iCloudUnavailable
        }
        
        // For now, just wait a short time for the file to be written
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        guard fileManager.fileExists(atPath: url.path) else {
            throw CloudSyncError.uploadTimeout
        }
    }
    
    func waitForDownload(fileName: String, timeout: TimeInterval = 30) async throws {
        guard let url = documentsURL?.appendingPathComponent(fileName) else {
            throw CloudSyncError.iCloudUnavailable
        }
        
        try await startDownloadIfNeeded(fileName: fileName)
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        guard fileManager.fileExists(atPath: url.path) else {
            throw CloudSyncError.downloadTimeout
        }
    }
}

class LocalSyncStorage: SyncStorageProtocol, @unchecked Sendable {
    private let fileManager = FileManager.default
    private let testDirectoryName = "RideshareTrackerTestSync"
    
    var isAvailable: Bool {
        return true // Local storage is always available
    }
    
    var documentsURL: URL? {
        let tempDir = fileManager.temporaryDirectory
        return tempDir.appendingPathComponent(testDirectoryName)
    }
    
    func writeData(_ data: Data, to fileName: String) async throws {
        guard let url = documentsURL?.appendingPathComponent(fileName) else {
            throw CloudSyncError.iCloudUnavailable
        }
        try data.write(to: url)
    }
    
    func readData(from fileName: String) async throws -> Data? {
        guard let url = documentsURL?.appendingPathComponent(fileName) else {
            return nil
        }
        
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        
        return try Data(contentsOf: url)
    }
    
    func fileExists(_ fileName: String) -> Bool {
        guard let url = documentsURL?.appendingPathComponent(fileName) else {
            return false
        }
        return fileManager.fileExists(atPath: url.path)
    }
    
    func createDirectoryIfNeeded() async throws {
        guard let url = documentsURL else {
            throw CloudSyncError.iCloudUnavailable
        }
        
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    func startDownloadIfNeeded(fileName: String) async throws {
        // No-op for local storage - files are immediately available
    }
    
    func waitForUpload(fileName: String, timeout: TimeInterval = 30) async throws {
        // No-op for local storage - writes are synchronous
        guard fileExists(fileName) else {
            throw CloudSyncError.uploadTimeout
        }
    }
    
    func waitForDownload(fileName: String, timeout: TimeInterval = 30) async throws {
        // No-op for local storage - files are immediately available
        guard fileExists(fileName) else {
            throw CloudSyncError.downloadTimeout
        }
    }
}

@MainActor
class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()
    
    @Published var isSyncing = false
    @Published var syncError: String?
    
    private var storage: SyncStorageProtocol {
        // Detect test environment more broadly
        let isTestEnvironment = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                                ProcessInfo.processInfo.arguments.contains("-testing") ||
                                NSClassFromString("XCTestCase") != nil ||
                                Bundle.main.bundlePath.contains("xctest")
        
        if isTestEnvironment {
            return LocalSyncStorage()
        } else {
            return CloudSyncStorage()
        }
    }
    
    private let shiftsFileName = "shifts_sync.json"
    private let expensesFileName = "expenses_sync.json"
    private let syncMetadataFileName = "sync_metadata.json"
    
    private init() {}
    
    // MARK: - Sync Status
    
    var isICloudAvailable: Bool {
        return storage.isAvailable
    }
    
    // MARK: - Initial Sync
    
    func performInitialSync(shifts: [RideshareShift], expenses: [ExpenseItem]) async throws {
        guard isICloudAvailable else {
            throw CloudSyncError.iCloudUnavailable
        }
        
        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        
        do {
            // Ensure storage directory exists
            try await storage.createDirectoryIfNeeded()
            
            // Upload all shifts
            try await uploadShifts(shifts)
            
            // Upload all expenses  
            try await uploadExpenses(expenses)
            
            // Create sync metadata
            let metadata = SyncMetadata(
                lastSyncDate: Date(),
                deviceID: await MainActor.run { UIDevice.current.identifierForVendor?.uuidString ?? "unknown" },
                schemaVersion: 1
            )
            try await uploadSyncMetadata(metadata)
            
            await MainActor.run {
                isSyncing = false
            }
            
        } catch {
            await MainActor.run {
                isSyncing = false
                syncError = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - Incremental Sync
    
    func performIncrementalSync(
        shifts: [RideshareShift],
        expenses: [ExpenseItem],
        lastSyncDate: Date?
    ) async throws -> SyncResult {
        guard isICloudAvailable else {
            throw CloudSyncError.iCloudUnavailable
        }
        
        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        
        do {
            // Download current cloud data
            let (cloudShifts, cloudExpenses, cloudMetadata) = try await downloadAllCloudData()
            
            // Resolve conflicts and merge changes
            let mergedShifts = try mergeShifts(local: shifts, cloud: cloudShifts, lastSync: lastSyncDate)
            let mergedExpenses = try mergeExpenses(local: expenses, cloud: cloudExpenses, lastSync: lastSyncDate)
            
            // Upload merged data back to cloud
            try await uploadShifts(mergedShifts)
            try await uploadExpenses(mergedExpenses)
            
            // Update sync metadata
            let newMetadata = SyncMetadata(
                lastSyncDate: Date(),
                deviceID: await MainActor.run { UIDevice.current.identifierForVendor?.uuidString ?? "unknown" },
                schemaVersion: cloudMetadata?.schemaVersion ?? 1
            )
            try await uploadSyncMetadata(newMetadata)
            
            await MainActor.run {
                isSyncing = false
            }
            
            return SyncResult(
                mergedShifts: mergedShifts,
                mergedExpenses: mergedExpenses,
                conflictsResolved: 0 // TODO: Count actual conflicts
            )
            
        } catch {
            await MainActor.run {
                isSyncing = false
                syncError = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - Upload Operations
    
    private func uploadShifts(_ shifts: [RideshareShift]) async throws {
        let data = try JSONEncoder().encode(shifts)
        try await storage.writeData(data, to: shiftsFileName)
        try await storage.waitForUpload(fileName: shiftsFileName, timeout: 30)
    }
    
    private func uploadExpenses(_ expenses: [ExpenseItem]) async throws {
        let data = try JSONEncoder().encode(expenses)
        try await storage.writeData(data, to: expensesFileName)
        try await storage.waitForUpload(fileName: expensesFileName, timeout: 30)
    }
    
    private func uploadSyncMetadata(_ metadata: SyncMetadata) async throws {
        let data = try JSONEncoder().encode(metadata)
        try await storage.writeData(data, to: syncMetadataFileName)
        try await storage.waitForUpload(fileName: syncMetadataFileName, timeout: 30)
    }
    
    // MARK: - Download Operations
    
    private func downloadAllCloudData() async throws -> (shifts: [RideshareShift], expenses: [ExpenseItem], metadata: SyncMetadata?) {
        // Download shifts
        let shifts: [RideshareShift]
        if storage.fileExists(shiftsFileName) {
            try await storage.waitForDownload(fileName: shiftsFileName, timeout: 30)
            if let data = try await storage.readData(from: shiftsFileName) {
                shifts = try JSONDecoder().decode([RideshareShift].self, from: data)
            } else {
                shifts = []
            }
        } else {
            shifts = []
        }
        
        // Download expenses
        let expenses: [ExpenseItem]
        if storage.fileExists(expensesFileName) {
            try await storage.waitForDownload(fileName: expensesFileName, timeout: 30)
            if let data = try await storage.readData(from: expensesFileName) {
                expenses = try JSONDecoder().decode([ExpenseItem].self, from: data)
            } else {
                expenses = []
            }
        } else {
            expenses = []
        }
        
        // Download metadata
        let metadata: SyncMetadata?
        if storage.fileExists(syncMetadataFileName) {
            try await storage.waitForDownload(fileName: syncMetadataFileName, timeout: 30)
            if let data = try await storage.readData(from: syncMetadataFileName) {
                metadata = try JSONDecoder().decode(SyncMetadata.self, from: data)
            } else {
                metadata = nil
            }
        } else {
            metadata = nil
        }
        
        return (shifts, expenses, metadata)
    }
    
    // MARK: - Conflict Resolution
    
    private func mergeShifts(local: [RideshareShift], cloud: [RideshareShift], lastSync: Date?) throws -> [RideshareShift] {
        var merged: [UUID: RideshareShift] = [:]
        
        // Add all cloud shifts first
        for shift in cloud {
            merged[shift.id] = shift
        }
        
        // Merge local changes
        for localShift in local {
            if let cloudShift = merged[localShift.id] {
                // Conflict resolution: use the most recently modified version
                if localShift.modifiedDate > cloudShift.modifiedDate {
                    merged[localShift.id] = localShift
                }
                // If cloud version is newer, keep it (already in merged)
            } else {
                // New local shift, add it
                merged[localShift.id] = localShift
            }
        }
        
        // Filter out deleted items
        return Array(merged.values.filter { !$0.isDeleted })
    }
    
    private func mergeExpenses(local: [ExpenseItem], cloud: [ExpenseItem], lastSync: Date?) throws -> [ExpenseItem] {
        var merged: [UUID: ExpenseItem] = [:]
        
        // Add all cloud expenses first
        for expense in cloud {
            merged[expense.id] = expense
        }
        
        // Merge local changes
        for localExpense in local {
            if let cloudExpense = merged[localExpense.id] {
                // Conflict resolution: use the most recently modified version
                if localExpense.modifiedDate > cloudExpense.modifiedDate {
                    merged[localExpense.id] = localExpense
                }
                // If cloud version is newer, keep it (already in merged)
            } else {
                // New local expense, add it
                merged[localExpense.id] = localExpense
            }
        }
        
        // Filter out deleted items
        return Array(merged.values.filter { !$0.isDeleted })
    }
    
    // MARK: - Storage Helper Methods (now abstracted)
    
    // MARK: - Permanent Cloud Cleanup
    
    func permanentlyDeleteFromCloud() async throws {
        // Download current data
        let (cloudShifts, cloudExpenses, _) = try await downloadAllCloudData()
        
        // Filter out deleted records permanently
        let cleanShifts = cloudShifts.filter { !$0.isDeleted }
        let cleanExpenses = cloudExpenses.filter { !$0.isDeleted }
        
        // Upload cleaned data back to storage
        try await uploadShifts(cleanShifts)
        try await uploadExpenses(cleanExpenses)
        
        print("Permanently deleted \(cloudShifts.count - cleanShifts.count) shifts and \(cloudExpenses.count - cleanExpenses.count) expenses from storage")
    }
}

// MARK: - Supporting Types

struct SyncMetadata: Codable {
    let lastSyncDate: Date
    let deviceID: String
    let schemaVersion: Int
}

struct SyncResult {
    let mergedShifts: [RideshareShift]
    let mergedExpenses: [ExpenseItem]
    let conflictsResolved: Int
}

enum CloudSyncError: LocalizedError {
    case iCloudUnavailable
    case downloadTimeout
    case uploadTimeout
    case conflictResolution
    case downloadFailed
    
    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud sync is currently unavailable. Please ensure:\n• You're signed into iCloud\n• iCloud Drive is enabled\n• You have an internet connection"
        case .downloadTimeout:
            return "Timeout downloading from iCloud. Please check your internet connection."
        case .uploadTimeout:
            return "Timeout uploading to iCloud. Please check your internet connection."
        case .conflictResolution:
            return "Unable to resolve sync conflicts. Please try again."
        case .downloadFailed:
            return "Failed to download from cloud storage. Please check your connection and try again."
        }
    }
}