# Flow Analysis Reference

## Bulkification Risk by Flow Type

| Flow Type | Processes Per Transaction | Bulkification Risk |
|---|---|---|
| Record-triggered (API 57.0+) | Batch (up to 200) | Low if built correctly |
| Record-triggered (API < 57.0) | One record at a time | HIGH — governor limits hit at ~100 records |
| Auto-launched (invoked from Apex) | Depends on caller | Depends on how caller invokes it |
| Screen flow | Single user action | Low — not batch |

**Check first:** Confirm the flow's API version. Flows saved at API < 57.0 may not benefit from bulk optimization. Recommend upgrading API version and retesting.

---

## Flow Review Checklist

**Governor Limit Risks**
- [ ] Does the flow call Apex actions (`@InvocableMethod`) inside a loop? → Each iteration may execute SOQL/DML
- [ ] Does the flow use "Get Records" inside a loop element? → Equivalent to SOQL in a loop
- [ ] Does the flow use "Create/Update/Delete Records" inside a loop without "Use Separate Resources"? → Multiple DML operations
- [ ] Is the flow's API version < 57.0? → Single-record processing; governor limits at scale

**Fault Path Coverage**
- [ ] Does every Apex action call have a fault connector? → Unhandled faults surface as generic errors to users
- [ ] Does every "Create/Update Records" element have a fault path for partial failures?
- [ ] Is there a fault handler subflow or screen that shows meaningful error messages?
- [ ] Does the flow log errors (Platform Event or custom object) before ending the fault path?

**Infinite Loop Risk**
- [ ] Does a record-triggered flow update the same object that triggers it? → Loop risk
- [ ] Is the "Only when record is created or updated to meet the condition" entry condition set (not "Every time")? → Controls re-entry
- [ ] Are recursive calls to invocable Apex guarded with a recursion flag?

**Logic and Data Issues**
- [ ] Are null checks in place before accessing fields of related records retrieved via "Get Records"?
- [ ] Are picklist values hardcoded? → Brittle; use Custom Labels or Custom Metadata for configurable values
- [ ] Does the flow handle zero results from "Get Records" before using the output?
- [ ] Are decision elements using `{!$GlobalConstant.True}` as a default path?

**Maintainability**
- [ ] Is the flow description populated and up to date?
- [ ] Are elements named meaningfully (not "Assignment 1", "Decision 2")?
- [ ] Is complex logic extracted into subflows for reuse?
- [ ] Does the flow have a corresponding test Flow or Apex test via `Test.startTest()`?

---

## When to Convert a Flow to Apex

Recommend converting when:
- Flow complexity exceeds 25 elements (debugging becomes impractical)
- The flow requires callouts (HTTP) — not supported in record-triggered flows
- The flow needs to publish Platform Events within a transaction boundary
- Performance profiling shows the flow is the CPU/DML bottleneck
- The flow performs complex collection manipulation (filtering, grouping) that would be O(n²) in Flow logic
