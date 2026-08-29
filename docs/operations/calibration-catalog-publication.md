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
- [ ] `GET` returns `200` with `Content-Type: application/json`; a missing
      document returns a definitive `404`.
- [ ] Cache-Control metadata and any required invalidation are recorded.
- [ ] The endpoint serves the exact approved digest and stays below 64 KiB.

## Post-publication evidence

- [ ] Download the document from the configured pilot endpoint and record its
      SHA-256 digest.
- [ ] Confirm the downloaded bytes pass the same schema and invariant tests.
- [ ] Confirm remote, cached, and bundled resolution paths on the accepted
      region `ES` and locale `es-ES`.
- [ ] Record rollback verification and the approver in the Milestone 7 closure
      evidence owned by PR10.
