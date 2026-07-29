# TMDB Spain Streaming Availability Findings

## 1. Executive conclusion

**Viability classification: `Viable for the pilot with explicit restrictions`.**

TMDB can supply enough Spain-specific movie availability evidence for the
PickOne pilot. On 2026-07-28, TMDB returned the following standalone provider
entries for region `ES`:

- Netflix: provider `8`
- Amazon Prime Video: provider `119`
- Disney Plus: provider `337`
- HBO Max: provider `1899`

The main sample checked 20 Discover candidates per provider, 80 provider/movie
associations in total and 78 unique movies. All 80 associations were present
under the movie-level `results.ES.flatrate` section. No sampled movie lacked an
`ES` entry, no expected provider was missing, and no duplicate provider entry
appeared inside a monetization array.

The evidence does not support using Discover results as final eligibility
proof. A negative control using provider `10` (`Amazon Video`) together with
`with_watch_monetization_types=flatrate` returned 9,304 results. In the checked
result, Amazon Video appeared only under `rent` and `buy`; unrelated providers
supplied the `flatrate` offers. The provider and monetization filters therefore
act as simultaneous movie-level filters but are not guaranteed to describe the
same offer.

The viable pilot path consequently has these candidate restrictions for
Product Owner and CTO review:

1. Use an explicit allowlist of standalone provider IDs.
2. Treat Discover only as candidate generation.
3. Before eligibility, require the selected provider to occur in that movie's
   `ES` `flatrate` array.
4. Require the exact provider that represents the selected entitlement. For the
   confirmed pilot entitlements, this excludes stores, ad-labelled variants,
   and add-on-channel IDs even when TMDB places them under `flatrate`.
5. Describe availability as current best-known information, not a guarantee;
   TMDB exposes no availability freshness timestamp.
6. Use the returned country-specific TMDB watch URL for handoff unless a
   separately supported direct link is later obtained. Do not manufacture a
   streaming-service deep link.
7. Attribute both TMDB and JustWatch as required.

This is research evidence, not an accepted implementation or product
specification.

## 2. Research scope

| Field | Value |
| --- | --- |
| Date accessed | 2026-07-28 |
| Region | Spain (`ES`) |
| Content type | Movies only |
| Target services | Netflix, Amazon Prime Video, Disney+, HBO Max |
| Accepted monetization | Included subscription (`flatrate`) only |
| Excluded monetization | `ads`, `free`, `rent`, and `buy` |
| Explicitly excluded variants | Ad-labelled plans, stores, and add-on channels |
| Product authority | [`PRODUCT.md`](../../PRODUCT.md) |
| Backlog relationship | [`IMP-009`](../product/improvement-backlog.md#imp-009--add-regional-availability-and-a-path-to-watch) |

Application code, onboarding, ranking, persistence, TV availability, production
architecture, and direct JustWatch integration were not changed or evaluated.

## 3. Official sources

All sources were accessed on 2026-07-28.

| Official source | Evidence established |
| --- | --- |
| [TMDB Movie Providers](https://developer.themoviedb.org/reference/watch-providers-movie-list) | The movie-provider list supports `watch_region`; the live list was queried with `ES`. |
| [TMDB Discover Movie](https://developer.themoviedb.org/reference/discover-movie) | `watch_region`, `with_watch_providers`, and `with_watch_monetization_types`; allowed monetization values; documented comma (`AND`) and pipe (`OR`) syntax. |
| [TMDB Movie Watch Providers](https://developer.themoviedb.org/reference/movie-watch-providers) | Per-country availability shape, required JustWatch attribution, absence of full provider deep links, and the supported TMDB watch-page link. |
| [TMDB FAQ](https://developer.themoviedb.org/docs/faq) | TMDB logo, notice, naming, placement, and commercial-use requirements. |
| [TMDB Rate Limiting](https://developer.themoviedb.org/docs/rate-limiting) | Current bulk-request guidance and `429` handling expectations. |
| [JustWatch Content Partner API](https://apis.justwatch.com/docs/api/) | A direct JustWatch partner integration requires a concluded contract and partner token; partner responses can include a country-specific `full_path`. |

No blog posts, unofficial SDKs, scraped JustWatch endpoints, or remembered
provider IDs were used.

## 4. Reproducible methodology

The local ignored TMDB read-access credential was loaded in process memory. It
was never printed, copied into a request example, written into the findings, or
committed. The research made 182 authenticated HTTPS requests and retained only
aggregate, credential-free evidence.

The provider list used this request shape:

```text
GET /3/watch/providers/movie
    ?watch_region=ES
    &language=es-ES
Authorization: Bearer <TMDB_READ_ACCESS_TOKEN>
```

For each accepted provider, five popularity-ordered Discover pages were read:

```text
GET /3/discover/movie
    ?watch_region=ES
    &with_watch_providers=<PROVIDER_ID>
    &with_watch_monetization_types=flatrate
    &sort_by=popularity.desc
    &include_adult=false
    &include_video=false
    &language=es-ES
    &page=<1...5>
Authorization: Bearer <TMDB_READ_ACCESS_TOKEN>
```

Four movies were selected from each page. Selection favored unseen original
languages, decades, genres, and different within-page position buckets. This
produced 20 checks per provider across 100 observed candidates, rather than
checking only the first results.

Each sampled movie was then checked with:

```text
GET /3/movie/<MOVIE_ID>/watch/providers
Authorization: Bearer <TMDB_READ_ACCESS_TOKEN>
```

For every provider/movie association, the check recorded:

- whether `results.ES` existed
- whether the expected provider ID occurred specifically in
  `results.ES.flatrate`
- whether that provider also occurred in `ads`, `free`, `rent`, or `buy`
- duplicate provider IDs within each monetization array
- the returned `results.ES.link`

The combined-provider tests used:

```text
with_watch_providers=8|119|337|1899
with_watch_providers=8,119,337,1899
with_watch_providers=8,119
```

Negative controls exercised `ads`, `free`, `rent`, `buy`, a title without an
`ES` entry, explicit ad-plan variants, an add-on channel, and the independence
of provider and monetization filters. Full API responses and the large sampled
movie list were intentionally not committed.

This is a dated snapshot. Re-running the same shapes may produce different
titles and counts as catalogs and TMDB data change.

## 5. Provider resolution for Spain

The live `ES` movie-provider list contained 79 entries. The exact standalone
entries selected as pilot candidates were:

| ID | Exact TMDB name | Priority | Logo path | Suspected role | Assessment |
| ---: | --- | ---: | --- | --- | --- |
| 8 | Netflix | 0 | `/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg` | Standalone subscription | Accept as candidate base provider. |
| 119 | Amazon Prime Video | 1 | `/pvske1MyAoymrs5bguRfVqYiM9a.jpg` | Standalone subscription, tier meaning not documented | Accept provisionally; Product Owner/CTO must confirm how this maps to the Spanish subscription now that TMDB also exposes an ads variant. |
| 337 | Disney Plus | 3 | `/97yvRBw1GzX7fXprcF80er19ot.jpg` | Standalone subscription | Accept as candidate base provider. |
| 1899 | HBO Max | 155 | `/jbe4gVSfRlbPTdESXhEKpornsfu.jpg` | Standalone subscription | Accept provisionally as the current standalone `ES` entry. |

`display_priority` is recorded exactly as returned. TMDB does not document it
as a provider-role or subscription-tier signal, so it was not used to accept or
reject an entry.

The following similarly named variants were returned and are not equivalent to
the four standalone candidates:

| ID | Exact TMDB name | Priority | Logo path | Role/evidence | Assessment |
| ---: | --- | ---: | --- | --- | --- |
| 10 | Amazon Video | 36 | `/qR6FKvnPBx2O37FDg8PNM7efwF3.jpg` | Store; control appeared under `rent` and `buy` | Reject. |
| 1796 | Netflix Standard with Ads | 154 | `/dpR8r13zWDeUR0QkzWidrdMxa56.jpg` | Explicit ad plan; TMDB reports offers under `flatrate` | Reject under current product scope. |
| 2100 | Amazon Prime Video with Ads | 203 | `/8aBqoNeGGr0oSA85iopgNZUOTOc.jpg` | Explicit ad plan; TMDB reports offers under `flatrate` | Reject under current product scope pending the Prime tier decision. |
| 1825 | HBO Max Amazon Channel | 11 | `/embS4GPK7c8pjbuY2O2irV5rYch.jpg` | Amazon add-on channel | Reject. |
| 201 | MUBI Amazon Channel | 88 | `/a4IDLKjvP5gvq7tNlg2Xw5YyEkI.jpg` | Amazon add-on channel | Reject. |
| 528 | AMC+ Amazon Channel | 29 | `/2ino0WmHA4GROB7NYKzT6PGqLcb.jpg` | Amazon add-on channel | Reject. |
| 607 | OUTtv Amazon Channel | 36 | `/d0KmcInHpiF44ahOLrXCQATEFmD.jpg` | Amazon add-on channel | Reject. |
| 608 | Love Nature Amazon Channel | 54 | `/bSy9zFiZtbKBHIyOu0H2Fs5cJmx.jpg` | Amazon add-on channel | Reject. |
| 684 | FlixOlé Amazon Channel | 40 | `/2GQVxfaiWA4n93I7sJDJf1b6NqS.jpg` | Amazon add-on channel | Reject. |
| 689 | TVCortos Amazon Channel | 320 | `/32R4lsqOPclNhb3qV613J8T8mdL.jpg` | Amazon add-on channel | Reject. |
| 1736 | Shadowz Amazon Channel | 60 | `/vBbNBDZnpnhgHe5ZO9CVur4DmkG.jpg` | Amazon add-on channel | Reject. |
| 1740 | Planet Horror Amazon Channel | 46 | `/yISpVXhf6axqiHh6lBvJ8RRrZ8v.jpg` | Amazon add-on channel | Reject. |
| 1741 | Dizi Amazon Channel | 45 | `/tM1HabyA45cnckBEhLS7hAVga5g.jpg` | Amazon add-on channel | Reject. |
| 1742 | Acontra Plus Amazon Channel | 48 | `/tGvAD4O9obFP3DfOrDn8NaRQ6eT.jpg` | Amazon add-on channel | Reject. |
| 1743 | Historia y Actualidad Amazon Channel | 49 | `/aJECXkHekrkuRZ7ABF5YR9DVDd8.jpg` | Amazon add-on channel | Reject. |
| 1968 | Crunchyroll Amazon Channel | 22 | `/pgjz7bzfBq4nFDu8JJDLBoUVAX8.jpg` | Amazon add-on channel | Reject. |
| 2141 | MGM Plus Amazon Channel | 37 | `/efu1Cqc63XrPBoreYnf2mn0Nizj.jpg` | Amazon add-on channel | Reject. |
| 2243 | Apple TV Amazon Channel | 216 | `/mHrYMgnZIp6lgW2aXg7ix9zGOnA.jpg` | Amazon add-on channel | Reject. |
| 2275 | Stingray Karaoke Amazon Channel | 220 | `/hhrxkhGheXYIxySqg4RcvO4tywc.jpg` | Amazon add-on channel | Reject. |
| 2358 | Lionsgate+ Amazon Channels | 67 | `/o4OqlMLb3ZjhK7OwR4qvxiZKOXf.jpg` | Amazon add-on channel | Reject. |
| 2561 | AMC Channels Amazon Channel | 82 | `/iaFj0Q4BVZQesLVfSyeHZhZHZhR.jpg` | Amazon add-on bundle | Reject. |
| 2735 | Animebox Channel Amazon Channel | 92 | `/wDQGu6bqoYCisi3m0bluxblNz0Y.jpg` | Amazon add-on channel | Reject. |

Provider names allow stores, explicit ad plans, and named Amazon channels to be
distinguished. The API does not return a semantic field such as
`base_subscription`, `store`, `add_on`, or `ad_supported`; the classification
above therefore combines exact names with live monetization controls. At the
time of research, Amazon Prime Video `119` and HBO Max `1899` remained
provisional pending owner review. Both were subsequently accepted for the
pilot; see section 15.

## 6. Coverage and sample size

| Provider | Discover total | Total pages | Pages observed | Candidates observed | Checks before deduplication | Languages | Decades | Genres | Sample popularity |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Netflix (`8`) | 6,624 | 332 | 5 | 100 | 20 | 10 | 5 | 18 | 14.674–69.912 |
| Amazon Prime Video (`119`) | 7,731 | 387 | 5 | 100 | 20 | 5 | 6 | 16 | 15.907–77.483 |
| Disney Plus (`337`) | 2,398 | 120 | 5 | 100 | 20 | 1 | 6 | 16 | 18.258–62.723 |
| HBO Max (`1899`) | 938 | 47 | 5 | 100 | 20 | 1 | 6 | 17 | 12.034–101.645 |
| Four-provider sample | — | — | 20 | 400 | 80 | 12 | 8 | 18 | 12.034–101.645 |

After deduplication, the sample contained 78 unique movies. Two movies were
sampled for more than one accepted provider, which is expected when catalogs
overlap. The minimum of 20 checks per provider and 40 unique movies was met.

The returned pools are quantitatively broad enough to supply more than three
candidates per provider and across the union. This does not establish that
three candidates will always meet taste, runtime, watched-state, and quality
constraints; recommendation plausibility and ranking were outside this spike.

The one-language Disney Plus and HBO Max sample reflects the selected
popularity pages after diversification, not a claim that those catalogs contain
only English-original movies.

## 7. Movie-level consistency

| Expected provider | Checks | Confirmed in `ES.flatrate` | Missing `ES` | Missing expected provider | Also in another category | Duplicate array entries |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Netflix (`8`) | 20 | 20 | 0 | 0 | 0 | 0 |
| Amazon Prime Video (`119`) | 20 | 20 | 0 | 0 | 0 | 0 |
| Disney Plus (`337`) | 20 | 20 | 0 | 0 | 0 | 0 |
| HBO Max (`1899`) | 20 | 20 | 0 | 0 | 0 | 0 |
| **Total** | **80** | **80** | **0** | **0** | **0** | **0** |

Within the bounded main sample, Discover and movie-level `ES.flatrate` data
were fully consistent. No mismatch category requires individual title
explanation because none occurred. The two cross-provider movie overlaps were
deduplicated only for the unique-movie count; both expected provider
associations were still checked.

This 100% result is evidence for the sample, not a guarantee for the complete
catalog. The negative filter-association control below shows why the movie-level
check remains mandatory.

## 8. Negative and ambiguous controls

| Control | Query/result | Movie-level evidence | Finding |
| --- | --- | --- | --- |
| Amazon store | `provider=10`, `rent|buy`; 15,283 results | *The Mandalorian and Grogu* (`1228710`): Amazon Video under both `rent` and `buy` | Store offers are distinct from subscription access. |
| Provider/monetization association | `provider=10`, `flatrate`; 9,304 results | *Proyecto Salvación* (`687163`): Amazon Video only under `rent` and `buy`; `flatrate` came from Amazon Prime Video `119`, MGM Plus Amazon Channel `2141`, and Amazon Prime Video with Ads `2100` | Discover does not prove that the requested provider supplies the requested monetization type. |
| Prime ads variant | `provider=2100`, `flatrate`; 7,717 results | *He-Man y los masters del universo* (`454639`): provider `2100` under `flatrate` | An explicitly ad-labelled plan can still be classified as `flatrate`; category alone cannot identify the selected entitlement. |
| Netflix ads variant | `provider=1796`, `flatrate`; 6,561 results | *Deseo* (`1668364`): provider `1796` under `flatrate` | Same ad-plan risk as Prime. |
| HBO Max add-on variant | `provider=1825`, `flatrate`; 882 results | *Mortal Kombat II* (`931285`): HBO Max Amazon Channel under `flatrate` | `flatrate` can represent a separately paid add-on channel. |
| Ad-supported offer | `provider=300`, `ads`; 69 results | *Ghost in the Shell* (`9323`): Pluto TV `300` under `ads` | `ads` is separately represented. |
| Free offer | `free`; 5,075 results | *Memoria de una madre* (`1567187`): Tivify `1838` under `free`, while unrelated providers also appeared under `flatrate` | `free` is separately represented and may coexist with subscription offers. |
| Unavailable in Spain | US Netflix `flatrate` candidate | *El quinto elemento* (`18`) had no `ES` watch-provider entry | Region omission is observable and must make a title ineligible for an `ES` recommendation. |

These controls exceed the five-control minimum and cover every non-subscription
monetization category in scope.

## 9. Combined-provider behavior

The official Discover documentation states that pipe-separated values are OR
and comma-separated values are AND. Live behavior matched that documentation:

| Expression | Documented meaning | Total results | Movie-level check |
| --- | --- | ---: | --- |
| `8|119|337|1899` | OR | 16,868 | 20/20 first-page movies had at least one accepted provider in `ES.flatrate`. |
| `8,119,337,1899` | AND | 0 | No movie was returned as common to all four. |
| `8,119` | AND | 241 | 10/10 checked first-page movies had both Netflix `8` and Amazon Prime Video `119` in `ES.flatrate`. |

For the four-service pilot union, the pipe syntax is the appropriate candidate
query. A comma query would require a title to be available on every selected
service and is not the product's intended eligibility rule.

The provider/monetization control still applies to either expression:
membership must be confirmed against each movie's `ES.flatrate` array.

## 10. Availability taxonomy

TMDB movie-level responses distinguish the following arrays:

| TMDB key | Observed meaning | Pilot treatment |
| --- | --- | --- |
| `flatrate` | Access associated with a subscription provider | Potentially eligible only when the exact provider ID is on the standalone allowlist. |
| `ads` | Ad-supported access | Excluded from the confirmed pilot entitlements; advertising is not a universal product exclusion. |
| `free` | Free access without a subscription payment | Excluded by current product scope. |
| `rent` | Time-limited transactional rental | Excluded. |
| `buy` | Transactional purchase | Excluded. |

The arrays make the five categories distinguishable without guessing from
prices. They do not make every offer's commercial role self-explanatory:

- explicit ad-plan providers `1796` and `2100` appeared under `flatrate`
- an Amazon add-on channel appeared under `flatrate`
- the provider list has no normalized role or tier field

Consequently, `flatrate` means subscription-shaped access in TMDB's taxonomy;
it does not by itself mean “included in one of PickOne's accepted base,
ad-free subscriptions.”

## 11. Attribution and linking

### TMDB

The TMDB FAQ requires:

- the approved TMDB logo to identify API use
- the notice: “This product uses the TMDB API but is not endorsed or certified
  by TMDB.”
- attribution in an About or Credits-style section
- logo usage that does not imply endorsement

It also distinguishes commercial from developer API use and directs commercial
projects to contact TMDB. The existing pilot attribution does not by itself
settle future commercial licensing.

### JustWatch

TMDB states that movie watch-provider data is powered by its JustWatch
partnership and that use of the endpoint requires attributing JustWatch as the
data source. The TMDB page does not prescribe final PickOne placement or copy
beyond that mandatory attribution, so those details remain for product/legal
review.

The direct JustWatch Content Partner API has different integration
requirements: a concluded contract, a partner token, and branded
country-specific links. PickOne does not have to call that API to use the TMDB
watch-provider endpoint, and this spike did not request a contract.

### Handoff

The TMDB movie response does not return full streaming-service deep links. It
does return a country-specific TMDB URL such as:

```text
https://www.themoviedb.org/movie/105-back-to-the-future/watch?locale=ES
```

TMDB documents that this URL can be used to reach the availability page and its
actual provider links. Therefore:

- supported now: open the returned TMDB `ES` watch page
- unsupported now: claim that the TMDB URL is a direct Netflix, Prime Video,
  Disney+, or HBO Max deep link
- unsupported now: construct a service URL from a title, provider ID, or logo
  path
- possible later: a direct JustWatch partner handoff after a separate agreement

## 12. Limitations and trust risks

### Observed evidence

- The primary sample was consistent at 80/80 checks, but it covered 78 movies,
  not the entire catalogs.
- Discover accepts provider and monetization filters simultaneously, but a
  result can satisfy them through different offers.
- Providers explicitly named “with Ads” can appear under `flatrate`.
- Add-on channel subscriptions can appear under `flatrate`.
- TMDB's provider list contains names, IDs, priorities, and logo paths, but no
  normalized store/base/add-on/ad-plan role.
- Movie watch-provider responses exposed `id`, country results, category
  arrays, provider identity, and `link`; no availability timestamp,
  last-updated field, confidence, or source-record age was observed.
- The reviewed TMDB documentation gives no freshness schedule or watch-provider
  SLA.
- No full provider deep link is returned.
- A movie can have no `ES` entry even when it is available in another country.
- Total-result metadata shows ample volume, but it does not measure
  recommendation quality or actual playability for a specific subscriber.

### Inferences and candidate risks

- Provider IDs and names may change as services rebrand or tiers change.
- Catalog entries can be stale, incomplete, or wrong even when the response is
  structurally consistent.
- Amazon Prime Video's generic and ads-labelled entries may not map cleanly to
  how pilot users understand their current Spanish Prime subscription.
- HBO Max `1899` appears to be TMDB's current standalone mapping, but provider
  identities and plan variants can still change.
- A provider page may still require authentication, app installation, or a
  separately eligible plan before playback.
- Without a freshness field, any cache duration is a PickOne policy decision,
  not a property supplied by TMDB.

PickOne can truthfully say that a movie is reported as included with a selected
service in Spain, subject to change and verification. It cannot truthfully
guarantee current playback entitlement or data freshness.

## 13. Implications for Onboarding v1

The following are candidate constraints for the later specification:

- Store stable TMDB provider IDs, not display names or priorities, for the four
  selected services.
- Display HBO Max using TMDB's current provider name while keeping provider IDs
  as the persisted identity.
- Present only the four supported services. Do not expose Amazon Video,
  ads-labelled plans, Amazon Channels, provider IDs, or other TMDB internals.
- Map the Product Owner's confirmed Netflix highest-plan and ad-free Prime Video
  entitlements internally; do not ask the pilot user to choose plan variants.
- Explain that availability is third-party, region-specific, and subject to
  change.
- Include an attribution path for TMDB and JustWatch.

No onboarding behavior is authorized by this research document. The accepted
post-spike product behavior lives in `PRODUCT.md`.

## 14. Implications for Availability & Eligibility v1

A later specification can use the following evidence-backed eligibility shape:

```text
eligible(movie, selectedProvider, region=ES)
    only if movie.watchProviders.results.ES exists
    and selectedProvider.id is in results.ES.flatrate
    and selectedProvider.id is in the approved standalone allowlist
```

Candidate generation may use:

```text
watch_region=ES
with_watch_providers=<selected IDs joined by "|">
with_watch_monetization_types=flatrate
```

It must not treat that Discover response as final proof. Missing region,
missing `flatrate`, a non-allowlisted provider, or an unsupported monetization
category should fail closed for primary recommendation eligibility.

Because TMDB supplies no freshness value, revalidation and caching remain
PickOne policy decisions rather than source guarantees. The Product Owner and
CTO accepted a policy after this research; see section 15.

The returned TMDB watch link is suitable for an honest fallback handoff. Direct
service links require separately supported data.

## 15. Post-spike product decisions

After reviewing the evidence, the Product Owner and CTO accepted the following
pilot decisions on 2026-07-29. `PRODUCT.md` remains the canonical authority:

1. The Spain allowlist is Netflix `8`, Amazon Prime Video `119`, Disney Plus
   `337`, and HBO Max `1899`.
2. HBO Max is the user-facing name for provider `1899`.
3. The Product Owner's Netflix highest plan maps to `8`, and ad-free Prime Video
   maps to `119`. The ad-labelled variants are not selected pilot entitlements.
4. Advertising is not a universal product exclusion. Eligibility depends on
   whether the exact provider represents the selected included entitlement.
5. Onboarding shows supported services, not TMDB IDs or plan variants. The
   confirmed pilot entitlements are mapped internally.
6. Availability is verified when a recommendation set is generated and
   revalidated before handoff when the previous verification is more than
   24 hours old.
7. The country-specific TMDB watch page is accepted as the pilot fallback
   handoff and must not be presented as a direct provider link.
8. Availability copy identifies JustWatch as the source, states that
   availability may change, and preserves required TMDB attribution.

These decisions accept the constrained TMDB path for the pilot; they do not
alter the dated API observations recorded by the spike.

## 16. Remaining questions

1. What exact caveat copy should distinguish reported availability from
   guaranteed playback without undermining the decision experience?
2. Where and how should JustWatch attribution appear alongside the existing
   TMDB About/Credits attribution?
3. Before commercial distribution, does PickOne require a commercial TMDB
   agreement or a direct JustWatch partner agreement?

No research question depends on broadening into TV, another country, an
unofficial endpoint, or application code.

## 17. Recommended next step

The required provider, entitlement, freshness, and handoff decisions now live
in product authority. The team can specify `Availability Foundation v1`,
followed by `Viewer Profile & Onboarding v1`. The exact caveat and attribution
presentation must be resolved in the availability specification before its
user interface is implemented.

This spike implements neither capability.

## Appendix A. Research-question traceability

| Question | Answer |
| --- | --- |
| 1. Current IDs/names | Resolved in section 5: `8`, `119`, `337`, `1899`. |
| 2. Separate or ambiguous entries | Yes; store, ads plans, Amazon Channels, and HBO Max Amazon Channel are listed in section 5. |
| 3. Base-subscription entries | Four standalone entries identified and subsequently accepted for the pilot; section 15. |
| 4. Region + provider + `flatrate` Discover | Parameters can be sent together, but the checked Amazon control proves they are not offer-bound. |
| 5. Discover/movie-level consistency | 80/80 primary checks confirmed; section 7. |
| 6. Monetization distinction | Arrays distinguish all five categories, with the `flatrate` role caveat; sections 8 and 10. |
| 7. Multiple-provider semantics | Pipe OR and comma AND documented and observed; section 9. |
| 8. Coverage for three candidates | Returned pools are far above three per provider; quality constraints remain untested; section 6. |
| 9. Inconsistencies and false positives | No primary-sample mismatch; independent-filter false positive and variant risks observed; sections 7 and 8. |
| 10. Freshness | No timestamp, age, confidence, schedule, or watch-provider SLA found; section 12. |
| 11. Truthful promise | “Reported included in Spain, subject to change and verification,” not guaranteed entitlement; section 12. |
| 12. Attribution | TMDB logo/notice and JustWatch source attribution required; section 11. |
| 13. Link type | Country-specific TMDB watch page, not a direct service deep link; section 11. |
| 14. User handoff | Open the returned TMDB URL; do not manufacture a provider URL; section 11. |
