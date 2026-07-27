# Two-Person Pilot Checklist

## Outcome

Status: Basic pilot passed on both target iPhones.

The initial installation and product smoke validation succeeded. The unchecked
items below remain as the reusable exhaustive regression checklist for later
builds; they are not required to reopen Milestone 3.3.

Run this checklist on both iPhones for the first build and again after installing
a replacement build over it.

## Installation and launch

- [ ] `PickOne Pilot` installs from Xcode
- [ ] the temporary icon and display name are visible
- [ ] the app launches without a configuration crash
- [ ] About shows version/build and TMDB attribution

## Core flows

- [ ] Discover loads movies and images
- [ ] Search finds a movie by title
- [ ] Detail opens and handles partial network failure
- [ ] Ask accepts a prompt and opens a recommendation
- [ ] Watchlist add, remove, and watched status work
- [ ] watchlist data survives force-quit and relaunch

## Degradation and update

- [ ] airplane mode produces recoverable UI instead of a crash
- [ ] reconnecting and retrying recovers
- [ ] a newer build installs over the old build
- [ ] watchlist data survives the replacement installation

## Session note

For each real “what should we watch?” session, record:

- date and person
- intended task or prompt
- point of confusion, abandonment, or error
- whether a movie was ultimately selected
- spontaneous observation

These notes detect friction and severe defects. They are not treated as
quantitative product validation.
