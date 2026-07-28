import Foundation

struct CacheResult<Value: Sendable>: Sendable {
    let value: Value
    let isStale: Bool
}
