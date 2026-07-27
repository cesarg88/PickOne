import Foundation

struct CacheKey: Hashable, Sendable {
    let rawValue: String
}

struct CacheEntry<Value: Sendable>: Sendable {
    let value: Value
    let storedAt: Date
    let expiresAt: Date
    
    var isExpired: Bool {
        Date() >= expiresAt
    }
}

protocol CacheStore: Sendable {
    func get<Value: Sendable>(for key: CacheKey, as type: Value.Type) async -> CacheEntry<Value>?
    func set<Value: Sendable>(value: Value, for key: CacheKey, ttl: TimeInterval) async
    func remove(for key: CacheKey) async
}
