# Observability Signals Design

Date: 2026-05-19
Topic: observability signals target-state specification
Audience: platform engineers, SREs, operations-focused developers maintaining DevFlow observability standards

## Purpose

This design adds a new `observability/signals/` documentation subtree to define the target-state signal specification for DevFlow. The goal is to describe, in operational detail, which fields belong in metrics, logs, and traces; which fields are mandatory versus optional; which fields are framework-generated versus service-written; and which fields must be enriched by Prometheus, OpenTelemetry SDKs, or the OpenTelemetry Collector.

This is a platform-target document set, not a point-in-time implementation report. It defines the intended steady state for DevFlow observability so platform and service teams can converge on one ownership model.

## Reader And Post-Read Action

Reader:
- Platform engineers responsible for observability standards
- SRE / operations developers validating telemetry ownership boundaries
- Service maintainers implementing telemetry in DevFlow services

Post-read action:
- A reader should be able to decide, for any telemetry field in DevFlow, whether it belongs in metrics, logs, or traces; whether it is required; and which layer is responsible for producing it.

## Scope

In scope:
- A new `content/docs/observability/signals/` directory
- A signal-oriented specification structure for `metrics`, `logs`, and `traces`
- A dedicated `http` mapping page that breaks down HTTP access logs, HTTP error logs, HTTP metrics, and HTTP trace attributes
- Ownership boundaries across:
  - framework / middleware generated fields
  - service-written business fields
  - SDK-populated attributes
  - OTel Collector enrichment
  - Prometheus scrape and target metadata
- Required fields, optional fields, recommended fields, and explicit anti-patterns
- Validation-oriented checklists for platform adoption

Out of scope:
- Rewriting the full existing `contracts/` subtree
- Changing application code, middleware, or Collector config in this task
- Declaring current implementation completeness service by service
- Providing language-specific code samples as the primary artifact

## Proposed Documentation Structure

Add the following files:

- `content/docs/observability/signals/_index.md`
- `content/docs/observability/signals/http.md`
- `content/docs/observability/signals/metrics.md`
- `content/docs/observability/signals/logs.md`
- `content/docs/observability/signals/traces.md`

Also update existing entry points:

- `content/docs/observability/_index.md`
  - Add a new section linking to the signal-oriented specification
- Existing contract pages are not a required integration point in this task; the primary integration point is the observability index page

## Information Architecture

### Why Organize By Signal

The chosen structure is signal-first:

- `metrics`
- `logs`
- `traces`
- `http` as a cross-signal mapping page

This is preferred over an ownership-first structure because operational readers usually start from the signal they are debugging or standardizing. A platform engineer auditing HTTP access logs should not need to reconstruct the answer by navigating across service-owned, framework-owned, and Collector-owned pages.

### Why Add A Dedicated HTTP Page

HTTP telemetry cuts across all three signals and is the most common operational entry point. The `http.md` page exists to answer detailed questions such as:

- What fields must exist in an HTTP access log?
- Which of those fields come from middleware versus service code?
- Which HTTP labels are legal in metrics?
- What is the exact mapping between access log fields, HTTP metric labels, and trace/span attributes?

Without a dedicated page, these answers would be fragmented across three signal pages and become harder to operationalize.

## Page Responsibilities

### `signals/_index.md`

Responsibilities:
- Define the purpose of the subtree
- State that this is the target-state platform specification
- Define common ownership layers
- Provide reading order
- Direct readers to the right page depending on whether they are standardizing HTTP telemetry, logs, metrics, or traces

Key sections:
- Who this is for
- What this subtree defines
- Ownership model
- Reading map

### `signals/http.md`

Responsibilities:
- Define HTTP telemetry across all three signals
- Specify HTTP access log fields in detail
- Specify HTTP error log additions
- Specify HTTP server metric labels
- Specify HTTP trace / span attributes
- Provide a mapping table across signals

Key sections:
- HTTP telemetry goals
- HTTP access log required fields
- HTTP access log optional fields
- HTTP error log additional fields
- HTTP metrics label set
- HTTP trace attribute set
- Cross-signal field mapping
- HTTP anti-patterns
- HTTP validation checklist

This page must be detailed enough to answer field-level questions such as whether `url.path` belongs in logs, whether `trace_id` can appear in metrics labels, and whether `caller` belongs in access logs or only selected error-oriented logs.

### `signals/metrics.md`

Responsibilities:
- Define target-state metric ownership and field rules
- Separate high-frequency HTTP metrics from lower-frequency business and platform metrics
- Define required versus optional labels
- Define Prometheus and OTel ownership boundaries
- Define prohibited label patterns

Key sections:
- What metrics are for
- Required labels
- Optional labels
- Framework / library generated metric dimensions
- Service-written business metric dimensions
- Prometheus / target metadata ownership
- Collector / spanmetrics derived metrics guidance
- Prohibited high-cardinality labels
- Validation checklist

### `signals/logs.md`

Responsibilities:
- Define target-state log schema and ownership
- Split logs into operational categories with different field expectations
- Specify required fields for:
  - HTTP access logs
  - HTTP error logs
  - business event logs
  - lifecycle / mutation logs
- Define which fields must be carried for trace correlation
- Define which fields should not become Loki labels

Key sections:
- What logs are for
- Shared base log schema
- HTTP access logs
- HTTP error logs
- business event logs
- lifecycle / mutation logs
- Ownership matrix
- Loki label restrictions
- Anti-patterns
- Validation checklist

This page should be the most detailed of the set because operations and platform teams commonly need exact log field requirements, especially around HTTP access and release lifecycle logs.

### `signals/traces.md`

Responsibilities:
- Define span and resource expectations for target-state tracing
- Separate root span, internal span, downstream client span, and async / callback span expectations
- Define required resource attributes and Collector-enriched fields
- Define which business identifiers must be attached at which stage in a release chain

Key sections:
- What traces are for
- Root span required fields
- Internal span guidance
- Downstream client span guidance
- Async / background / callback span guidance
- Resource attributes
- Collector enrichment fields
- Release and runtime special context
- Anti-patterns
- Validation checklist

## Ownership Model

Every signal page will use the same five-layer ownership model:

1. Framework or middleware generated
2. Service explicitly written
3. SDK-generated or SDK-propagated
4. Platform-enriched by OTel Collector
5. Platform metadata provided by Prometheus scrape target labels or discovery metadata

This model is central to the new subtree. The docs should repeatedly answer not just "what is the field" but "who owns producing it."

## Detail Level Requirements

The pages must be detailed, not just conceptual.

Minimum detail standard:
- Each page contains field-level tables
- Each important field documents:
  - field name
  - whether it is required
  - ownership source
  - signal position
  - example value
  - notes or restrictions
- HTTP access logs receive their own detailed field breakdown
- Anti-pattern tables explicitly call out invalid placements such as:
  - `trace_id` as a high-frequency metric label
  - `k8s.pod.name` manually hardcoded in service code
  - raw `url.path` used as a metric label
  - logs without `trace_id` and `span_id`
  - traces that capture external dependencies but omit DevFlow internal stage spans

## Relationship To Existing Contracts

The existing `contracts/` pages remain useful for:
- common terminology
- current cross-signal contract framing
- existing attribute and logging guidance

The new `signals/` subtree should not duplicate them mechanically. Instead:
- `contracts/` remains the general contract layer
- `signals/` becomes the target-state operational specification layer

This avoids replacing or destabilizing the existing structure while still giving platform readers a more actionable source of truth.

## Writing Style

The docs should read like platform standards, not tutorials.

Writing rules:
- Prioritize normative language over exploratory language
- Prefer tables, responsibilities, and validation criteria
- Keep examples concrete and operational
- Avoid language-specific implementation walkthroughs except where a small example is necessary to clarify ownership
- State when a field is forbidden in a given signal class

## Testing And Validation

The implementation should be validated by:

1. Content review
   - No placeholder text
   - No contradictory ownership claims
   - No ambiguity about required versus optional fields

2. Structural review
   - New pages are discoverable from the observability index
   - Pages do not become orphaned

3. Build validation
   - `hugo --minify` completes successfully

## Risks

### Risk: conflict with existing contract pages

Mitigation:
- Position the new subtree as target-state signal documentation
- Keep existing contract pages intact
- Link rather than overwrite

### Risk: over-specifying fields that current services do not yet emit

Mitigation:
- Explicitly describe the subtree as a target-state platform standard
- Avoid wording that implies universal current implementation

### Risk: pages become repetitive

Mitigation:
- Reuse a consistent page template
- Use the `http` page as the deep cross-signal drilldown rather than repeating the same explanations everywhere

## Recommended Implementation Approach

Recommended approach:
- Create the new `signals/` subtree
- Start with the index page and the `http` page because they define the operational reading model
- Then write the `metrics`, `logs`, and `traces` pages using a consistent structure
- Finally wire the subtree into the main observability index

Alternative approaches considered:

1. Add all new content into existing `contracts/` pages
   - Rejected because it would blur the distinction between generic contract guidance and target-state signal ownership standards

2. Organize by ownership source instead of signal
   - Rejected because operations readers typically enter by signal, not by producer layer

3. Write one large matrix page only
   - Rejected because it would be harder to maintain and too dense for detailed HTTP access log guidance

## Final Recommendation

Proceed with a signal-first subtree under `content/docs/observability/signals/`, with a dedicated `http.md` page and detailed operational specifications for `metrics`, `logs`, and `traces`.

This structure best matches the needs of an operations and platform audience, preserves the current contract pages, and gives DevFlow a clear target-state source of truth for telemetry ownership and field requirements.
