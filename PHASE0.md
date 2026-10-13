# Phase 0: source findings (incomplete, blocked)

Status: **not signed off. Sources could not be verified from the build environment.**

The cloud environment's network policy rejects connections to every source host
(`www.etenders.gov.ie`, `api.ted.europa.eu`, `docs.ted.europa.eu`, `data.gov.ie`).
Web search does not index the eTenders T&Cs, its robots.txt, the TED field list or the CSV
header, so nothing below counts as verified unless marked so.

## What is known

| Source | Status | Confirmed | Unconfirmed |
|---|---|---|---|
| eTenders listings | Blocked | Nothing | robots.txt, T&Cs on automated access, listing columns, pagination, detail page fields |
| TED Search API | Blocked | Expert search exists on TED, and the search fields are documented in TED Developer Docs (op.europa.eu, ted.europa.eu) | Endpoint (`POST /v3/notices/search` from memory), `buyer-country=IRL` syntax, field names, rate limits |
| OGP CSV | Blocked | On data.gov.ie, published by the OGP, CC BY 4.0, updated **quarterly**, hosted on assets.gov.ie, covers notices, awards, procedures and supplier info (data.gov.ie search snippet) | Column names, whether the winner and award value are populated |
| Email fallback | Not tested | n/a | Needs a dedicated inbox and live eTenders alerts first |

### Discrepancy to check
The search snippet of the dataset page says the CSV covers **1 Jan 2013 to 30 Sep 2025**. The brief says
it runs to mid-2026. The snippet may be stale, but if it isn't, award data lags by about a year, not a few months.
That affects how useful buyer history is for recent competitions. Low confidence either way until the file is opened.

## To unblock

Add these hosts to the environment's allowed domains (environment settings → Network access, see
https://code.claude.com/docs/en/cloud-environments#network-access):

- `www.etenders.gov.ie`
- `api.ted.europa.eu`, `docs.ted.europa.eu`
- `data.gov.ie`, `assets.gov.ie`

Alternatively run `scripts/phase0-probe.sh` on your own machine (set `UA` to include a contact email) and
commit `fixtures/phase0/` except the full CSV. It:

1. fetches the eTenders robots.txt and T&Cs, then **pauses** so they can be read before any listing page is touched;
2. fetches one listing page of each type and one detail page, 5 s apart;
3. runs one TED query for Irish buyers over the last 7 days;
4. pulls the OGP dataset metadata and CSV, then prints the column list.

These responses double as the offline fixtures for the adapter tests later.

## Stack recommendation (for sign-off alongside the sources)

**Node 22 + TypeScript** for ingest and jobs. Reasons: the TED API is JSON, the official Anthropic SDK with
structured output is TypeScript-first, esbuild is already in the frontend toolchain so one `package.json`
covers both, and `better-sqlite3` is synchronous and fast for a single-user SQLite app. PHP 8 would match
the studio stack for templating, but it would need a second toolchain for the JS build and has weaker
Anthropic SDK support. Server-rendered pages with Fastify + a plain template engine (Eta), Alpine.js and SCSS
stay within the brief's "no React" rule.

## Next steps once sources are verified
1. Fill in this note with real fields, freshness and terms per source; you agree which ones to use.
2. Propose the data model and file structure.
3. Build.
