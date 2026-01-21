import Foundation

struct CacheKey: Hashable {
    let rawValue: String
}

struct CacheEntry<Value> {
    let value: Value
    let storedAt: Date
    let expiresAt: Date
    
    var isExpired: Bool {
        Date() >= expiresAt
    }
}

protocol CacheStore {
    func get<Value>(for key: CacheKey, as type: Value.Type) async -> CacheEntry<Value>?
    func set<Value>(value: Value, for key: CacheKey, ttl: TimeInterval) async
    func remove(for key: CacheKey) async
}
