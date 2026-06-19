---
name: sf-review-checklist-reference
description: >-
  Complete mechanical review checklist for Salesforce Apex, LWC, Flow, metadata,
  validation rules, and permission sets. Loaded by sf-review-agent for first-pass
  code review. INFRASTRUCTURE REFERENCE: Loaded on demand by sf-review-agent.
  The omission of the -skill suffix is intentional to distinguish infrastructure
  reference files from user-facing domain skills.
---

# Mechanical Review Checklist

This file is loaded by **sf-review-agent** to provide the full first-pass review checklist. Apply the relevant sections based on the file types being reviewed.

---

## 1. Apex — Bulkification

- [ ] No SOQL inside a `for` loop (including enhanced for loops)
- [ ] No DML inside a `for` loop
- [ ] Collections (`List`, `Set`, `Map`) used to batch SOQL and DML
- [ ] Trigger handlers process `Trigger.new` / `Trigger.old` as collections, not record-by-record
- [ ] No `Database.query()` or `[SELECT ...]` inside a loop

## 2. Apex — SOQL Quality

- [ ] Bind variables used (`WHERE Id IN :idSet`); no string concatenation in dynamic SOQL
- [ ] `LIMIT` clause present on queries that could return unbounded rows
- [ ] `WITH SECURITY_ENFORCED` or `Security.stripInaccessible` used where user-context queries are needed
- [ ] No `SELECT *`-equivalent (all fields named explicitly)
- [ ] Relationship queries used where possible to avoid N+1 patterns

## 3. Apex — FLS / CRUD

- [ ] DML operations preceded by appropriate CRUD check or `Security.stripInaccessible`
- [ ] SOQL in user context uses `WITH SECURITY_ENFORCED` or `stripInaccessible(READ, records)`
- [ ] `Schema.sObjectType.[Object].isCreateable()` / `isUpdateable()` / `isDeletable()` checked before DML if not using stripInaccessible
- [ ] System-context operations (bypass sharing) are justified in a comment

## 4. Apex — Naming Conventions

- [ ] Class names: `PascalCase`; handlers follow `[Object]TriggerHandler` pattern
- [ ] Method names: `camelCase`; descriptive verbs (`processJournals`, `buildStayEvent`)
- [ ] Constants: `UPPER_SNAKE_CASE`
- [ ] Test classes: `[ClassName]Test` suffix; annotated `@isTest`
- [ ] Custom exceptions: `[Name]Exception` extending `Exception`

## 5. Apex — Trigger Framework

- [ ] One trigger per object (no multiple triggers on the same SObject)
- [ ] Trigger delegates to handler via `GenericTriggerDispatcher` (or equivalent dispatcher)
- [ ] Handler implements `ITriggerHandler` interface (or project's equivalent)
- [ ] No business logic directly in the trigger file
- [ ] Recursive guard present where appropriate (static boolean flag or similar)

## 6. Apex — Error Handling

- [ ] `try/catch` present for DML and callout operations
- [ ] Exceptions logged to `Exception_Log__c` (or project's equivalent) rather than silent swallowing
- [ ] `Database.insert(records, false)` (allOrNone=false) used with `SaveResult` inspection where partial success is intended
- [ ] `System.debug` statements not left in production code paths

## 7. Apex — Test Classes

- [ ] `@isTest` annotation present
- [ ] `@TestSetup` used for shared test data (not repeated setup in each method)
- [ ] Bulk test: at least one test method inserts/updates 200+ records
- [ ] Negative test: at least one test validates error conditions / null handling
- [ ] `System.assert`, `System.assertEquals`, or `System.assertNotEquals` with meaningful messages — not just coverage padding
- [ ] `Test.startTest()` / `Test.stopTest()` wrapping async invocations
- [ ] `Test.setMock()` used for callout classes (`HttpCalloutMock`, `WebServiceMock`)
- [ ] No `SeeAllData=true` unless absolutely required (and commented with justification)
- [ ] `runAs(user)` used for permission-sensitive test scenarios

## 8. Apex — Async Patterns

- [ ] `@future` methods are `static void`; parameters are primitives or collections of primitives (no SObject params)
- [ ] Queueable classes implement `Database.AllowsCallouts` when making callouts
- [ ] `System.enqueueJob()` not called inside a loop
- [ ] Batch classes implement `Database.Batchable` with appropriate `start`, `execute`, `finish` methods
- [ ] `Database.executeBatch()` scope size is appropriate (default 200 is fine; smaller for heavy processing)

## 9. LWC — Mechanical Checks

- [ ] `@api` properties are not mutated directly (clone before mutation)
- [ ] Error handling present in all `@wire` adapters (`if (error) { ... }`)
- [ ] Error handling present in all imperative Apex calls (`.catch()` or `try/catch`)
- [ ] No hardcoded record IDs or object API names in JS (use `@salesforce/schema` imports)
- [ ] `connectedCallback` does not make synchronous Apex calls (use `@wire` or handle async)
- [ ] `disconnectedCallback` cleans up event listeners if registered in `connectedCallback`

## 10. Metadata XML — Mechanical Checks

- [ ] API version matches project standard (66.0 for this workspace)
- [ ] Custom field API names follow convention (`PascalCase__c` for custom, standard casing for standard)
- [ ] `<required>` and `<externalId>` flags intentional (not accidentally true)
- [ ] Permission sets reference fields by `<field>Object.FieldName__c</field>` pattern
- [ ] Platform Event `<publishBehavior>` is appropriate (`PublishAfterCommit` for most cases)

## 11. Flow — Mechanical Checks

> For flow design standards (why these checks exist, intended trigger patterns, callout restriction rationale), see `.cursor/rules/sf-flow-standards-rule.mdc`.

- [ ] **Bulkification risk:** Record-triggered flows execute once per record by default; flag any flow element that performs DML on unrelated objects inside a loop (creates hidden N×DML patterns when invoked in bulk)
- [ ] **Fault paths present:** Every DML element, callout element, and subflow invocation has a configured Fault connector (not just the default "uncaught fault" behavior)
- [ ] **Null checks on variable references:** Variables used in decision conditions are initialized or null-safe (`{!var} != null` checks present before use)
- [ ] **Infinite loop risk:** Record-triggered flows that update the triggering record include a condition or entry check to prevent re-triggering (e.g., a prior-value check on the entry condition)
- [ ] **DML in loops:** Apex Action or subflow elements that perform DML are not placed inside a Loop element
- [ ] **Entry conditions set:** Record-triggered flows have specific entry conditions (not "Always" unless intentional and justified in a description)
- [ ] **Interview label set:** Flow has a meaningful `interviewLabel` for debugging purposes
- [ ] **API version current:** Flow API version matches project standard (66.0)
- [ ] **Description populated:** Flow has a meaningful description explaining its purpose and trigger conditions
- [ ] **Callout in after-save context:** Callout elements (HTTP, External Service) are not used in after-save record-triggered flows (not supported — flag for async refactor)

## 12. Validation Rules — Mechanical Checks

- [ ] **Error message is user-friendly:** Error message is in plain English, not a technical string or internal code; tells the user what to do, not just what is wrong
- [ ] **Field-level display:** `Error Message Location` is set to `Field` where applicable (not always `Top of Page`); `Field` display is clearer for the user
- [ ] **Bypass pattern present (if needed):** If admin/integration bypass is required, rule uses a standard bypass pattern (e.g., custom permission `Bypass_Validation_Rules__c` or profile/permission set check via `$Permission` or `$Profile`) — not a hardcoded username
- [ ] **Formula is readable:** Complex boolean conditions use named custom permissions or intermediate formula fields rather than deeply nested `AND`/`OR` chains
- [ ] **No duplicate logic:** Rule logic does not duplicate an existing flow condition or trigger validation that runs in the same context

## 13. Permission Sets — Mechanical Checks

- [ ] **Functional persona naming:** Permission set name reflects a functional role or feature (e.g., `Loyalty_Program_Agent`, `Stay_Accrual_Processor`) — not a person's name or vague label
- [ ] **Minimum access principle:** Permission set grants only the object and field permissions needed for the persona's tasks; flag any `Modify All` or `View All` grants that seem broader than the stated use case
- [ ] **License requirement documented:** If the permission set requires a specific license (e.g., Loyalty Management User, Industries User), this is noted in the description
- [ ] **Description populated:** Permission set has a description explaining who should receive it and why
- [ ] **No redundant grants:** Permissions granted here are not already granted to the baseline profile — flag obvious redundancies

---

## Severity Definitions

| Severity | Meaning |
|---|---|
| **Critical** | Must fix before merge: governor limit risk, security flaw, data integrity issue |
| **Warning** | Should fix: performance, incomplete error handling, test anti-pattern |
| **Suggestion** | Optional improvement: naming, readability, minor pattern alignment |

---

## Output Template

```
## Mechanical Review: [File / Batch Name]

### Summary
[Pass / Findings Present] — [X] Critical, [Y] Warning, [Z] Suggestion

### Findings

| # | Severity | Category | Location (Line / Method) | Issue | Fix |
|---|---|---|---|---|---|
| 1 | Critical | Bulkification | Line 42, processJournals() | SOQL inside for loop | Move query above loop; use Set<Id> collection |
| 2 | Warning | FLS | Line 78, updateMembers() | DML without CRUD check | Add Security.stripInaccessible before insert |
| 3 | Warning | Test Class | Line 12, testInsert() | No bulk test (only 1 record) | Add test method with 200+ records |
| 4 | Suggestion | Naming | Class name | Handler class not following [Object]TriggerHandler pattern | Rename to match convention |

### Governor Limit Hotspots
[SOQL count estimate, DML count estimate, any heap/CPU risk — mechanical assessment only]

### Escalation Recommendations
[List items that need sf-dev-agent or sf-research-agent for deeper analysis]

### Files Reviewed
[List of files / line counts]
```
