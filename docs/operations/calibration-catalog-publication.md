# Calibration Catalog Publication Checklist

## Status

Operational checklist for Milestone 7 catalog publications. External
infrastructure provisioning and mutation require separate Product Owner
authorization.

## Publication artifact

The initial pilot document is the exact tracked file at
`PickOne/Resources/CalibrationCatalog/calibration-catalog-es-ES-v1.json`.
It mirrors `CalibrationCatalog.spainHouseholdV1` and is also the bundled offline
fallback. Do not edit the published object independently from this artifact.

Initial proposed artifact SHA-256:
`c451c0752fd99988eede317067344cbe7f31137c9aa84164b282318bb6292eac`.
Recompute and record a new digest after any approved change; publication must
use the exact bytes whose digest was approved.

## Accepted pilot publication contract

The pilot publishes the current catalog at the stable object and CloudFront
path `/catalogs/ES/es-ES/calibration.json`. Publication must not introduce a
version-specific public path or invalidate a wider CloudFront path.

The approved target response metadata is exactly:
`Cache-Control: public, max-age=0, s-maxage=300, must-revalidate`. The pilot
infrastructure has not been deployed yet; publication must configure this value
rather than treat it as observed evidence. The CloudFront cache policy must use
`MinimumTTL = 0` and `MaximumTTL >= 300` so it does not override the approved
origin directive.

Catalog JSON `version` values are strictly monotonic. Every publication must
use a value higher than every version previously exposed at the stable path.
A rollback is therefore a roll-forward publication: republish the approved
content of an earlier object with a new higher `version` and a new `updatedAt`.
S3 Versioning preserves recovery material, but restoring an older S3 object
version must never expose its lower catalog `version` at the stable path again.

## Approval and validation

- [ ] Product Owner approved the complete movie IDs, order, blocks, fallback
      titles, years, languages, region, locale, and version.
- [ ] The document passes `CalibrationCatalogDocumentTests` and the complete
      repository verification gate.
- [ ] `schemaVersion` remains supported and `version` is incremented for every
      content or ordering change.
- [ ] The SHA-256 digest of the exact proposed bytes is recorded in the release
      evidence before upload.
- [ ] The previous published object remains recoverable through host versioning
      or an equivalent rollback mechanism.

## Endpoint controls

- [ ] The endpoint is read-only HTTPS and requires no client credential,
      signature, cookie, Viewer state, or request body.
- [ ] Redirects remain on the configured HTTPS host and port.
- [ ] The public object path is exactly
      `/catalogs/ES/es-ES/calibration.json`.
- [ ] `GET` returns `200` with `Content-Type: application/json`; a missing
      document returns a definitive `404`.
- [ ] The response contains exactly
      `Cache-Control: public, max-age=0, s-maxage=300, must-revalidate`.
- [ ] The CloudFront cache policy uses `MinimumTTL = 0` and
      `MaximumTTL >= 300`.
- [ ] Any CloudFront invalidation names only
      `/catalogs/ES/es-ES/calibration.json`; no wildcard or parent path is
      invalidated.
- [ ] The endpoint serves the exact approved digest and stays below 64 KiB.
- [ ] The document `version` is higher than every version previously published
      at the stable path.

## Post-publication evidence

- [ ] Download the document from the configured pilot endpoint and record its
      SHA-256 digest.
- [ ] Confirm the downloaded bytes pass the same schema and invariant tests.
- [ ] Confirm the downloaded `version` and `updatedAt` match the approved
      roll-forward artifact, including after rollback.
- [ ] Confirm remote, cached, and bundled resolution paths on the accepted
      region `ES` and locale `es-ES`.
- [ ] Record rollback verification and the approver in the Milestone 7 closure
      evidence owned by PR10.
