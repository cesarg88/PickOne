import Foundation

actor MemoryCacheStore: CacheStore {
    private struct AnyCacheEntry {
        let value: Any
        let storedAt: Date
        let expiresAt: Date
    }
    
    private var entries: [String: AnyCacheEntry] = [:]
    
    func get<Value>(for key: CacheKey, as type: Value.Type) async -> CacheEntry<Value>? {
        guard let entry = entries[key.rawValue], let value = entry.value as? Value else {
            return nil
        }
        return CacheEntry(value: value, storedAt: entry.storedAt, expiresAt: entry.expiresAt)
    }
    
    func set<Value>(value: Value, for key: CacheKey, ttl: TimeInterval) async {
        let now = Date()
        let entry = AnyCacheEntry(value: value, storedAt: now, expiresAt: now.addingTimeInterval(ttl))
        entries[key.rawValue] = entry
    }
    
    func remove(for key: CacheKey) async {
        entries.removeValue(forKey: key.rawValue)
    }
}
