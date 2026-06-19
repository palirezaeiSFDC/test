---
name: sf-integration-patterns-skill
description: >-
  Enterprise integration patterns, data architecture, and large data volume (LDV)
  design knowledge for Salesforce architects. Covers integration pattern selection,
  Salesforce-specific integration mechanisms (Platform Events, CDC, REST, Bulk API,
  Streaming API, MuleSoft), data migration strategies, LDV query optimization,
  async processing patterns for scale, and performance architecture. Use when
  designing integrations, assessing data volume risks, optimizing performance,
  or selecting async patterns.
---

# Salesforce Integration Patterns & LDV Architecture

## Quick Start

Apply this skill when the user mentions: integration, REST API, SOAP, Platform Events, Change Data Capture, Streaming API, Bulk API, MuleSoft, ETL, data migration, large data volume, LDV, performance, query optimization, skinny table, custom index, Batch Apex scaling, async pattern selection, event-driven, real-time vs batch.

**Supporting references:**
- [integration-reference.md](integration-reference.md) — integration mechanism comparison tables, protocol details, governor limits
- [ldv-performance-reference.md](ldv-performance-reference.md) — LDV patterns, query optimization, async scaling, platform cache

---

## Integration Pattern Selection

### Architectural Patterns (Technology-Agnostic)

| Pattern | Description | Best For |
|---|---|---|
| **Point-to-Point** | Direct system-to-system connection | Simple, 2-system, low-change scenarios |
| **Hub-and-Spoke (ESB)** | Central integration bus routes messages | Many systems, enterprise-wide; requires ESB (e.g., MuleSoft) |
| **Event-Driven (EDA)** | Producers publish events; consumers subscribe independently | Decoupled, async, high-volume, real-time flows |
| **Batch ETL** | Scheduled bulk data transfer | High-volume, non-real-time, reporting, migration |
| **Request-Reply (Synchronous)** | Caller waits for response | Real-time reads, validations, immediate confirmation |
| **Publish-Subscribe** | Publisher unaware of consumers | One-to-many notifications, CDC, audit |

**Decision rule:** Prefer Event-Driven when the source system cannot wait for Salesforce processing. Prefer Request-Reply only when immediate confirmation is required. Avoid Point-to-Point when more than 2 systems are involved — use a hub or event bus.

### Salesforce Integration Mechanisms

See [integration-reference.md](integration-reference.md) for full comparison table.

#### Inbound to Salesforce

| Mechanism | Protocol | Latency | Volume | Use When |
|---|---|---|---|---|
| REST API (standard) | HTTPS/JSON | Low | Up to 5MB/request | External system pushes single/small batch records to Salesforce |
| REST API (Bulk API 2.0) | HTTPS/CSV or JSON | High (async) | Millions of rows | Mass data load/upsert; high-volume ETL; migration |
| SOAP API | HTTPS/XML | Low | Up to 200 records per call | Legacy systems; older integration middleware |
| Platform Events (inbound) | SOAP/REST publish | Low | 250K events/day (standard) | Decoupled event publishing from external system; fire-and-forget |
| Apex REST Web Service | HTTPS/JSON | Low | Limited by Apex limits | Custom integration endpoint; business logic on inbound |
| MuleSoft Anypoint | Varies | Varies | Enterprise | Multi-system; transformation; error handling; orchestration |

#### Outbound from Salesforce

| Mechanism | Trigger | Latency | Reliability | Use When |
|---|---|---|---|---|
| Outbound Messages (Workflow) | Declarative trigger | Low | At-least-once (retry) | Simple field-change notifications; no code required |
| Apex Callouts | Code-triggered | Low (sync) | Once (no auto-retry) | Custom outbound logic; response processing needed |
| Platform Events (outbound) | Code/flow publish | Near-real-time | At-least-once (retain 72h) | Decoupled; multiple consumers; EDA |
| Change Data Capture (CDC) | Data change | Near-real-time | At-least-once (72h retain) | Replication to external systems; audit; data sync |
| Streaming API (PushTopic) | Query-based | Near-real-time | At-most-once | Client-side real-time updates (browser/mobile) |
| Bulk API (Export) | On-demand | High | N/A | Large-volume data export; ETL |

### Choosing Between Platform Events and CDC

| Dimension | Platform Events | Change Data Capture |
|---|---|---|
| **Trigger** | Published explicitly by code or flow | Automatically published when a record changes |
| **Payload** | Custom fields (only what you define) | Changed fields + headers (what changed + context) |
| **Objects** | Custom and standard | Standard objects + custom objects (enableable) |
| **Volume limit** | 250K events/day (standard license) | 25K events/24h per channel (default) |
| **Use for** | Business events (stay check-in, enrollment) | Data sync, external replication, audit trail |
| **Retention** | 72 hours | 72 hours |

**Loyalty context:** Use Platform Events (`Loyalty_Stay_Event__e`) for stay accrual integration from POS — the event carries only the payload needed for loyalty processing. Use CDC for downstream data replication (e.g., syncing LoyaltyProgramMember to a data warehouse).

### MuleSoft Considerations

- Required for: multi-system orchestration, complex data transformation, enterprise error handling, guaranteed delivery
- Requires Anypoint Starter for Industries license for Loyalty Management pre-built connectors
- Avoid MuleSoft for simple 2-system Salesforce ↔ single external system integrations — native Platform Events or REST are cheaper and simpler
- MuleSoft is the right choice when: >3 external systems involved, complex routing/transformation, enterprise SLA for retry and dead-letter handling

---

## Data Architecture

### Object and Relationship Design for Integration

- **External IDs:** Define `externalId=true` on integration key fields (e.g., `BonvoyID__c`) to enable upsert operations without requiring Salesforce IDs
- **Lookup vs Master-Detail:** Use Lookup for cross-system junction objects (allows independent lifecycle); Master-Detail for ownership and cascade delete when parent control is intended
- **Sharing and integration users:** Integration users should have a dedicated profile with minimum-required access; do not use admin users for integration
- **Person Accounts:** Required for certain POS integrations with Loyalty; assess early — enabling Person Accounts is irreversible
- **Data Cloud integration:** `PromotionMarketSegment` links Salesforce Promotions to Data Cloud segments; requires Data Cloud license and ingestion pipeline setup

### Data Migration Strategy

| Strategy | When to Use | Tools |
|---|---|---|
| **Big Bang** | Small dataset; tolerance for downtime | Salesforce Data Loader, Bulk API 2.0 |
| **Phased / Incremental** | Large dataset; zero-downtime requirement | Bulk API 2.0 with delta queries; ETL tool |
| **Parallel Run** | High-risk migration; validation period needed | Dual-write pattern; comparison reports |
| **Trickle / Change-Based** | Ongoing sync after initial load | CDC, Platform Events, MuleSoft |

**Migration order for Loyalty data (dependency-aware):**
1. LoyaltyProgram → LoyaltyTierGroup → LoyaltyTier → LoyaltyProgramCurrency
2. Account / Contact (members) → LoyaltyProgramMember
3. LoyaltyMemberTier → LoyaltyMemberCurrency
4. TransactionJournal → LoyaltyLedger (in chronological order)
5. Voucher → Promotion records last

---

## Large Data Volume (LDV) Architecture

For detailed patterns and commands, see [ldv-performance-reference.md](ldv-performance-reference.md).

### LDV Thresholds (When LDV Patterns Apply)

| Object Record Count | Action Required |
|---|---|
| >100K records | Ensure selective SOQL (indexed filters); review query plans |
| >1M records | Custom index requests; evaluate skinny tables for reporting |
| >10M records | Archiving strategy; data segmentation; platform cache |
| Any object with frequent updates | Avoid record-locking; use Queueable chains or Batch |

### Query Design for LDV

- **Selective queries:** A query is selective when the leading filter reduces records to <10% of the object's total, or <333K rows (whichever is lower). Use `LIMIT` + indexed fields.
- **Indexed fields (automatic):** Id, Name, OwnerId, CreatedDate, LastModifiedDate, SystemModstamp, any ExternalId field, Master-Detail relationship fields
- **Custom indexes:** Request from Salesforce Support for high-cardinality custom fields used as filter criteria in frequent queries (e.g., `BonvoyID__c` on LoyaltyProgramMember)
- **SOQL anti-patterns for LDV:**
  - `WHERE NOT IN (...)` — non-selective; forces full table scan
  - `WHERE [field] != null` on a non-indexed field — non-selective
  - `LIKE '%value%'` — leading wildcard, non-selective
  - Large `IN` lists (>1000 IDs) — split into batches

**Query Plan analysis:** Use the Salesforce Query Plan Tool (Developer Console > Query Editor > "Query Plan" button) to verify index usage before deploying SOQL against large objects.

### Skinny Tables

- Salesforce Support creates skinny tables for objects with >10M records and frequent reporting queries
- Skinny table contains: record ID + a subset of indexed columns you specify
- Dramatically improves report and query performance on LDV objects
- Request when: a SOQL query repeatedly times out on a >10M object despite custom indexes

### Archiving Strategy

- Use **Salesforce Shield Platform Encryption + Big Object** for long-term audit retention
- Use **External Objects** (Salesforce Connect) for archived data in external storage (e.g., AWS S3, Azure) with real-time federated queries
- Archive `TransactionJournal` and `LoyaltyLedger` records older than [retention period] — these are the highest-volume loyalty objects

---

## Async Processing Patterns for Scale

### Pattern Selection Matrix

| Pattern | Max Volume | Retry | Best For |
|---|---|---|---|
| `@future` | Low (sync transaction limit) | No | Simple, one-shot callouts; fire-and-forget |
| Queueable | Medium (50 concurrent) | Manual chain | Sequential multi-step processing; chaining |
| Batch Apex | Very High (50M records) | Manual | Mass data processing, LDV transformations |
| Schedulable | N/A (wraps Batch or Queueable) | N/A | Periodic jobs (daily tier assessment, points expiration) |
| Platform Events (async trigger) | High (250K events/day) | Auto-retry (3x) | Decoupled processing; EDA; external integration |
| Change Data Capture | High (25K events/24h default) | Auto-retry | External replication; audit |

### Queueable vs Batch Decision

| Use Queueable when | Use Batch when |
|---|---|
| Processing < a few thousand records | Processing millions of records |
| Sequential multi-step logic with dependencies | Parallel chunk processing is acceptable |
| Callouts needed (implement `Database.AllowsCallouts`) | No callout per execute() chunk (callouts per batch are limited) |
| Chaining: enqueue next job from `execute()` | Start/execute/finish lifecycle needed |
| Real-time trigger-initiated processing | Scheduled nightly/weekly job |

### Batch Apex Best Practices for LDV

```apex
global class LoyaltyStayAccrualBatch implements Database.Batchable<SObject>, Database.Stateful {
    // Database.Stateful: preserve instance variables between execute() chunks
    private Integer processedCount = 0;
    private List<String> errors = new List<String>();

    global Database.QueryLocator start(Database.BatchableContext bc) {
        // Use QueryLocator for SOQL-based batches (supports up to 50M rows)
        // Filter to minimize scope: use CreatedDate range or a Status field
        return Database.getQueryLocator(
            'SELECT Id, Status__c FROM Loyalty_Stay__c WHERE Status__c = \'Pending\' ORDER BY CreatedDate ASC'
        );
    }

    global void execute(Database.BatchableContext bc, List<Loyalty_Stay__c> scope) {
        // Process scope (default 200 records); reduce scope for memory-intensive ops
        processedCount += scope.size();
    }

    global void finish(Database.BatchableContext bc) {
        // Notify, log, or chain next batch
    }
}
```

- **Scope size:** Default 200. Reduce to 50–100 for operations with many related queries per record.
- **`Database.Stateful`:** Use when you need to accumulate results across chunks (e.g., error lists, counters). Stateful batches are single-threaded.
- **Callouts in Batch:** Only in `start()` and `finish()`; not in `execute()` without `Database.AllowsCallouts` (and this restricts parallelism).
- **Scheduling:** Use `System.scheduleBatch()` or a Schedulable wrapper; do not hard-code start times in code.

### Platform Event Consumer Patterns for LDV

- Platform Event triggers run asynchronously after commit — no governor limit bleed from the publishing transaction
- Consumer trigger governor limits: same as synchronous triggers per batch (200 events processed per trigger invocation)
- For high-volume events: design consumer to be idempotent (safe to process same event twice) — events can be replayed
- Use `EventBus.TriggerContext.currentEvent()` to get publish time and replay ID in the trigger

---

## Governor Limit Budgets for Integration Scenarios

| Scenario | Key Limits to Watch |
|---|---|
| Inbound REST → Apex REST endpoint | 100 SOQL, 150 DML per transaction; 6MB heap; 10s CPU |
| Platform Event trigger (consumer) | 100 SOQL, 150 DML per 200-event batch in trigger |
| Batch Apex execute() | 100 SOQL, 150 DML per scope; heap resets per chunk |
| Queueable with callouts | 100 callouts per transaction; callout after DML = error (use Platform Events to separate) |
| Outbound callout in trigger | Never call sync callout from trigger — use Queueable or Platform Event consumer |
| Data import via Bulk API | No Apex limit per record; triggers still fire (design for bulk: 200 records/trigger batch) |

**Critical rule for callouts:** A callout cannot be made after DML in the same transaction. If you need DML then callout (or vice versa), use an async boundary — Queueable, Platform Event, or `@future`.

---

## Salesforce Documentation Sources

- [Integration Patterns](https://architect.salesforce.com/docs/architect/fundamentals/guide/integration-patterns) — Salesforce Architect fundamentals
- [Event-Driven Architecture](https://architect.salesforce.com/docs/architect/decision-guides/guide/event-driven) — decision guide
- [Platform Events Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_intro.htm)
- [Change Data Capture Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.change_data_capture.meta/change_data_capture/cdc_intro.htm)
- [Bulk API 2.0 Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.api_asynch.meta/api_asynch/asynch_api_intro.htm)
- [Streaming API Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.api_streaming.meta/api_streaming/intro_stream.htm)
- [Async Processing Decision Guide](https://architect.salesforce.com/docs/architect/decision-guides/guide/async-processing)
- [Data Integration Decision Guide](https://architect.salesforce.com/docs/architect/decision-guides/guide/data-integration)
- [Large Data Volumes Best Practices](https://developer.salesforce.com/docs/atlas.en-us.salesforce_large_data_volumes_bp.meta/salesforce_large_data_volumes_bp/ldv_deployments_introduction.htm)
- [Apex Batch Best Practices](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch_interface.htm)
- [Salesforce Limits Quick Reference](https://developer.salesforce.com/docs/atlas.en-us.salesforce_app_limits_cheatsheet.meta/salesforce_app_limits_cheatsheet/salesforce_app_limits_overview.htm)
