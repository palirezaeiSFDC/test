# Workflow: Data Model Analysis

**Use when:** Analyzing object relationships, field usage, object assessment, or junction object optimization across a Salesforce org.
**Agents:** org-agent (metadata) + research-agent (design analysis) in parallel → parent synthesizes inline
**Mode:** Plan

---

Target org: [TARGET_ORG]
Objects in scope: [list of objects or "derive from feature/domain"]
Analysis focus: [relationship-analysis | field-usage-audit | object-assessment | junction-optimization | all] (default: all)

**Guard rails:**
- If sf-org-agent fails/times out, proceed with local workspace discovery and research-agent analysis only; flag unverified metadata.
- Output inline in the plan document; do not auto-write to docs/. Ask user for file-write preference at end.

Run Phase 1 in PARALLEL:

1. Use sf-org-agent to:
   **Relationship Analysis:**
   - For each object in scope: describe fields, relationships (lookups, master-detail, external IDs)
   - Identify polymorphic relationships (What/Who fields) and note cascade-delete implications
   - Map parent-child relationship chains (up to 3 levels deep)

   **Field Usage Audit:**
   - For each object, run SOQL: SELECT QualifiedApiName, DataType, IsCustom FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = '[Object]' LIMIT 100
   - Identify fields with no recent usage (check LastModifiedDate patterns if available)
   - Identify formula fields with complex cross-object references (potential performance risk)

   **Object Assessment:**
   - Check record count for each object: SELECT COUNT() FROM [Object]
   - Identify objects near Large Data Volume thresholds (>1M records)
   - Verify index coverage: check if frequently-filtered fields are indexed (External ID or indexed standard fields)

   **Junction Object Review:**
   - Identify junction objects (objects with 2+ master-detail relationships)
   - Verify junction object roll-up summary field usage and cascade behavior
   - Flag junction objects with high record volumes (>500K) as LDV risk

2. Use sf-research-agent to:
   - Analyze org-agent findings against Salesforce data model best practices
   - Assess LDV risks and query performance implications
   - Identify normalization vs denormalization trade-offs
   - Recommend relationship type changes or archiving strategies where applicable
   - Reference: .cursor/skills/sf-integration-patterns-skill/SKILL.md for LDV patterns

Phase 2 — Synthesis (parent synthesizes directly):
- Do NOT spawn sf-dev-agent for synthesis
- Produce a structured Data Model Analysis Report:
  1. Executive Summary (key findings and risk count)
  2. Object Inventory — table: Object | Record Count | Custom Fields | Relationships | LDV Risk
  3. Relationship Map — describe key relationships and dependency chains
  4. Field Usage Findings — table: Object | Field | Issue | Recommendation
  5. LDV & Performance Risks — table: Object/Field | Risk | Threshold | Recommendation
  6. Junction Object Assessment — table: Object | Parent1 | Parent2 | Record Count | Risk
  7. Recommendations — prioritized action list
- Tell the user: "Data Model Analysis complete. This session is in Plan mode — copy the output above and switch to Agent mode to save it to a file (suggested filename: docs/DataModelAnalysis_[scope]_v1.md)."
