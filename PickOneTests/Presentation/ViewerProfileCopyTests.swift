@testable import PickOne
import Testing

@Suite("Viewer profile copy tests")
struct ViewerProfileCopyTests {
    @Test("accepted onboarding, completion, reset, and recovery copy is exact")
    func acceptedCopy() {
        #expect(ViewerProfileCopy.serviceTitle == "Streaming services")
        #expect(ViewerProfileCopy.region == "Availability region: Spain")
        #expect(ViewerProfileCopy.serviceGuidance == "Choose the services where you can watch movies without paying extra.")
        #expect(ViewerProfileCopy.progress == "8 taste signals help us start with more confidence.")
        #expect(ViewerProfileCopy.lowSignalTitle == "Want to rate a few more?")
        #expect(ViewerProfileCopy.lowSignalBody == "We can start broadly with what you have told us, or you can rate a few more movies first.")
        #expect(ViewerProfileCopy.completionTitle == "Your preferences are saved.")
        #expect(ViewerProfileCopy.completionBody == "We'll use them to improve what you can watch and your future recommendations.")
        #expect(ViewerProfileCopy.resetTitle == "Reset preferences?")
        #expect(ViewerProfileCopy.resetBody == "This removes your streaming services and movie calibration. Your Watchlist and Search History will stay.")
        #expect(ViewerProfileCopy.unsupportedTitle == "Preferences need to be reset")
        #expect(ViewerProfileCopy.corruptTitle == "Preferences couldn't be read")
    }
}
