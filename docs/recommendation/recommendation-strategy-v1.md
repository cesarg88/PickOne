# Recommendation Strategy v1

## Status

Accepted

## Purpose

This document defines how PickOne should think about conversational recommendations before introducing a real AI provider, backend, proxy, authentication, streaming, or long-term memory.

The current Ask experience already exists and is intentionally powered by a local stub/mock recommendation source. That was the correct milestone decision: validate the product surface and architecture before committing to infrastructure.

This strategy document is the bridge between the current stubbed UX and any future real recommendation system.

It should answer:

- what PickOne is trying to achieve with recommendations
- what a good recommendation means
- how user intent should be interpreted
- when the system should answer immediately
- when it should ask for clarification
- what data the recommendation system may use
- how future AI/backend work should be evaluated

It should not define implementation details such as provider choice, endpoint structure, deployment, authentication, pricing, or streaming.

---

## North Star

PickOne does not exist to maximize browsing.

PickOne exists to help the user stop searching and confidently choose something to watch.

The recommendation system should optimize for:

> faster, more confident viewing decisions

Not for:

- longer sessions
- larger result lists
- generic catalogue exploration
- chatbot-like conversation for its own sake
- exhaustive movie knowledge

A successful recommendation is one that reduces uncertainty.

---

## Product Principle

The Ask experience is not a general-purpose chatbot.

It is a decision assistant.

That distinction matters.

A chatbot keeps the conversation going.

PickOne should help the user make a decision.

Therefore:

- answers should be concise
- recommendations should be limited
- explanations should be useful but short
- the system should avoid unnecessary back-and-forth
- the user should always have a clear next action

---

## Core User Problem

Users often know roughly what they want, but struggle to translate that feeling into a concrete title.

Examples:

- "something like Blade Runner but more recent"
- "something light for tonight"
- "a good thriller under two hours"
- "something to watch with my partner"
- "I loved Interstellar"
- "I want something dark but not depressing"

The challenge is not simply matching keywords.

The challenge is understanding the underlying intent.

---

## What Makes a Good Recommendation?

A good PickOne recommendation should be:

### 1. Decision-oriented

It should help the user decide, not simply expose more options.

The output should feel like:

> "Here are a few strong choices. Start here."

Not:

> "Here is a long catalogue of possible matches."

### 2. Context-aware

It should respond to the actual constraint or mood in the prompt.

If the user says "under two hours", runtime matters.

If the user says "light", tone matters.

If the user says "like Arrival", the relevant similarity may be tone, theme, pacing, emotional weight, structure, or genre.

### 3. Explainable

Each recommendation should include a short reason.

The reason should explain why it fits the user intent, not summarize the plot.

Good:

> "Fits if you want thoughtful sci-fi with emotional stakes and a slower, mysterious build."

Weak:

> "This is a science fiction movie released in 2016."

### 4. Actionable

Every recommendation should map to a real movie in the app.

The user should be able to open detail, add to watchlist, or mark as watched.

Text-only recommendations are not acceptable as the final product behavior.

### 5. Limited

PickOne should prefer a small number of strong recommendations.

Default target:

- 3 recommendations for focused prompts
- up to 5 for broad prompts

Avoid returning more than 5.

---

## User Intent Model

The recommendation system should classify prompts by the kind of intent they express.

This does not require a formal ML classifier in the app today. It is a product model for reasoning about future behavior.

### 1. Mood intent

Examples:

- "something funny"
- "something dark"
- "something relaxing"
- "something intense"
- "something emotional"

Primary matching dimensions:

- tone
- pacing
- emotional weight
- genre

Expected behavior:

- answer directly if the mood is clear
- avoid overexplaining
- provide 3 strong options

---

### 2. Constraint intent

Examples:

- "under 90 minutes"
- "not too long"
- "something from the last 10 years"
- "nothing too violent"

Primary matching dimensions:

- runtime
- release year
- content intensity
- genre exclusions

Expected behavior:

- constraints must be respected when possible
- if a hard constraint cannot be satisfied, explain briefly

---

### 3. Reference-title intent

Examples:

- "something like Blade Runner"
- "I loved Interstellar"
- "similar to Hereditary"
- "like The Dark Knight but less superhero"

Primary matching dimensions:

- tone
- themes
- genre
- pacing
- visual style
- director/actor influence
- emotional effect

Expected behavior:

- infer what may have mattered about the reference
- avoid returning only obvious franchise/sequel matches
- explain the similarity in terms of experience, not metadata only

---

### 4. Social context intent

Examples:

- "something to watch with my partner"
- "something for family night"
- "something with friends"

Primary matching dimensions:

- accessibility
- tone
- broad appeal
- content intensity
- pacing

Expected behavior:

- prefer approachable recommendations
- avoid extreme or divisive picks unless explicitly requested

---

### 5. Discovery intent

Examples:

- "surprise me"
- "something underrated"
- "something I probably missed"
- "hidden gem"

Primary matching dimensions:

- quality
- novelty
- lower obviousness
- relevance to broad taste signals

Expected behavior:

- provide slightly less obvious recommendations
- still avoid randomness
- explain why the pick is worth attention

---

### 6. Vague intent

Examples:

- "recommend something"
- "what should I watch?"
- "give me a movie"

Expected behavior:

PickOne should not always ask a follow-up question.

For MVP, the preferred behavior is:

- provide a small set of safe, diverse, high-confidence recommendations
- include suggestion chips/prompts for refinement

Future behavior may ask one clarification question if enough user context exists to make that valuable.

---

## Answer vs Clarify Policy

PickOne should answer directly when:

- the prompt includes a clear mood
- the prompt includes a reference movie
- the prompt includes a clear genre
- the prompt includes a practical constraint
- the user appears to want quick help

PickOne may ask a clarification question when:

- the prompt is too broad and user context is unavailable
- two or more strong interpretations conflict
- answering would likely produce generic recommendations
- the user explicitly asks for a more tailored choice

However, clarification should be used sparingly.

The product promise is speed.

Default behavior should be:

> recommend first, refine second

Not:

> interrogate first, recommend later

---

## Recommendation Output Shape

The user-facing output should include:

### Overall explanation

A short statement explaining the recommendation set.

Example:

> "These lean toward thoughtful sci-fi with emotional stakes rather than pure action."

### Recommendation items

Each recommendation should include:

- movie identifier where possible
- title
- year when useful
- short reason
- resolved movie summary from the movie domain layer

### Reason quality bar

Reasons should be:

- specific
- short
- tied to user intent
- not generic plot summaries

Avoid:

- long essays
- generic praise
- unsupported certainty
- pretending the app knows more user preference data than it actually has

---

## Data Available by Product Stage

### Current stage

Available:

- user prompt
- local watchlist
- watched state
- TMDB movie metadata
- recommendation stub candidates

Not available:

- real user ratings
- real preference model
- long-term conversation memory
- account-level history
- streaming availability
- backend-side personalization

### Near future

Potential inputs:

- watchlist items
- watched movies
- local search history
- repeated Ask prompts

### Later

Potential inputs:

- explicit likes/dislikes
- rejected recommendations
- recommendation history
- multi-user/couple preferences
- streaming availability

Each new input must earn its complexity.

Do not add personalization signals simply because they are available.

---

## Source Trust Policy

Recommendation source output must not be treated as final display data.

Current accepted rule:

1. Recommendation source returns candidates.
2. Domain use case enriches candidates through `MovieRepository`.
3. Unresolved candidates are dropped.
4. Final recommendations are created only from resolved movie domain data.

This preserves the movie domain layer as the authority for movie information.

---

## Recommendation Diversity

PickOne should avoid returning recommendations that feel redundant.

Unless explicitly requested, avoid:

- multiple movies from the same franchise
- five movies from the same director
- several recommendations with the exact same tone
- obvious duplicates of the reference title

For vague prompts, recommendations should cover at least a small range of tones or genres.

For focused prompts, diversity should not override relevance.

---

## Personalization Policy

Personalization should be introduced gradually.

The first useful personalization signals are likely:

1. watched movies
2. watchlist items
3. repeated Ask prompts
4. explicit likes/dislikes

Avoid pretending to know the user.

If using weak signals, language should remain cautious.

Good:

> "Since this is already in your watchlist, this might be a good next pick."

Risky:

> "You love slow-burn thrillers."

Unless the product has evidence for that claim.

---

## Watchlist Relationship

Ask recommendations should eventually understand watchlist state, but this does not need to block the current recommendation strategy.

Possible future behavior:

- avoid recommending already watched movies unless asked
- highlight if a recommendation is already in watchlist
- prioritize watchlist items when the user asks "what should I watch tonight?"
- help sort or reduce the watchlist

Current stage:

- recommendation cards may offer add-to-watchlist
- full watchlist-aware recommendation logic is optional and should be introduced deliberately

---

## Conversation Memory

Conversation memory is not part of the current product strategy.

Do not introduce long-term memory before answering:

- what should be remembered?
- why should it be remembered?
- how can the user correct it?
- how does memory improve decisions?
- how do we prevent stale assumptions?

Short-term in-session context may become useful, but only after the single-turn recommendation experience is strong.

---

## Backend Readiness Criteria

A real backend or proxy should not be introduced merely because the Ask tab exists.

Backend work becomes justified when at least some of the following are true:

- the UX pattern is stable enough to preserve
- the recommendation request/response contract is clear
- prompt strategy has at least a first accepted version
- enrichment responsibilities are explicitly assigned between client and backend
- error semantics are defined
- secrets/provider access must be protected
- real provider iteration is necessary to learn more

Until then, the local stub remains acceptable.

---

## Future Backend Principles

If/when a backend is introduced:

- the app should not talk directly to AI providers
- provider secrets must not ship in the app
- backend output should prefer TMDB IDs
- backend may return candidate reasons, but app/domain still controls enrichment
- backend should not return UI-specific models
- provider-specific quirks should not leak into Presentation

The backend should support the product strategy, not define it.

---

## Success Signals

A recommendation flow is improving if:

- users submit prompts without needing instructions
- users understand why recommendations fit
- users tap into detail from recommendations
- users add recommended movies to watchlist
- users ask fewer follow-up questions because the first answer is useful
- users report that choosing feels easier

A recommendation flow is not improving if:

- the answer is technically impressive but too long
- the system returns too many options
- users keep refining because the first answer was vague
- recommendations feel generic
- recommendations cannot be opened in the app
- the system behaves like a chatbot rather than a decision assistant

---

## Non-Goals

This strategy does not aim to define:

- real backend architecture
- provider choice
- pricing or model selection
- streaming
- authentication
- recommendation history
- account sync
- collaborative filtering
- streaming availability
- long-term memory

Those require separate decisions.

---

## Open Questions

These should be answered before real backend/provider work:

1. What prompt categories should be considered officially supported?
2. Should vague prompts answer immediately or ask a clarification question?
3. Should recommendations default to 3 or 5 items?
4. Should already watched movies be excluded by default?
5. Should watchlist items be prioritized for "what should I watch tonight?"
6. Should backend return only TMDB IDs, or allow title/year fallback?
7. What error states should distinguish model failure vs no valid movie candidates?
8. What user feedback should be captured after recommendations?

---

## Recommended Next Step

After this document is reviewed and accepted, the next logical step is not implementation.

The next step should be to define:

- supported prompt categories
- response shape examples
- decision rules for answer vs clarification
- backend readiness checklist

Only after that should PickOne begin real provider/backend integration.

---

## CTO Summary

PickOne's recommendation system should be designed around decision quality, not AI novelty.

The strategic challenge is not to make the app "use AI".

The strategic challenge is to make the user feel:

> "I know what to watch now."

Everything else is implementation detail.
