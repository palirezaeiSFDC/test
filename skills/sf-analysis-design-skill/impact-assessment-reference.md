# Impact Assessment & Apex Design Patterns Reference

## Impact Assessment Methodology

An impact assessment answers: "What is affected by this change, what are the risks, and what needs to be done?"

### Step 1: Understand the Change

Before scanning the codebase, clarify:
- **What is changing?** Object, field, API, process, integration endpoint, or data model
- **Direction:** New capability, removal/deprecation, replacement (custom → standard), or refactoring
- **Org context:** Confirm API version, record counts, and active integrations via **sf-org-agent**

### Step 2: Component Discovery (Parallel)

Launch parallel agents/searches across these component categories simultaneously:

| Category | What to Look For | Tool |
|---|---|---|
| Apex classes | References to old object/field API names | `explore` subagent + Grep |
| Triggers | Trigger object name, field references in handlers | Grep on `force-app/**/*.trigger` |
| Flows | Flow element references, variable assignments | Grep on `force-app/**/*.flow-meta.xml` |
| LWC | `@wire` adapters, object API names in JS, HTML | Grep on `force-app/**/lwc/**` |
| Validation Rules | Field references in formula | Grep on `*.validationRule-meta.xml` |
| Permission Sets / Profiles | FLS and CRUD entries for old object/fields | `sf-org-agent` SOQL |
| Layouts | Field references | `sf-org-agent` describe |
| Reports / Dashboards | Column references | `sf-org-agent` query |
| Custom Metadata / Settings | Lookup or field value references | Grep + org describe |
| Integrations | API payload field names in callout classes | Grep on REST/SOAP callout classes |

### Step 3: Risk Classification

For each affected component, classify:

| Risk Level | Criteria |
|---|---|
| **Critical** | Data loss, broken required relationships, security gap, governor limit failure at scale |
| **High** | Functional regression in production code path, broken integration, invalid SOQL |
| **Medium** | Validation rule logic changes, Flow path changes, UI/layout gaps |
| **Low** | Documentation, cosmetic, field label changes |

### Step 4: Field / Object Mapping

For object migrations or field renames:
- Document direct mappings (same type, same semantics)
- Document near-mappings (type conversion required — e.g., Date → DateTime, Lookup → Master-Detail)
- Document gaps (custom fields with no standard equivalent — require custom field creation)
- Document new standard capabilities (not in custom implementation — consider adopting)

### Step 5: Dependency Map

Produce a dependency diagram or table showing the change propagation path:

```
Change (e.g., Custom_Object__c → StandardObject migration)
  ├── Apex: N classes reference old API name → update to new API name
  ├── Flows: N flows reference old object → update object references
  ├── Validation Rules: N rules → migrate to standard object
  ├── Permission Sets: N entries → re-grant on standard object
  ├── Layouts: N layouts → recreate on standard object
  └── Child Relationship: cross-object lookups → add lookup on standard object
```

### Step 6: Document the Assessment

Use the standard template (aligned with `docs/Impact_Assessment_*.md`):

1. **Executive Summary** — scope, current state, key risks
2. **Object/Field Comparison** — source vs target mapping tables
3. **Component Inventory** — table of all affected components, risk level, owner
4. **Gap Analysis** — what needs to be built or configured
5. **Cutover Sequence** — ordered steps with dependencies
6. **Test Strategy** — what to test, in what order, with what data

### Delegation Pattern for Impact Assessments

For large assessments, orchestrate in parallel using `sf-workflow-templates-skill` workflow `impact-assessment`:

```
Parallel launch:
  - explore subagent → codebase scan (Apex, LWC, Flow, metadata XML)
  - sf-org-agent → metadata describe, SOQL for record counts, permission sets
  - sf-research-agent → standard object documentation, WAF alignment

Then: parent synthesizes findings directly into the impact doc
```

---

## Apex Design Patterns

### Trigger Framework (ITriggerHandler / GenericTriggerDispatcher)

This project uses the `ITriggerHandler` interface with `GenericTriggerDispatcher`. Every trigger must follow this pattern — never put logic directly in the trigger file.

```apex
// Trigger (one per object — delegates only)
trigger LoyaltyProgramMemberTrigger on LoyaltyProgramMember (
    before insert, before update, before delete,
    after insert, after update, after delete, after undelete
) {
    GenericTriggerDispatcher.run(new LoyaltyProgramMemberHandler());
}

// Handler implements ITriggerHandler
public class LoyaltyProgramMemberHandler implements ITriggerHandler {
    public void beforeInsert(List<SObject> newList) {
        LoyaltyMemberService.allocateBonvoyIds((List<LoyaltyProgramMember>) newList);
    }
    public void afterInsert(List<SObject> newList, Map<Id, SObject> newMap) { }
    public void beforeUpdate(List<SObject> newList, Map<Id, SObject> oldMap) { }
    public void afterUpdate(List<SObject> newList, Map<Id, SObject> oldMap) { }
    public void beforeDelete(List<SObject> oldList, Map<Id, SObject> oldMap) { }
    public void afterDelete(List<SObject> oldList, Map<Id, SObject> oldMap) { }
    public void afterUndelete(List<SObject> newList, Map<Id, SObject> newMap) { }
}
```

**Rules:**
- One trigger file per object — never create a second trigger on the same object
- Before checking if a trigger exists for an object, verify via `GenericTriggerDispatcher` or trigger file search
- All business logic lives in the handler or in a dedicated Service class called from the handler

### Recursion Guard Pattern

Prevent re-entrancy in after-triggers that perform DML, which can re-fire the same trigger:

```apex
public class TriggerRecursionGuard {
    private static Set<Id> processedIds = new Set<Id>();

    public static Boolean hasProcessed(Id recordId) {
        return processedIds.contains(recordId);
    }

    public static void markProcessed(Id recordId) {
        processedIds.add(recordId);
    }

    public static void reset() {
        processedIds.clear();
    }
}

// In handler
public void afterInsert(List<SObject> newList, Map<Id, SObject> newMap) {
    List<LoyaltyProgramMember> toProcess = new List<LoyaltyProgramMember>();
    for (LoyaltyProgramMember m : (List<LoyaltyProgramMember>) newList) {
        if (!TriggerRecursionGuard.hasProcessed(m.Id)) {
            toProcess.add(m);
            TriggerRecursionGuard.markProcessed(m.Id);
        }
    }
    if (!toProcess.isEmpty()) LoyaltyMemberService.publishMemberEvents(toProcess);
}
```

### Service Layer Pattern

Business logic that spans multiple SObjects or is called from multiple entry points should live in a Service class, not in the handler:

```apex
public with sharing class LoyaltyMemberService {

    @InvocableMethod(label='Allocate BonvoyID' description='Allocates BonvoyID to new members')
    public static void allocateBonvoyIdsInvocable(List<Id> memberIds) {
        List<LoyaltyProgramMember> members = MemberSelector.getByIds(memberIds);
        allocateBonvoyIds(members);
    }

    public static void allocateBonvoyIds(List<LoyaltyProgramMember> members) {
        List<LoyaltyProgramMember> toUpdate = new List<LoyaltyProgramMember>();
        for (LoyaltyProgramMember m : members) {
            if (m.BonvoyID__c == null) {
                toUpdate.add(new LoyaltyProgramMember(
                    Id = m.Id,
                    BonvoyID__c = BonvoyIDGenerator.generate()
                ));
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }
}
```

### Selector Layer Pattern

All SOQL lives in Selector classes, never scattered across handlers or service methods:

```apex
public with sharing class MemberSelector {

    public static List<LoyaltyProgramMember> getByIds(Set<Id> ids) {
        return [
            SELECT Id, Name, BonvoyID__c, MemberStatus, LoyaltyProgramId
            FROM LoyaltyProgramMember
            WHERE Id IN :ids
            WITH SECURITY_ENFORCED
        ];
    }

    public static List<LoyaltyProgramMember> getActiveByProgram(Id programId) {
        return [
            SELECT Id, Name, BonvoyID__c, MemberStatus
            FROM LoyaltyProgramMember
            WHERE LoyaltyProgramId = :programId
            AND MemberStatus = 'Active'
            WITH SECURITY_ENFORCED
            ORDER BY Name
        ];
    }
}
```

**Why Selector classes matter:**
- Single place to add FLS enforcement (`WITH SECURITY_ENFORCED` or `Security.stripInaccessible`)
- Single place to update field lists as schema changes
- Testable in isolation; no SOQL scattered in business logic

### When to Use Each Layer

| Entry Point | Handler | Service | Selector |
|---|---|---|---|
| Trigger before/after event | Routes to Service | Executes business logic | Runs SOQL |
| @InvocableMethod (Flow) | Not involved | Entry point | Called from Service |
| Batch Apex `execute()` | Not involved | Entry point | Called from Service |
| REST API endpoint | Not involved | Entry point | Called from Service |
| LWC (via AuraEnabled) | Not involved | Entry point | Called from Service |

---

## MCP Integration

Use `Salesforce DX` as the sole MCP server, with SF CLI as fallback.

> **Full routing policy:** See `sf-mcp-routing-rule` rule and `.cursor/skills/sf-shared-reference/SKILL.md` for the complete priority table, fallback trigger conditions, and CLI fallback.

### `user-Salesforce DX` — Primary for all org operations

| Tool | Task |
|---|---|
| `run_soql_query` | Verify data, record counts, field values, SObject schema (`useToolingApi=true`) |
| `retrieve_metadata` | Retrieve metadata from org |
| `scan_apex_class_for_antipatterns` | Static analysis of Apex class |
| `run_code_analyzer` | PMD/ESLint analysis on local files |

**Fallback:** SF CLI (`sf data query`, `sf sobject describe`, `sf data create record`, etc.).

For metadata XML schema reference before generation, use `Salesforce DX` code-analysis tools or `WebFetch` from the [Metadata API Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_intro.htm).
