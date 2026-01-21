import Foundation

struct CacheResult<Value> {
    let value: Value
    let isStale: Bool
}
