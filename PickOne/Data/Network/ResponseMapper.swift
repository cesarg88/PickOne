import Foundation

protocol ResponseMapper {
    func map<T: Decodable>(_ data: Data, to type: T.Type) throws -> T
}

final class JSONResponseMapper: ResponseMapper {
    
    private let decoder: JSONDecoder
    
    init() {
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    func map<T: Decodable>(_ data: Data, to type: T.Type) throws -> T {
        do {
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
