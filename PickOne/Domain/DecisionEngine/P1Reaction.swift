extension CalibrationReaction {
    var p1Value: Double? {
        switch self {
            case .loveIt: 1.00
            case .likeIt: 0.50
            case .itWasOkay: 0.00
            case .didNotLikeIt: -0.75
            case .haveNotSeenIt, .doNotKnowIt: nil
        }
    }

    var isDirectionalEvidence: Bool {
        switch self {
            case .loveIt, .likeIt, .didNotLikeIt: true
            case .itWasOkay, .haveNotSeenIt, .doNotKnowIt: false
        }
    }

    var isPositiveP1Anchor: Bool {
        switch self {
            case .loveIt, .likeIt: true
            case .itWasOkay, .didNotLikeIt, .haveNotSeenIt, .doNotKnowIt: false
        }
    }

    var p1AnchorStrength: Double? {
        switch self {
            case .loveIt: 1.00
            case .likeIt: 0.75
            case .itWasOkay, .didNotLikeIt, .haveNotSeenIt, .doNotKnowIt: nil
        }
    }
}
