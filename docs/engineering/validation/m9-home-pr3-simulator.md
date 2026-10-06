# M9 Home PR3 — simulator composition evidence

This evidence belongs to [issue #64](https://github.com/montunolabs/PickOne/issues/64) and [PR #71](https://github.com/montunolabs/PickOne/pull/71). It supplements the [physical validation guide](m9-home-pr3-physical.md); it is **not** physical-device approval. The full Home acceptance matrix remains in PR4/#65.

The screenshots come from isolated `-ui-testing` fixtures on iOS 26.5: iPhone 17 Pro and iPad (A16). The tests use in-memory recommendation data, generated/cached provider-logo images, and a solid dark-blue fixture backdrop. They do not fetch network artwork or alter a real profile. The reference-copy and provider-count cases are enabled only by explicit test launch arguments; normal app launches do not use them.

| Scenario | Screenshot | What the focused test checks |
| --- | --- | --- |
| iPhone, Spanish reference composition and dark backdrop | [ES backdrop](m9-home-pr3-simulator/iphone-es-backdrop.png) | Full hero title, bounded art region, provider/CTA row and card order. |
| iPhone, English reference composition and dark backdrop | [EN backdrop](m9-home-pr3-simulator/iphone-en-backdrop.png) | Localized copy and the same composition. |
| iPhone, four successful provider logos | [Four logos](m9-home-pr3-simulator/iphone-four-logos.png) | All four logos remain one horizontal row, with Pick trailing and no visible provider names. |
| iPhone, long title and failed logo | [Long title/fallback](m9-home-pr3-simulator/iphone-long-title-logo-fallback.png) | Full multiline title, truthful fallback text after logo failure, and nonoverlapping Pick. |
| iPhone, accessibility XXXL | [Maximum text](m9-home-pr3-simulator/iphone-xxxl.png) | Last card's Pick/ellipsis and refresh action remain reachable through scrolling. |
| iPhone, missing artwork | [Poster fallback](m9-home-pr3-simulator/iphone-poster-fallback.png) | Hero remains semantically distinct with no backdrop; Detail and feedback remain reachable. |
| iPad portrait, English | [Portrait](m9-home-pr3-simulator/ipad-en-portrait.png) | Hero and alternatives remain ordered and readable. |
| iPad landscape, Spanish | [Landscape](m9-home-pr3-simulator/ipad-es-landscape.png) | Two-column layout; both alternative titles are complete and their cards and Pick controls are within the app viewport. |

Reproduce with `make test TEST_ONLY=PickOneUITests/HomeCompositionInteractionTests SIMULATOR_OS=26.5` on iPhone 17 Pro, then run the two iPad-only cases with `SIMULATOR_NAME='iPad (A16)'` and their individual `TEST_ONLY` identifiers. The iPhone run on 2026-10-06 passed 10 tests with two iPad-specific skips; both iPad cases passed separately. XCUI bounds assertions check semantic relationships and viewport inclusion, not fixed Figma coordinates. Simulator screenshots establish composition, not physical contrast, real VoiceOver focus, or a Product Owner's acceptance; record those against the exact build SHA in the physical guide.
