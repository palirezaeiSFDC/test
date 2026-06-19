# Large Data Volume (LDV) & Performance — Reference

## LDV Thresholds

| Record Count | Risk Level | Required Actions |
|---|---|---|
| 1K – 100K | Low | Standard design; ensure queries use indexed fields |
| 100K – 1M | Medium | Review query plans; ensure selective SOQL; avoid LIKE with leading % |
| 1M – 10M | High | Custom index requests; skinny tables for reporting; archiving plan |
| >10M | Critical | Skinny tables; archiving; data segmentation; platform cache; LDV-specific architecture review |

## Automatic Index Fields (Always Indexed)

These fields are indexed by Salesforce automatically — always prefer them as leading filter criteria:

- `Id`
- `Name` (for objects where it is the primary identifier)
- `OwnerId`
- `CreatedDate`
- `LastModifiedDate`
- `SystemModstamp`
- `RecordTypeId`
- Any field marked `ExternalId = true`
- Master-Detail and Lookup relationship fields (parent ID)

## Selectivity Rules

A SOQL query is **selective** (uses an index) when:

| Object Size | Selectivity Threshold |
|---|---|
| < 1M records | Filter returns < 333,000 rows (33%) |
| > 1M records | Filter returns < 10% of total rows |

**Non-selective = full table scan.** On LDV objects, non-selective queries cause timeouts and lock issues.

## Non-Selective SOQL Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| `WHERE Status__c != 'Closed'` | Non-selective (most records pass) | Filter on the minority set: `WHERE Status__c = 'Pending'` |
| `WHERE Name LIKE '%Marriott%'` | Leading wildcard = full scan | Trailing wildcard only: `LIKE 'Marriott%'`; or use SOSL |
| `WHERE Description != null` | Non-selective on non-indexed field | Add custom index or restructure query |
| `WHERE Id NOT IN :idSet` | Non-selective | Redesign to query the desired set directly |
| No LIMIT on open-ended query | May exceed 50K row limit | Always use `LIMIT`; paginate with `OFFSET` or `LastModifiedDate` cursor |
| SOQL in loop | N+1 queries; governor limit breach | Collect IDs; single query outside loop |

## Custom Index Requests

**When to request:** High-cardinality custom fields used as the leading filter in frequent SOQL queries on objects with >100K records.

**How to request:** Salesforce Customer Support ticket. Provide:
- Object API name
- Field API name
- Representative SOQL query
- Record count and growth projection

**Examples for this project:**
- `LoyaltyProgramMember.BonvoyID__c` — frequent lookup by BonvoyID
- `Loyalty_Stay__c.Status__c` (if stay processing queries filter by status on a large dataset)
- `TransactionJournal.CreatedDate` — already indexed (standard field); use as leading filter

## Query Plan Tool Usage

1. Open Developer Console → Query Editor
2. Enter your SOQL query
3. Click **"Query Plan"** (not "Execute")
4. Assess output:
   - **Leading Operation Type = Index** → Good; query uses an index
   - **Leading Operation Type = TableScan** → Bad; non-selective; refactor
   - **Relative Cost < 1** → Acceptable; > 1 → review; > 10 → must refactor

## Skinny Tables

A Salesforce Support-created denormalized table subset for LDV reporting performance.

| Aspect | Detail |
|---|---|
| When to request | Object > 10M records; reporting queries repeatedly timeout |
| What they contain | Record ID + selected indexed columns (you specify) |
| Performance gain | 50–90% faster on filtered reports |
| Limitation | Not available for all object types; read-only; schema changes require re-request |
| How to request | Salesforce Customer Support ticket |

**Candidate objects for this project:**
- `TransactionJournal` (high write volume; frequent reporting)
- `LoyaltyLedger` (high write volume; financial aggregation)
- `Loyalty_Stay__c` (if stay volume grows to millions)

## Archiving Strategy

| Approach | Mechanism | Use For |
|---|---|---|
| **Big Objects** | Standard Salesforce Big Object + archive trigger | Long-term retention in Salesforce; queryable via SOQL with restrictions |
| **External Objects** | Salesforce Connect + External Data Source | Archive to AWS S3, Azure, Snowflake; federated real-time query |
| **Data Export + Purge** | Bulk API export + `sf data delete` | Compliance-driven purge; non-queryable post-archive |

**Archiving candidates:**
- `TransactionJournal` records > 2 years old
- `LoyaltyLedger` records > 2 years old  
- Closed `Promotion` records > 1 year old

## Async Processing Performance Patterns

### Batch Apex Scope Sizing

| Operation Complexity | Recommended Scope |
|---|---|
| Simple field update, no related queries | 200 (default) |
| 2–5 related SOQL queries per record group | 100 |
| Complex loyalty calculation per record (multiple queries + DML) | 50 |
| External callout per chunk | 1–5 (callout-per-chunk model) |

### Queueable Chaining for LDV

For processing >50K records that cannot fit in a single Queueable (which doesn't support SOQL QueryLocator), chain Queueables with an offset/cursor:

```apex
public class LoyaltyProcessQueueable implements Queueable {
    private Integer offset;
    private static final Integer CHUNK_SIZE = 200;

    public LoyaltyProcessQueueable(Integer offset) {
        this.offset = offset;
    }

    public void execute(QueueableContext ctx) {
        List<Loyalty_Stay__c> stays = [
            SELECT Id FROM Loyalty_Stay__c
            WHERE Status__c = 'Pending'
            ORDER BY CreatedDate ASC
            LIMIT :CHUNK_SIZE OFFSET :offset
        ];
        if (stays.isEmpty()) return; // Done

        // process stays...

        // Chain next chunk
        if (!Test.isRunningTest()) {
            System.enqueueJob(new LoyaltyProcessQueueable(offset + CHUNK_SIZE));
        }
    }
}
```

**Limit:** Queueable chaining is limited to 50 concurrent Queueable jobs. For true LDV (>10M records), use Batch Apex with QueryLocator instead.

### Platform Cache

| Cache Type | Scope | TTL Max | Best For |
|---|---|---|---|
| **Org Cache** | Entire org | 172,800s (48h) | Shared config data; lookup tables; tier definitions |
| **Session Cache** | Per user session | 28,800s (8h) | User-specific preferences; member profile snapshot |
| **Local Cache** (Platform Cache Partition) | Per partition | Configurable | High-frequency read, low-frequency write data |

**Candidates for Platform Cache in this project:**
- Loyalty tier definitions (`LoyaltyTier`, `LoyaltyTierGroup`) — read-frequently, change-rarely
- `Loyalty_Tier_Tenure_Configuration__mdt` records — CMT is already fast but caching avoids repeated queries
- `Stay_Eligibility_Rule__c` — eligibility rules queried per stay event; cache at org level with a daily TTL

```apex
// Writing to org cache
Cache.OrgPartition partition = Cache.Org.getPartition('local.LoyaltyConfig');
partition.put('tierDefinitions', tierList, 86400); // 24h TTL

// Reading from org cache
List<LoyaltyTier> tiers = (List<LoyaltyTier>) partition.get('tierDefinitions');
if (tiers == null) {
    tiers = [SELECT Id, Name, MinimumPoints__c FROM LoyaltyTier WHERE ...];
    partition.put('tierDefinitions', tiers, 86400);
}
```

## Performance Review Checklist

When reviewing a design or implementation for LDV and performance:

- [ ] All SOQL queries on high-volume objects use indexed leading filters
- [ ] Query plans verified for objects with >100K records
- [ ] Custom index requested for high-cardinality filter fields on LDV objects
- [ ] No SOQL or DML inside loops (bulkification)
- [ ] Batch Apex scope size appropriate for operation complexity
- [ ] Platform Cache used for frequently-read, rarely-changed configuration data
- [ ] Archiving plan documented for objects projected to exceed 10M records
- [ ] Async pattern selected matches volume, latency, and retry requirements
- [ ] Callouts not placed synchronously in triggers (async boundary enforced)
- [ ] `Database.Stateful` used only when cross-chunk state is genuinely needed (single-threaded)
- [ ] Skinny table request submitted if object already >10M records with reporting timeouts

## Salesforce Documentation

- [Large Data Volumes Best Practices](https://developer.salesforce.com/docs/atlas.en-us.salesforce_large_data_volumes_bp.meta/salesforce_large_data_volumes_bp/ldv_deployments_introduction.htm)
- [SOQL and SOSL Reference](https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_sosl_intro.htm)
- [Apex Batch Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch_interface.htm)
- [Apex Queueable](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_queueable_jobs.htm)
- [Platform Cache Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_cache_namespace_overview.htm)
- [Async Processing Decision Guide](https://architect.salesforce.com/docs/architect/decision-guides/guide/async-processing)
- [Salesforce Limits Quick Reference](https://developer.salesforce.com/docs/atlas.en-us.salesforce_app_limits_cheatsheet.meta/salesforce_app_limits_cheatsheet/salesforce_app_limits_overview.htm)
