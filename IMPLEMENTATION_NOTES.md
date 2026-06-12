# ARS REST v2 Bridge Adapter — Record Aggregation (v2.1.0)

**Repo:** `kineticdata/peripherals-bmc-remedy` · **Branch:** `feature/ars-rest-aggregate-limit` · **Module:** `bridge-adapters/kinetic-bridgehub-adapter-ars-rest`

## The problem

The ARS REST v2 bridge adapter (`ArsRestV2Adapter`) could never return more than 1000 records. Every `search()` made exactly one HTTP GET to Remedy's REST API, and a method called `addLimit()` clamped the `limit` query parameter to a maximum of 1000 before the request was sent. Any qualification matching more rows was silently truncated — no error, no indicator.

The standard answer would be pagination, but our consumers are bridge-backed UI elements (dropdowns, search fields, tag pickers) that make a single bridge call and cannot drive page-by-page requests. So the adapter itself has to do the paging.

## The design

**Opt-in aggregation, signaled by the `limit` parameter.** The meaning of `limit` in a qualification changed slightly:

| Qualification | Behavior |
|---|---|
| no `limit`, or `limit` ≤ 1000 | Exactly as before: one HTTP request, identical URL to v2.0.3 |
| `limit` > 1000 | Treated as **total records desired**. The adapter internally loops Remedy's server-side `offset`/`limit` paging in chunks of 1000 and concatenates all pages into one bridge response |

Backward compatibility was the controlling constraint: existing bridge models never send `limit > 1000` (it used to be clamped), so no deployed behavior changes unless someone explicitly asks for more.

**A safety ceiling: the `Max Records` bridge property.** Aggregation materializes every record in the Bridgehub agent's JVM heap (the adapter has no streaming path), so unbounded aggregation is an OOM risk. A new *optional* bridge configuration property, `Max Records` (default **10000**), caps the total per call. When the ceiling cuts a result set short, the response metadata includes `truncated: "true"` and a WARN is logged. Misconfigured values (non-numeric, < 1) fail at bridge save time, not query time.

### How the loop works (`aggregateEntries`)

All three request paths (`search`, `count`) now funnel through one new protected method:

```
totalLimit  = min(requestedLimit, maxRecords)
aggregating = requestedLimit > 1000
offset      = offset param from the qualification, else 0

do {
    chunk = min(1000, totalLimit - collected so far)
    set limit=chunk (and offset, except on the first request) in the query params
    GET {origin}/api/arsys/v1{path}?{params}
    append response "entries" to the accumulator
    offset += number of entries actually returned
} while (not exhausted AND collected < totalLimit)
```

Worked example — qualification `limit=2500`, 2500+ matching rows:

1. `GET ...?limit=1000` → 1000 entries
2. `GET ...?limit=1000&offset=1000` → 1000 entries
3. `GET ...?limit=500&offset=2000` → 500 entries → done, one `RecordList` of 2500

Two subtleties worth understanding:

- **Termination is "empty page", not "partial page."** ARS admins can configure *Maximum Entries Returned by GetList* below 1000, in which case the server silently returns short pages even though more rows exist. If we treated a partial page as "no more results," aggregation would stop after one page on those servers. So while aggregating, the loop only stops on a **zero-entry page**, the requested total, or the ceiling. Offsets advance by the count *actually returned*, so a server capped at 500 simply produces clean 500-row strides. Cost: one extra (cheap, empty) request when an aggregated query genuinely exhausts its results. Non-aggregated calls keep the old single-request behavior exactly.
- **The path is built once, outside the loop.** The structure-to-URL path builders mutate the parameter map (`pathEntry` consumes `entry_id`, `pathAdhoc` consumes `adapterPath`), so they must not be re-invoked per page. Only the query string is rebuilt each iteration.

### `count()` is now a real count

Previously `count()` sent no `limit` at all and returned the size of whatever single page the server's default settings produced — not the number of matching records. It now uses the same aggregation loop (precedent: the kineticcore adapter's `count()`, which loops `nextPageToken` the same way) and returns the true total, bounded by `Max Records`, with the same `truncated` indicator. A `limit` in the qualification caps the count if you want the old cheapness.

### Sort and ordering — the one caveat

Offset paging is only strictly correct against a stable sort order. The adapter does **not** inject a sort field (field names vary per Remedy form — a wrong guess like `Request ID` would 500 on forms that name field 1 differently). Instead it:

- logs a WARN when aggregating without an explicit `sort` parameter, and
- documents the recommendation to add one (e.g. `sort=Request ID.asc`) in the README.

Without a sort, paging relies on the ARS server's default ordering (entry-ID), which is normally stable — but be deliberate about this on large pulls.

## Bug fixes included (all in the touched code paths)

1. **Infinite 401 retry recursion** (`ArsRestV2ApiHelper.executeRequest`): the token-refresh retry called `executeRequest(url, tries++)` — post-increment passes the *old* value, so `tries` stayed 0 forever and a persistently-401 resource recursed to StackOverflow. Now `tries + 1`: one refresh-and-retry, then a clean `BridgeError`. This mattered more once multi-page loops raised the odds of a JWT expiring mid-aggregation.
2. **Dead sort-by-metadata code** (`search()`): the check for `order` metadata ran *after* `metadata.clear()`, so platform-supplied order metadata could never produce a sort. The order value is now captured before the clear. (Behavior change: bridges that set `order` metadata will now actually sort.)
3. **Pagination off-by-one** (`setOffset()`): the next-page offset was computed as `offset + limit + 1`, which skipped one record at every page boundary for consumer-driven paging. It now advances by the number of records actually returned. New signature: `setOffset(metadata, initialOffset, returnedCount)`.
4. **Spurious query param on Adhoc requests** (`pathAdhoc()`): the internal `adapterPath` map entry was left in the parameter map and serialized onto every Adhoc URL (`...&adapterPath=/entry/Foo`). It's now removed when the path is built.

## Response metadata contract

| Key | Meaning |
|---|---|
| `offset` | Next offset for a consumer that *can* page: `initialOffset + recordsReturned` (corrected by fix #3). Set whenever records were returned. |
| `truncated` | `"true"` only when the `Max Records` ceiling stopped aggregation with (potentially) more rows on the server. Absent otherwise. |

## What was deliberately NOT changed

- **V1 adapter** (`ArsRestAdapter`) — deprecated, untouched.
- **`retrieve()`** — single-record semantics, no paging needed.
- No forced sort injection (see caveat above).
- The per-request chunk stays 1000 — aggregation loops around the per-request limit; it doesn't ask Remedy for bigger pages.

## Testing

- **New `ArsRestV2AggregationTest`** — 13 unit tests, no live Remedy needed. A stub subclass of `ArsRestV2ApiHelper` (injected via a package-private field) records every request URL and replays queued JSON pages. Covers: single-page default, ≤1000 never loops, multi-page aggregation with correct offsets, exhaustion on empty page, ceiling truncation, initial-offset handling, server-capped short pages, order-metadata sort (proves fix #2), Adhoc aggregation with clean URLs, count paging, count truncation, single-entry `values` responses, and `limit` parsing edge cases (negative, non-numeric, whitespace, >ceiling).
- **`ArsRestV2Test.test_setOffset`** updated — it previously asserted the off-by-one values.
- **Results:** 17/17 green on `maven:3.6-jdk-8` (the project's canonical builder image) **and** `maven:3.8-openjdk-11`. The artifact compiles to Java 8 bytecode (`source/target 1.8`), so it runs on JDK 8 and JDK 11 agents alike.
- ⚠️ The pom sets surefire `testFailureIgnore=true` — a green build does **not** prove green tests. Check `target/surefire-reports/`.

## Building / deploying

```powershell
docker run --rm `
  -v "<path-to>\kinetic-bridgehub-adapter-ars-rest:/project" `
  -v ars-rest-m2:/root/.m2 -w /project `
  maven:3.6-jdk-8 mvn clean package "-Dtest=ArsRest_HelperMethodTest,ArsRestV2AggregationTest" "-DfailIfNoTests=false"
```

Produces `target/kinetic-bridgehub-adapter-ars-rest-2.1.0.jar`. Drop it into the Bridgehub/agent adapter directory as usual. Existing bridges keep working with no config changes; to enable >1000 results on a bridge model, put `limit=<total>` in the qualification mapping and optionally set `Max Records` on the bridge config (raise the agent JVM heap if you raise the ceiling significantly).

## Using it from a bridge model (example)

```
Structure:                Entry > CTM:People
Qualification (search):   q='Profile Status'="Enabled"&limit=5000&sort=Request ID.asc
```

Returns up to 5000 people in one bridge response (5 internal requests), `truncated=true` in metadata if the 10000 default ceiling ever bites (it won't here), and a stable order for the paging.
