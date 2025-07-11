import Foundation

/// Manages the association between business-logic specific identifiers and uniquely generated idempotency keys.
class IdempotencyKeyManager {
    typealias IdempotencyKey = String

    // MARK: - Properties

    private let userDefaultsKey = "IdempotencyKeys"

    private var storage: [String: IdempotencyKey] = [:] {
        didSet {
            saveToUserDefaults()
        }
    }

    // MARK: - Initializers

    init() {
        storage = loadFromUserDefaults() ?? [:]
    }

    // MARK: - Methods

    /// Store an idempotency key for a transaction ID
    func store(id: String, idempotencyKey: IdempotencyKey) {
        storage[id] = idempotencyKey
    }

    /// Remove an idempotency key for a transaction ID
    func removeKey(for id: String) {
        storage.removeValue(forKey: id)
    }

    /// Get an idempotency key for a transaction ID (returns nil if not found)
    func getKey(for id: String) -> IdempotencyKey? {
        return storage[id]
    }
    
    // Add this method to IdempotencyKeyManager
    func cleanupExpiredKeys() {
        let cutoffDate = Date().addingTimeInterval(-25 * 3600) // 25 hours to be safe
        var activeKeys: [String: IdempotencyKey] = [:]
        
        for (transactionId, key) in storage {
            // Parse timestamp from transaction ID
            let components = transactionId.split(separator: "_")
            if components.count >= 3,
               let timestampString = components.last,
               let timestamp = TimeInterval(timestampString) {
                
                let transactionDate = Date(timeIntervalSince1970: timestamp)
                if transactionDate > cutoffDate {
                    activeKeys[transactionId] = key
                }
            } else {
                // Keep keys we can't parse (shouldn't happen with your format)
                activeKeys[transactionId] = key
            }
        }
        
        let removedCount = storage.count - activeKeys.count
        if removedCount > 0 {
            print("🧹 Cleaning up \(removedCount) expired idempotency keys")
            storage = activeKeys
        }
    }

    // MARK: - Private Methods

    private func loadFromUserDefaults() -> [String: IdempotencyKey]? {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            return try? JSONDecoder().decode([String: IdempotencyKey].self, from: data)
        }
        return nil
    }

    private func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(storage) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
