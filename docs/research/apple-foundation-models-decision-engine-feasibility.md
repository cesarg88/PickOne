# Apple Foundation Models — Decision Engine Feasibility Study

**Status:** Accepted
**Date:** 11 August 2026
**Scope:** Determine whether Apple Foundation Models should participate in PickOne's Decision Engine v1 for Milestone 6.

## Executive decision

**Do not integrate Apple Foundation Models into the Milestone 6 Decision Engine. Keep P1 deterministic and authoritative.**

Foundation Models does have a promising role in PickOne, but later and at a different boundary: interpreting a viewer's natural-language request into a small, validated, structured intent. In other words, it may improve **how the viewer tells PickOne what they want**, but it should not decide **which movie wins**.

Recommended future use:

> `Ask text → optional on-device intent interpreter → validated PreferenceDelta → deterministic Decision Engine`

This preserves PickOne's product promise that AI is optional, retains identical eligibility and scoring rules, and provides a complete fallback on unsupported devices or when the model is unavailable.

## Why this is the right boundary

### 1. It does not solve M6's core problem

M6 needs reproducible filtering, scoring and diversity rules that can be explained with fixtures. Foundation Models is optimized for language tasks such as extraction, classification, summarization and composition—not numerical recommendation scoring. Its public API does not expose movie embeddings, logits, confidence scores or a specialized reranking function. This last point is an inference from the documented public API surface, not an explicit Apple guarantee. [Foundation Models API](https://developer.apple.com/documentation/FoundationModels)

The accepted P1 model already solves the core problem with observable rules. Replacing or overriding it with generative judgment would make the result harder to test without supplying a better ranking signal.

### 2. PickOne cannot depend on universal availability

PickOne currently targets iOS 18. Foundation Models begins with iOS 26 and additionally requires an Apple Intelligence-capable device, Apple Intelligence enabled, compatible language settings and downloaded model assets. The framework reports states such as `deviceNotEligible`, `appleIntelligenceNotEnabled` and `modelNotReady`. [Apple Intelligence requirements](https://support.apple.com/en-us/121115) and [model availability](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason)

Therefore, an integration would have to be guarded by both platform availability and runtime availability. It cannot be a required path while PickOne supports iOS 18.

### 3. Generative repeatability is not product-rule determinism

Apple offers greedy sampling, described as producing the same output for the same input, and seeded random sampling with only best-effort determinism. However, Apple also replaces the underlying model in system updates and explicitly recommends retesting and updating prompts for new model versions. Even greedy sampling cannot guarantee durable equivalence across OS/model versions or different users' devices. [Greedy sampling](https://developer.apple.com/documentation/foundationmodels/generationoptions/samplingmode-swift.struct/greedy), [seeded sampling](https://developer.apple.com/documentation/foundationmodels/generationoptions/samplingmode-swift.struct/random%28probabilitythreshold%3Aseed%3A%29), and [updating prompts for new models](https://developer.apple.com/documentation/foundationmodels/updating-prompts-for-new-model-versions)

That is acceptable for interpreting or phrasing language. It is not acceptable as the authority behind fixture-tested ranking.

### 4. The context window is a poor fit for full-pool reranking

The on-device model has a 4,096-token session context, shared by instructions, prompts, schemas, tools, responses and transcript. The 120-candidate M6 pool, together with enough metadata to make a meaningful comparison, cannot be reliably evaluated in one session. Chunking it would introduce ordering and cross-batch comparison problems. [Managing the context window](https://developer.apple.com/documentation/foundationmodels/managing-the-context-window)

### 5. Its strongest PickOne capability is structured language extraction

`@Generable` and `@Guide` can constrain the shape of model output to Swift structures. That makes the framework well suited to converting a request such as:

> “Quiero un thriller de misterio con giros, nada de musicales y que no sea demasiado antigua.”

into a closed structure such as genres, excluded topics, era preference and maximum runtime. The generated structure still needs domain validation; constrained generation guarantees structure, not semantic truth. [Generable](https://developer.apple.com/documentation/foundationmodels/generable) and [Foundation Models framework overview](https://developer.apple.com/videos/play/wwdc2025/286/)

## Use-case assessment

| Potential use | Assessment | Decision |
|---|---|---|
| Core P1 scoring | No movie-scoring primitive; not durable across model versions; limited device coverage | **Do not use** |
| TMDB candidate generation | The model has no authoritative, current TMDB catalogue or availability data | **Do not use** |
| Eligibility and availability | Must remain exact, region-aware product rules | **Do not use** |
| Reranking the 120-candidate pool | Context is insufficient; batching would bias comparison; results are model-version dependent | **Do not use** |
| Selecting Safe / Stretch / Discovery | These are accepted, fixture-testable product semantics | **Keep deterministic** |
| Recommendation explanations | Could paraphrase facts, but adds hallucination and availability risk for limited value | **Keep templates in M6; optional experiment later** |
| Synopsis/topic tagging | Potentially useful for signals absent from TMDB genres, but guardrails and semantic variation require evaluation | **Possible later experiment** |
| `Ask` preference extraction | Excellent fit for private, on-device, structured language understanding | **Recommended future use** |

## Privacy, operation and failure modes

The base model runs on-device and can work offline after the assets are present, with no per-request inference charge. Any tool call that PickOne makes to TMDB would still be network traffic controlled by PickOne. [Apple announcement](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/)

The implementation would still need to handle:

- model not ready or assets unavailable;
- ineligible device or disabled Apple Intelligence;
- unsupported language or locale;
- context overflow and rate limiting;
- guardrail refusal, including possible false positives for legitimate horror, crime or adult movie descriptions;
- concurrent request rejection;
- changing output after OS/model updates.

Apple documents safety handling and recommends app-specific mitigations rather than assuming every valid input will produce an answer. [Model safety](https://developer.apple.com/documentation/FoundationModels/improving-the-safety-of-generative-model-output) and [language support](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models)

## Local feasibility check

The framework is present in the installed Xcode 26.5 SDK. The local system reported:

- model availability: available;
- Spanish locale: supported;
- context size: 4,096 tokens.

However, three attempted generations failed immediately with an underlying model-asset service error, despite the initial `available` state. This is one local observation, not evidence of a general framework defect. It does demonstrate why PickOne must treat generation as fallible even after an availability check and retain a complete deterministic fallback.

The physical iPhone intended for the pilot has not yet been identified in the project documentation, so its Apple Intelligence eligibility remains an open implementation fact. It does not affect the M6 decision because iOS 18 support already rules out making the framework mandatory.

## Recommended future architecture

If PickOne evaluates Foundation Models after M6, the boundary should be narrow:

1. Define a framework-independent domain type such as `ViewingIntent` or `PreferenceDelta`.
2. Keep Foundation Models types outside the Domain layer, behind an adapter available only on iOS 26+.
3. Use guided structured generation with closed enums and bounded optional values.
4. Validate every generated value in the domain before use.
5. Let P1 perform all candidate filtering, scoring, diversity and role assignment.
6. Never allow generated output to bypass availability, watched-state, explicit exclusions or the credibility threshold.
7. Offer manual controls or the normal deterministic result whenever generation is unavailable or fails.
8. Do not mutate the persistent Taste Profile from interpreted text without explicit viewer confirmation.

## Proposed post-M6 spike

A bounded experiment would be worthwhile after the deterministic engine is shipped:

- Parse 20–30 Spanish requests into a small `ViewingIntent` schema.
- Include cases derived from the current calibration: “thriller o misterio con giros”, “nada de musicales”, “no demasiado antigua”, and ambiguous or conflicting requests.
- Measure semantic accuracy, latency and failure behavior on the actual pilot iPhone.
- Repeat the evaluation after model/OS updates using Apple's prompt-evaluation guidance. [Evaluating prompts](https://developer.apple.com/documentation/foundationmodels/evaluating-prompts-to-measure-performance-and-improve-model-responses)
- Require the deterministic/manual fallback to pass the same product flow.

Success should mean that the interpreter reliably captures the viewer's stated intent without changing the accepted ranking rules—not that its prose sounds intelligent.

## Final recommendation

Record the following decision in the consolidated Decision Engine ADR:

> **Decision Engine v1 does not depend on Apple Foundation Models. Candidate generation, eligibility, scoring, diversity, role assignment and canonical explanations remain deterministic. Apple Foundation Models may be evaluated in a later milestone as an optional iOS 26+ adapter for structured natural-language intent extraction, with domain validation and a complete deterministic fallback.**

This keeps M6 focused and testable while preserving a genuinely useful path for Apple Intelligence in the medium-term product vision.
