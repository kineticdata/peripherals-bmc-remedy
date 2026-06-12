# PR title

ARS REST v2 adapter: aggregate paged requests for limits over 1000 (v2.1.0)

# PR body (copy below this line)

## Summary

The v2 adapter capped every `search()` at 1000 records (`addLimit()` clamp + single HTTP request), with no way for consumers that cannot drive pagination (form dropdowns, typeaheads, tag pickers) to retrieve larger result sets.

- **Opt-in aggregation:** a qualification `limit` parameter greater than 1000 is now treated as the *total records desired*; the adapter internally loops the ARS REST `offset`/`limit` paging in chunks of 1000 and concatenates the results into one response. `limit` absent or <= 1000 is byte-compatible with prior behavior (single request).
- **New optional `Max Records` config property (default 10000):** hard ceiling on aggregated totals per call, protecting agent/core memory. When the ceiling cuts results short, a `truncated` indicator is set on the response metadata and a warning is logged.
- **`count()` now returns a true count** by paging through results (bounded by Max Records), instead of returning the size of a single server-default page.
- **Server-cap resilience:** while aggregating, a partial-but-nonzero page does not end the loop (ARS servers configured with a max-entries setting below 1000 silently return short pages); only an empty page, the requested limit, or the ceiling stops aggregation.

## Bug fixes (in the touched code paths)

- `ArsRestV2ApiHelper.executeRequest`: `tries++` passed 0 forever, causing infinite recursion / StackOverflow on persistent 401. Now retries once with a fresh token, then errors cleanly.
- `search()`: the sort-by-`order`-metadata branch ran *after* `metadata.clear()` and was unreachable. Order metadata now applies a sort.
- `setOffset()`: next-page offset was computed as `offset + limit + 1`, silently skipping one record per page in consumer-driven paging. Now advances by records actually returned.
- `pathAdhoc()`: removed a spurious `adapterPath=...` query parameter that was serialized onto every Adhoc request URL.

## Notes

- When aggregating without an explicit `sort` in the qualification, the adapter logs a WARN: offset paging relies on the ARS server's default ordering. The README recommends adding e.g. `sort=Request ID.asc`. A sort field is deliberately not injected because field names vary by form.
- V1 adapter (deprecated) untouched.

## Testing

- New `ArsRestV2AggregationTest` (13 unit tests, stubbed API helper, no live server): multi-page aggregation, exhaustion, ceiling truncation, initial offset, server-capped pages, order-metadata sort, Adhoc aggregation, count paging, limit parsing edge cases.
- `ArsRestV2Test.test_setOffset` updated to the corrected offset semantics (it previously asserted the off-by-one).
- Full suite green on `maven:3.6-jdk-8` (canonical builder image) **and** `maven:3.8-openjdk-11`: 17/17 pass on both. Artifact targets Java 8 bytecode, so it runs on JDK 8 and 11 agents.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
