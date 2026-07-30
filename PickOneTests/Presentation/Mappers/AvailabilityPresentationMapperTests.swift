import Foundation
import Testing
@testable import PickOne

@MainActor
@Suite("AvailabilityPresentationMapper tests")
struct AvailabilityPresentationMapperTests {
    @Test("eligible providers map logos, fallback names, order, and handoff")
    func mapsEligibleProviders() throws {
        let evidence = AvailabilityTestFixtures.verifiedEvidence(
            flatrate: [
                AvailabilityTestFixtures.offer(id: 8),
                AvailabilityTestFixtures.offer(id: 119, logoPath: nil)
            ]
        )
        let outcome = AvailabilityOutcome.eligible(
            providers: [
                EligibleStreamingProvider(
                    id: 8,
                    name: "Netflix",
                    logoPath: "/netflix.png",
                    productOrder: 1
                ),
                EligibleStreamingProvider(
                    id: 119,
                    name: "Amazon Prime Video",
                    logoPath: nil,
                    productOrder: 2
                )
            ],
            evidence: evidence
        )

        let state = AvailabilityPresentationMapper.map(outcome: outcome)

        guard case .eligible(let data) = state else {
            Issue.record("Expected eligible presentation")
            return
        }
        #expect(data.providers.map(\.name) == [
            "Netflix",
            "Amazon Prime Video"
        ])
        #expect(
            data.providers[0].logoURL?.absoluteString
                == "https://image.tmdb.org/t/p/w92/netflix.png"
        )
        #expect(data.providers[1].logoURL == nil)
        #expect(data.showsPlaybackOptionsAction)
    }

    @Test("invalid handoff URL is hidden without changing eligibility")
    func invalidURLHidesHandoff() {
        let evidence = AvailabilityTestFixtures.verifiedEvidence(
            watchURL: "https://example.com/watch",
            flatrate: [AvailabilityTestFixtures.offer(id: 8)]
        )
        let outcome = AvailabilityOutcome.eligible(
            providers: [
                EligibleStreamingProvider(
                    id: 8,
                    name: "Netflix",
                    logoPath: nil,
                    productOrder: 1
                )
            ],
            evidence: evidence
        )

        let state = AvailabilityPresentationMapper.map(outcome: outcome)

        guard case .eligible(let data) = state else {
            Issue.record("Expected eligible presentation")
            return
        }
        #expect(data.showsPlaybackOptionsAction == false)
    }

    @Test("accepted copy is exact")
    func acceptedCopyIsExact() {
        #expect(MovieAvailabilityViewState.title == "Available on")
        #expect(
            MovieAvailabilityViewState.ineligibleMessage
                == "Not shown as included with your services."
        )
        #expect(
            MovieAvailabilityViewState.unknownMessage
                == "We couldn't verify availability."
        )
        #expect(
            MovieAvailabilityViewState.attribution
                == "Availability data from JustWatch · may change"
        )
        #expect(
            MovieAvailabilityViewState.handoffTitle
                == "View playback options on TMDB"
        )
    }
}
