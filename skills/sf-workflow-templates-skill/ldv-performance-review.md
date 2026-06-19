# Workflow: LDV & Performance Review

**Use when:** Assessing query selectivity, skinny-table eligibility, async-pattern fit, and volume projections for LDV objects (TransactionJournal, LoyaltyLedger, Loyalty_Stay__c, or other user-specified high-volume objects).
**Agents:** sf-org-agent (model: fast) + sf-research-agent (model: inherit) in parallel → parent synthesizes inline
**Mode:** Plan (read-only org analysis; no changes made)

---

**Input parameters:**
- `Target org alias` (required)
- `Objects in scope` (required; at least one LDV-candidate object)
- `Expected volume / growth projection` (optional; e.g., "500K TransactionJournals/day, 12mo = 180M rows")
- `Hotspot queries to assess` (optional; list of SOQL strings)
- `Time horizon` (optional; default 12 months)

**Workflow steps:**

1. Input validation
   - Confirm org alias is provided; ask if missing.
   - Confirm at least one object is in scope; ask if missing.
   - Resolve org context: sf-org-agent → list_all_orgs → confirm alias is authorized.

2. [PARALLEL] Org data retrieval (sf-org-agent) + Design analysis (sf-research-agent)

   sf-org-agent retrieves:
   - Record count per object (`SELECT COUNT() FROM <Object>`); if count would exceed SOQL row limit, approximate via ApexJob history or EntityParticle statistics
   - Field-level index status for each in-scope object:
     - External ID flags (via EntityParticle: `SELECT QualifiedApiName, IsExternalId FROM EntityParticle WHERE EntityDefinition.QualifiedApiName = '<Object>'`)
     - Custom index presence (where introspectable; otherwise note "Support ticket required to confirm")
     - Indexed standard fields (Id, Name, OwnerId, CreatedDate, LastModifiedDate, SystemModstamp, RecordTypeId, M-D and Lookup parent IDs)
   - Existing skinny tables (query SkinnyTable if available in the org tooling API; otherwise report "SFDC Support request required to confirm")
   - Async job history: `SELECT Status, JobType, ApexClass.Name, TotalJobItems, CreatedDate FROM AsyncApexJob WHERE JobType IN ('BatchApex','Queueable','ScheduledApex') ORDER BY CreatedDate DESC LIMIT 50`
   - Query-plan eligibility pre-check: for each provided hotspot query, run a representative LIMIT 1 variant to confirm syntax validity; actual Query Plan requires Dev Console and is reported as a manual step

   sf-research-agent provides (load `.cursor/skills/sf-integration-patterns-skill/ldv-performance-reference.md`):
   - Selectivity assessment per hotspot query (non-selective anti-patterns, leading-filter recommendation)
   - Async pattern fit: synchronous vs @future vs Queueable vs Batch vs Platform Events, justified by projected volume and governor-limit headroom
   - Skinny-table eligibility check (>10M record threshold, reporting pattern, field-count/relationship constraints)
   - Custom-index candidacy list (high-cardinality, high-frequency filter fields; include request template)
   - Archiving / data lifecycle strategy if growth projection crosses LDV thresholds
   - Cite Large Data Volumes Best Practices guide and ldv-performance-reference.md

3. Parent synthesizes LDV & Performance Review Report inline with these sections:

   a. **Executive Summary** — objects assessed, risk level per object (Low/Medium/High/Critical per ldv-performance-reference.md threshold table), top 3 actions
   b. **Object Inventory** — table: Object | Current Count | Projected (12mo) | LDV Tier | Index Status Summary
   c. **Query Plan Assessment** — table: Query | Selective? | Leading Filter | Recommendation | Manual Dev-Console Verification Needed?
   d. **Skinny Table Eligibility** — table: Object | Eligible? | Justification | Support Request Template
   e. **Custom Index Candidates** — table: Object.Field | Cardinality Assumption | Use Case | Request Priority | Support Request Template
   f. **Async Pattern Review** — table: Current Pattern | Recommended Pattern | Volume Justification | Governor-Limit Headroom
   g. **Archiving / Data Lifecycle Plan** — objects crossing 10M, strategy (Big Objects, external archive, soft-delete with retention policy), retention policy
   h. **Prioritized Remediation Backlog** — table: Priority | Action | Effort (H/M/L) | Impact (H/M/L) | Dependencies

4. Tell the user: "LDV & Performance Review complete. This session is in Plan mode — copy the output above and switch to Agent mode to save it to a file (suggested filename: docs/LDV_Performance_Review_[OrgAlias]_[date]_v1.md)."

**Guard rails:**
- **Sub-agent failure handling:** If sf-org-agent fails or times out, continue with sf-research-agent output and flag "org data unverified" in each affected section. If sf-research-agent fails, continue with org facts only and flag "design analysis pending".
- **No writes:** This workflow is strictly read-only. No org changes, no data mutations, no metadata deploys. If the user asks to apply a remediation, escalate to the appropriate dev-agent workflow after this report is delivered.
