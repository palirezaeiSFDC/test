# Salesforce Analysis & Design — Reference

## Governor Limits (Synchronous Transaction)

| Limit | Value |
|-------|-------|
| SOQL queries | 100 |
| DML statements | 150 |
| DML rows | 10,000 |
| Heap size | 6 MB |
| CPU time | 10,000 ms |
| Callouts | 100 |
| Future/Queueable invocations | 50 |

---

## Trigger Best Practices

### Bulkification Pattern

```apex
trigger AccountTrigger on Account (before insert, before update) {
    AccountHandler.handleBeforeInsertUpdate(Trigger.new, Trigger.oldMap);
}

// Handler
public class AccountHandler {
    public static void handleBeforeInsertUpdate(List<Account> newList, Map<Id, Account> oldMap) {
        Set<Id> parentIds = new Set<Id>();
        for (Account a : newList) {
            if (a.ParentId != null) parentIds.add(a.ParentId);
        }
        Map<Id, Account> parents = new Map<Id, Account>([
            SELECT Id, Name FROM Account WHERE Id IN :parentIds
        ]);
        for (Account a : newList) {
            if (a.ParentId != null && parents.containsKey(a.ParentId)) {
                a.Description = parents.get(a.ParentId).Name;
            }
        }
    }
}
```

- Collect IDs/keys in a loop; run one SOQL outside the loop.
- Collect records to insert/update; run one DML outside the loop.

---

## LWC Best Practices

### Wire vs Imperative

- **Wire**: Use for reactive data that updates when params change. No manual refresh.
- **Imperative**: Use when you need to call on user action or when wire is not suitable.

### Error Handling

```javascript
@wire(getRecord, { recordId: '$recordId', fields: ACCOUNT_FIELDS })
wiredAccount({ error, data }) {
    if (data) this.account = data;
    if (error) this.error = reduceErrors(error);
}
```

### renderedCallback Anti-Pattern

```javascript
// BAD — causes infinite render loop
renderedCallback() {
    this.counter++;          // reactive property change → triggers re-render → loops
    this.doHeavyCalculation(); // expensive on every render
}

// GOOD — guard with a flag for one-time DOM setup
renderedCallback() {
    if (this._initialized) return;
    this._initialized = true;
    // DOM manipulation that cannot be done declaratively
    const el = this.template.querySelector('.my-element');
    if (el) el.focus();
}
```

### Lightning Message Service Pattern

```javascript
// Publisher
import { publish, MessageContext } from 'lightning/messageService';
import MEMBER_SELECTED_CHANNEL from '@salesforce/messageChannel/MemberSelected__c';

@wire(MessageContext) messageContext;

handleMemberSelect(event) {
    publish(this.messageContext, MEMBER_SELECTED_CHANNEL, {
        memberId: event.detail.memberId
    });
}

// Subscriber
import { subscribe, MessageContext } from 'lightning/messageService';
import MEMBER_SELECTED_CHANNEL from '@salesforce/messageChannel/MemberSelected__c';

@wire(MessageContext) messageContext;
subscription = null;

connectedCallback() {
    this.subscription = subscribe(
        this.messageContext,
        MEMBER_SELECTED_CHANNEL,
        (message) => this.handleMemberSelected(message)
    );
}

disconnectedCallback() {
    // Always unsubscribe to prevent memory leaks
    if (this.subscription) {
        import('lightning/messageService').then(({ unsubscribe }) => {
            unsubscribe(this.subscription);
        });
    }
}
```

### LWC Performance Review Checklist

- [ ] No reactive property mutations in `renderedCallback` without an initialization guard
- [ ] `@wire` adapters not called with undefined parameters until data is available (use conditional in template)
- [ ] Large lists use `lightning-virtual-scroller` or pagination — not full render of 1000+ rows
- [ ] `connectedCallback` does not make imperative Apex calls that could be `@wire`
- [ ] `disconnectedCallback` cleans up subscriptions and event listeners

---

## Flow vs Apex Decision Matrix

| Use Flow when | Use Apex when |
|---------------|---------------|
| Logic is declarative | Logic requires code (loops, callouts) |
| Admins maintain it | Developers maintain it |
| No callouts/platform events | Callouts, platform events, complex branching |
| Simple record updates | Bulk processing, governor limit control |

---

## Security Review Checklist

### Apex Sharing Model

| Declaration | When to Use |
|---|---|
| `with sharing` | Default for all classes; enforces record-level sharing rules |
| `without sharing` | Only when explicitly required (system-level operations, data migration utilities). Must be documented with justification |
| `inherited sharing` | Entry-point classes called from both sharing-enforced and system contexts; inherits the caller's sharing context |

**Rules:**
- Every `@AuraEnabled`, `@InvocableMethod`, and REST `@RestResource` class must declare `with sharing` unless there is a documented reason
- Inner classes inherit the outer class sharing unless explicitly declared
- Utility and selector classes: use `with sharing`; use `inherited sharing` only when the class must serve both contexts

### FLS Enforcement Methods

| Method | When to Use | Tradeoff |
|---|---|---|
| `WITH SECURITY_ENFORCED` | SOQL queries where you want inline FLS/CRUD enforcement | Throws `QueryException` on inaccessible fields — less granular control; entire query fails |
| `Security.stripInaccessible(AccessType.READABLE, records)` | After query, strip fields the user cannot read | Graceful degradation — returns partial data; use when partial data is acceptable |
| `Security.stripInaccessible(AccessType.CREATABLE, records)` | Before insert — strip fields the user cannot write | Prevents FLS violation on create |
| `Security.stripInaccessible(AccessType.UPDATABLE, records)` | Before update | Prevents FLS violation on update |
| Manual `SObjectType.fields.getMap()` check | Deprecated pattern; avoid | Verbose, error-prone, not recommended |

**Recommended default:** Use `WITH SECURITY_ENFORCED` in Selectors for read operations. Use `Security.stripInaccessible(CREATABLE/UPDATABLE)` before DML in Service classes.

### SOQL Injection Prevention

```apex
// VULNERABLE — never do this
String query = 'SELECT Id FROM Contact WHERE Name = \'' + userInput + '\'';
List<Contact> results = Database.query(query);

// SAFE — bind variable
List<Contact> results = [SELECT Id FROM Contact WHERE Name = :userInput];

// SAFE — dynamic SOQL with bind
String safeQuery = 'SELECT Id FROM Contact WHERE Name = :userInput';
List<Contact> results = Database.query(safeQuery); // bind variable still works in dynamic SOQL
```

**Additional SOQL injection checks:**
- [ ] No string concatenation of user-controlled input into SOQL strings
- [ ] If using `String.escapeSingleQuotes()`, verify it is applied to every user input segment — preferred approach is bind variables
- [ ] Dynamic field names from user input must be validated against `Schema.SObjectType.fields.getMap().keySet()`

### Endpoint and Credential Security

| Pattern | Secure | Notes |
|---|---|---|
| Named Credentials | Yes | Handles OAuth token refresh; no secrets in code |
| Custom Metadata + Named Credential | Yes | Configurable endpoint URLs per environment |
| Hardcoded endpoint URL in Apex | No | Fails in sandbox/prod promotion; expose in code review |
| Stored credential in Custom Setting/CMT | No | Not encrypted at rest; visible to admins |
| Protected Custom Metadata | Partial | Values not visible in UI but still not encrypted |

### Guest User Exposure

- [ ] Guest user profiles must not have "View All" or "Modify All" on any object
- [ ] Sharing settings for objects exposed via Community/Experience Cloud must use public read-only or stricter OWD
- [ ] Apex classes used by guest users must explicitly test `System.runAs(guestUser)` scenarios
- [ ] `@AuraEnabled` methods called by unauthenticated pages must validate input before DML

### Connected App and OAuth

- [ ] Verify OAuth scopes are minimal (avoid `full` or `refresh_token` unless required)
- [ ] Client credentials and secrets must be stored in Named Credentials, not in code or Custom Settings
- [ ] Token expiry and refresh logic must not log tokens to debug logs
- [ ] IP restrictions should be configured for internal integrations

### Checklist — Code Review Security Gate

- [ ] All Apex classes declare sharing explicitly
- [ ] All SOQL uses bind variables or `WITH SECURITY_ENFORCED`
- [ ] All DML in Service classes is preceded by `Security.stripInaccessible`
- [ ] No hardcoded credentials, endpoints, or IDs
- [ ] All external callouts use Named Credentials
- [ ] `@AuraEnabled` methods declare `with sharing`
- [ ] `@InvocableMethod` classes declare `with sharing`

---

## Common Metadata Types

| Type | Use when |
|------|----------|
| CustomObject | New business entity |
| CustomField | Attribute on existing object |
| ValidationRule | Declarative field validation |
| Flow | Record-triggered or screen flow |
| ApexTrigger | Code-based automation |
| ApexClass | Reusable logic, handlers |
| LightningComponentBundle | LWC component |
