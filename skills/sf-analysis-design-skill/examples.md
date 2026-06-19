# Salesforce Analysis & Design — Examples

## Example 1: Trigger Bulkification

### Before (anti-pattern)

```apex
trigger OpportunityTrigger on Opportunity (before insert) {
    for (Opportunity opp : Trigger.new) {
        Account acc = [SELECT Id, Name FROM Account WHERE Id = :opp.AccountId];
        opp.Description = acc.Name;
    }
}
```

**Problem**: SOQL inside loop — fails when 100+ opportunities inserted.

### After (bulkified)

```apex
trigger OpportunityTrigger on Opportunity (before insert) {
    OpportunityHandler.setAccountDescription(Trigger.new);
}

public class OpportunityHandler {
    public static void setAccountDescription(List<Opportunity> opps) {
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity o : opps) {
            if (o.AccountId != null) accountIds.add(o.AccountId);
        }
        Map<Id, Account> accounts = new Map<Id, Account>([
            SELECT Id, Name FROM Account WHERE Id IN :accountIds
        ]);
        for (Opportunity o : opps) {
            if (o.AccountId != null && accounts.containsKey(o.AccountId)) {
                o.Description = accounts.get(o.AccountId).Name;
            }
        }
    }
}
```

**Rationale**: Single SOQL, processes full batch within governor limits.

---

## Example 2: Data Model Design

### Requirement

Track hotel reservations with guest info, check-in/out dates, and room assignment.

### Proposed Design

| Object | Purpose |
|--------|---------|
| Reservation__c | Main record; links to Account (guest), Room__c |
| Room__c | Room entity; lookup to Property__c |
| Property__c | Hotel property |

**Fields on Reservation__c:**
- Guest__c (Lookup to Account)
- Room__c (Lookup to Room__c)
- Check_In__c (Date)
- Check_Out__c (Date)
- Status__c (Picklist: Pending, Confirmed, Checked In, Checked Out, Cancelled)

**Rationale**: Separate objects for Property, Room, and Reservation allow reuse and reporting. Lookups avoid cascade delete; Status picklist supports workflow/flow logic.

---

## Example 3: Metadata Design Suggestion

### Problem

Users need to prevent duplicate Contacts by Email on the same Account.

### Proposed Changes

1. **Duplicate Rules (preferred)**:
   - Matching Rule: Email + AccountId
   - Duplicate Rule: Block on create/edit

2. **Flow (if custom logic needed)**:
   - Record-triggered flow on Contact create/update
   - Get Records: Contact where AccountId = record.AccountId AND Email = record.Email AND Id != record.Id
   - If count > 0, fault with error message

3. **Trigger (if Flow cannot meet requirements)**:
   - Bulk query existing Contacts with same AccountId + Email from `Trigger.new`
   - Add `record.addError()` for duplicates

**Rationale**: Prefer Duplicate Rules (declarative, no code). Use Flow for simple custom logic; Trigger only when Flow cannot express the rule (e.g., complex branching).

---

## Example 4: LWC — reactive pattern vs renderedCallback anti-pattern

### Requirement

Display a formatted member tier badge that updates whenever the member's tier changes.

### Before (anti-pattern)

```javascript
// memberBadge.js — BAD
renderedCallback() {
    this.badgeLabel = this.tier === 'Platinum' ? 'PLAT' : this.tier.substring(0, 3).toUpperCase();
    // Problem: mutating reactive property in renderedCallback → infinite re-render loop
}
```

### After (correct reactive pattern)

```javascript
// memberBadge.js — GOOD
import { LightningElement, api, track } from 'lwc';

export default class MemberBadge extends LightningElement {
    @api tier;

    get badgeLabel() {
        if (!this.tier) return '';
        return this.tier === 'Platinum' ? 'PLAT' : this.tier.substring(0, 3).toUpperCase();
    }

    get badgeClass() {
        return `badge badge--${(this.tier || '').toLowerCase()}`;
    }
}
```

```html
<!-- memberBadge.html -->
<template>
    <span class={badgeClass} aria-label={tier}>{badgeLabel}</span>
</template>
```

**Rationale**: Use computed getters for derived display values — they recalculate reactively when `@api tier` changes. No `renderedCallback` needed. No infinite loop risk.

---

## Example 5: Sharing Design — OWD and Sharing Rules

### Requirement

Loyalty program members should see only their own `LoyaltyTransactionJournal` records. Customer Success agents should see all records for members they own. Administrators and Integration users must see all records.

### Proposed Design

**Object OWD:** Private (only record owner and roles above in hierarchy can see)

**Sharing Rules:**
- Role-based: "Customer Success" role → Read/Write access to records owned by users in "Member" role
- Criteria-based: `Status__c = 'Active'` → Read access for "Reporting" public group

**Apex Managed Sharing (for dynamic sharing logic):**

```apex
public without sharing class MemberJournalSharingService {
    // Called after member assignment changes
    public static void shareJournalsWithAgent(Id agentUserId, Id memberId) {
        List<LoyaltyTransactionJournal__Share> shares = new List<LoyaltyTransactionJournal__Share>();
        for (LoyaltyTransactionJournal__c j : [
            SELECT Id FROM LoyaltyTransactionJournal__c WHERE MemberId__c = :memberId
        ]) {
            shares.add(new LoyaltyTransactionJournal__Share(
                ParentId = j.Id,
                UserOrGroupId = agentUserId,
                AccessLevel = 'Edit',
                RowCause = Schema.LoyaltyTransactionJournal__Share.RowCause.Manual
            ));
        }
        if (!shares.isEmpty()) insert shares;
    }
}
```

**Rationale**: OWD Private + role hierarchy covers most cases declaratively. Apex Managed Sharing handles dynamic agent assignment without creating a sharing rule explosion.

---

## Example 6: Flow Fault Path — missing vs correct

### Requirement

A record-triggered flow on `LoyaltyProgramMember` calls an Apex invocable action to sync member data to an external partner system.

### Before (missing fault path — BAD)

```
[Record Trigger: LoyaltyProgramMember - after update]
  → [Apex Action: Sync Member to Partner]
  → [END]
```

**Problem**: If the Apex action throws an exception (e.g., callout timeout, partner system unavailable), the flow throws a generic "An unhandled fault has occurred" error to the user. No logging. No retry opportunity.

### After (correct fault handling)

```
[Record Trigger: LoyaltyProgramMember - after update]
  → [Apex Action: Sync Member to Partner]
       ├── SUCCESS → [END]
       └── FAULT  → [Create Record: Integration_Error_Log__c
                         Object_API_Name__c = 'LoyaltyProgramMember'
                         Record_Id__c = {!$Record.Id}
                         Error_Message__c = {!$Flow.FaultMessage}
                         Flow_Name__c = 'LPM_SyncToPartner'
                         Timestamp__c = {!$Flow.CurrentDateTime}]
                   → [Custom Notification or Platform Event: alert integration team]
                   → [END]
```

**Rationale**: All Apex action elements in flows must have a fault connector. Log the `{!$Flow.FaultMessage}` for debugging. Never let a fault silently end the flow without a record of what failed.

---

## Example 7: Security — SOQL injection fix and FLS enforcement

### Requirement

An Apex endpoint accepts a search term from an LWC component and queries `LoyaltyProgramMember` by name.

### Before (vulnerable — BAD)

```apex
@AuraEnabled
public static List<LoyaltyProgramMember> searchMembers(String searchTerm) {
    // SOQL injection: user can pass "' OR Name != null OR Name = '"
    String query = 'SELECT Id, Name, BonvoyID__c FROM LoyaltyProgramMember WHERE Name LIKE \'%' + searchTerm + '%\'';
    return Database.query(query);
    // No FLS enforcement — returns fields regardless of user permissions
}
```

### After (secure — GOOD)

```apex
@AuraEnabled(cacheable=true)
public static List<LoyaltyProgramMember> searchMembers(String searchTerm) {
    if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
        return new List<LoyaltyProgramMember>();
    }
    // Bind variable prevents injection; LIKE with bind is safe
    String searchPattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';
    List<LoyaltyProgramMember> results = [
        SELECT Id, Name, BonvoyID__c, MemberStatus
        FROM LoyaltyProgramMember
        WHERE Name LIKE :searchPattern
        WITH SECURITY_ENFORCED
        LIMIT 50
    ];
    return results;
}
```

**Key fixes:**
1. Bind variable (`:searchPattern`) prevents SOQL injection even if `escapeSingleQuotes` is somehow bypassed
2. `WITH SECURITY_ENFORCED` enforces FLS — query fails cleanly if user lacks access to any selected field
3. Input validation (blank check, length minimum) prevents unnecessary queries
4. `LIMIT 50` prevents unbounded result sets
5. `cacheable=true` on read-only search reduces server calls
