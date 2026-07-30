import Foundation
import Testing
@testable import PickOne

@Suite("Availability DTO and mapping tests")
struct AvailabilityDTOTests {
    @Test("decodes complete provider evidence")
    func decodesCompleteEvidence() throws {
        let response = try decode(
            """
            {
              "id": 42,
              "results": {
                "ES": {
                  "link": "https://www.themoviedb.org/movie/42/watch?locale=ES",
                  "flatrate": [
                    {"provider_id": 8, "provider_name": "Netflix", "logo_path": "/netflix.png"}
                  ],
                  "rent": [
                    {"provider_id": 10, "provider_name": "Store", "logo_path": null}
                  ],
                  "buy": [
                    {"provider_id": 11, "provider_name": "Buy", "logo_path": "/buy.png"}
                  ],
                  "ads": [
                    {"provider_id": 12, "provider_name": "Ads", "logo_path": "/ads.png"}
                  ],
                  "free": [
                    {"provider_id": 13, "provider_name": "Free", "logo_path": "/free.png"}
                  ]
                }
              }
            }
            """
        )

        let region = try #require(response.results["ES"])
        #expect(response.id == 42)
        #expect(region.flatrate?.first?.providerId == 8)
        #expect(region.rent?.first?.providerId == 10)
        #expect(region.buy?.first?.providerId == 11)
        #expect(region.ads?.first?.providerId == 12)
        #expect(region.free?.first?.providerId == 13)
    }

    @Test("missing monetization arrays decode as empty evidence")
    func missingArraysMapToEmpty() throws {
        let response = try decode(
            """
            {
              "id": 42,
              "results": {
                "ES": {
                  "link": "https://www.themoviedb.org/movie/42/watch"
                }
              }
            }
            """
        )

        let evidence = try #require(
            AvailabilityMapper.map(response: response, region: .spain)
        )
        #expect(evidence.flatrate.isEmpty)
        #expect(evidence.rent.isEmpty)
        #expect(evidence.buy.isEmpty)
        #expect(evidence.ads.isEmpty)
        #expect(evidence.free.isEmpty)
    }

    @Test("missing Spain entry maps to no regional evidence")
    func missingSpainMapsToNil() throws {
        let response = try decode(
            """
            {
              "id": 42,
              "results": {
                "FR": {
                  "flatrate": []
                }
              }
            }
            """
        )

        #expect(
            AvailabilityMapper.map(response: response, region: .spain) == nil
        )
    }

    @Test("invalid provider structure fails decoding")
    func invalidFixtureFails() {
        #expect(throws: DecodingError.self) {
            try decode(
                """
                {
                  "id": 42,
                  "results": {
                    "ES": {
                      "flatrate": [
                        {"provider_name": "Missing identifier"}
                      ]
                    }
                  }
                }
                """
            )
        }
    }

    @Test("maps every category and preserves the regional URL")
    func mapsEveryCategory() throws {
        let response = AvailabilityTestFixtures.responseDTO(
            results: [
                "ES": AvailabilityTestFixtures.regionDTO(
                    flatrate: [.init(providerId: 8, providerName: "N", logoPath: "/n.png")],
                    rent: [.init(providerId: 10, providerName: "R", logoPath: nil)],
                    buy: [.init(providerId: 11, providerName: "B", logoPath: nil)],
                    ads: [.init(providerId: 12, providerName: "A", logoPath: nil)],
                    free: [.init(providerId: 13, providerName: "F", logoPath: nil)]
                )
            ]
        )

        let evidence = try #require(
            AvailabilityMapper.map(response: response, region: .spain)
        )
        #expect(evidence.watchURL == AvailabilityTestFixtures.tmdbURL)
        #expect(evidence.flatrate.map(\.providerID) == [8])
        #expect(evidence.rent.map(\.providerID) == [10])
        #expect(evidence.buy.map(\.providerID) == [11])
        #expect(evidence.ads.map(\.providerID) == [12])
        #expect(evidence.free.map(\.providerID) == [13])
    }

    private func decode(_ json: String) throws -> WatchProvidersResponseDTO {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(
            WatchProvidersResponseDTO.self,
            from: Data(json.utf8)
        )
    }
}
