import Foundation

protocol ResponseMapper: Sendable {
    func map<T: Decodable>(_ data: Data, to type: T.Type) throws -> T
}

struct JSONResponseMapper: ResponseMapper {
    func map<T: Decodable>(_ data: Data, to type: T.Type) throws -> T {
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
                print("❌ Decoding error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Response body: \(jsonString.prefix(500))")
                }
            #endif
            throw NetworkError.decodingError(error)
        }
    }
}
