# CLM Multiplier Historical Tracking - Technical Design

## 1. Purpose

This document defines the technical implementation for `LYLT-14270`:

`Earn | P1 | CLM Multipliers Historical Tracking: Brand/EQN - Year over year (SF Configuration)`

Goal: preserve an audit-grade history of multiplier configuration changes on Brand and Property records so authorized users can research what values were effective when a stay occurred.

## 2. Scope

In scope:

- Track create, update, and deactivation changes for configured multiplier fields.
- Track changes on Brand and Property (Account) records.
- Preserve old/new values with effective dating.
- Enable permission-based reporting and export.
- Support year-over-year audit/research use cases.

Out of scope:

- Recalculating or reprocessing historical stays.
- Automatic correction workflows in Earn.
- Redefining multiplier business rules.

## 3. Recommended Solution

Implement a custom history object and change-capture service (Option 2 from epic analysis).

Why this option:

- Native field history is fast but too limited for effective dating and long-term audit controls.
- Custom object gives full control over tracked fields, metadata, and retention.
- Reporting can be built directly in Salesforce and can also feed CRAM in a later phase.

## 4. Data Model

### 4.1 New Object

Create `Multiplier_History__c` with one record per change event.

Required fields:

- `Entity_Type__c` (Picklist: `Account`, `Brand`)
- `Entity_Id__c` (Text 18)
- `Entity_Name__c` (Text 255)
- `Property_Code__c` (Text 20, nullable for Brand-only events)
- `Brand_Code__c` (Text 20, nullable for Property-only events)
- `Multiplier_Field_Api__c` (Text 255)
- `Multiplier_Type__c` (Picklist: `BASE_EARN`, `EQN`, `OTHER`)
- `Old_Value__c` (Text 255)
- `New_Value__c` (Text 255)
- `Effective_Start_Datetime__c` (DateTime)
- `Effective_End_Datetime__c` (DateTime, nullable)
- `Changed_At__c` (DateTime)
- `Changed_By_Id__c` (Text 18)
- `Changed_By_Name__c` (Text 255)
- `Change_Source__c` (Picklist: `UI`, `API`, `BATCH`, `SYSTEM`)
- `Change_Event_Type__c` (Picklist: `CREATE`, `UPDATE`, `DEACTIVATE`)
- `Correlation_Id__c` (Text 100, nullable)
- `Is_Active_Version__c` (Checkbox)

Recommended indexes:

- `Entity_Type__c`, `Entity_Id__c`, `Multiplier_Field_Api__c`, `Effective_Start_Datetime__c`
- `Changed_At__c`
- `Property_Code__c`
- `Brand_Code__c`

### 4.2 Tracked Fields Registry

Create metadata-driven tracked field config so future multiplier types can be added without code deployment:

- `Multiplier_Tracked_Field__mdt`
  - `Entity_Type__c`
  - `Field_Api_Name__c`
  - `Multiplier_Type__c`
  - `Is_Enabled__c`

## 5. Change Capture Design

Use record-triggered capture on both `Account` and `Brand` update paths.

Implementation options:

- Preferred: Apex trigger handler + shared service class for deterministic behavior.
- Alternate: Record-triggered Flow if volume remains low and logic remains simple.

Processing behavior:

1. Detect changed tracked fields by comparing `Trigger.oldMap` and `Trigger.newMap`.
2. For each changed tracked field:
   - Close previous active version (`Effective_End_Datetime__c = now`, `Is_Active_Version__c = false`).
   - Insert a new version row with:
     - `Effective_Start_Datetime__c = now`
     - `Effective_End_Datetime__c = null`
     - `Is_Active_Version__c = true`
     - old/new values and actor metadata.
3. Persist in the same transaction as source change.

Guardrails:

- Bulk-safe processing for batch/API updates.
- No recursion (static transaction guard).
- Skip writes when value change is semantic no-op (trim/normalized-equal).
- Emit platform event/log entry on capture failure (do not silently drop).

## 6. Effective-Dating Rules

History should answer: "what multiplier value was effective at stay activity date/time?"

Rules:

- Exactly one active version per `(Entity, Field)` at any moment.
- New version starts at capture timestamp.
- Prior version ends at same timestamp.
- Open-ended active row has `Effective_End_Datetime__c = null`.

As-of query logic:

- `Effective_Start_Datetime__c <= :asOf`
- `Effective_End_Datetime__c = null OR Effective_End_Datetime__c > :asOf`

## 7. Reporting and Access

### 7.1 Salesforce Reporting

Yes, reporting is supported from this design.

Enable:

- Custom report type on `Multiplier_History__c`.
- Filters for date range, property, brand, multiplier type, actor, and source.
- Export capability for permitted users.

### 7.2 CRAM Reporting

Yes, CRAM reporting is possible if CRAM can consume this dataset.

Recommended approach:

- Phase 1: Build operational reports in Salesforce on `Multiplier_History__c`.
- Phase 2: Feed same records to CRAM (batch extract or event feed) for enterprise analytics.

Key dependency for CRAM:

- Confirm ingestion path from CLM/SF object data to CRAM data store.
- Confirm required latency (near-real-time vs daily batch).
- Confirm retention and masking policies.

## 8. Access and Auditability

- Limit report/query/export access to permission-based associates.
- Preserve actor linkage through `Changed_By_Id__c` and `Correlation_Id__c`.
- Keep access setup aligned with existing CLM permission model.

## 9. Retention and Governance

- Retain per audit policy (minimum must satisfy year-over-year research).
- Define archive strategy if record count growth affects performance.
- Add monthly volume monitoring and query performance checks.

## 10. API and Query Contract (for downstream consumers)

Minimum query dimensions to support:

- Date range (`Changed_At__c`, effective dates)
- Property code
- Brand code
- Multiplier field/type
- Change actor
- Change source

Recommended consumer view:

- Current snapshot view (active versions only)
- Historical timeline view (full version chain)
- As-of view (effective at target date)

## 11. Non-Functional Requirements Mapping

- **Audit quality**: full old/new + actor + timestamp + effective dating.
- **Scalability**: metadata-based tracked field registry and indexed history object.
- **Operability**: bulk-safe capture and failure observability.
- **Access control**: permission-based visibility for historical research.

## 12. Delivery Plan

Phase 1 (P1, this epic):

- Build `Multiplier_History__c`.
- Implement Account/Brand change capture for agreed multiplier fields.
- Add base Salesforce report type and audit report templates.
- Validate with sample historical queries.

Phase 2 (optional hardening):

- CRAM ingestion pipeline.
- Additional analytics/report packs.
- Data archival automation.

## 13. Acceptance Criteria to Technical Traceability

Epic acceptance asks that permission-based associates can research historical changes after multiplier term updates.

This design satisfies it by:

- capturing every multiplier config change as versioned history,
- preserving effective windows for as-of research,
- enabling report/query/export access only for permissioned users.

No stay reprocessing logic is introduced, consistent with epic scope.
