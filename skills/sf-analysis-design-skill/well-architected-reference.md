# Well-Architected Framework (WAF) Reference

Salesforce Well-Architected defines 5 pillars. Use as a review lens on designs and code deliverables.

---

## 1. Trusted (Security & Compliance)

| Check | Guidance |
|---|---|
| Apex sharing | All classes declare `with sharing` unless justified |
| FLS enforcement | `WITH SECURITY_ENFORCED` or `Security.stripInaccessible` in all DML paths |
| Input validation | No SOQL injection; all external input sanitized |
| Credentials | Named Credentials only; no secrets in code or CMT |
| Guest user | No "View All" or "Modify All" on guest profile |
| Shield / Encryption | Evaluate for PII fields (loyalty member data, external IDs) |

## 2. Easy (Usability & Maintainability)

| Check | Guidance |
|---|---|
| One trigger per object | `GenericTriggerDispatcher` pattern enforced |
| Service/Selector separation | No SOQL or DML scattered in handlers or LWC controllers |
| Flow element naming | Meaningful names; no "Decision 1", "Assignment 2" |
| Code comment quality | Comments explain *why*, not *what*; no outdated comments |
| Flow vs Apex choice | Flow for declarative; Apex only when Flow cannot express the requirement |
| Test coverage | 85%+ meaningful coverage; bulk, negative, and permission scenarios |

## 3. Resilient (Reliability & Error Handling)

| Check | Guidance |
|---|---|
| Bulkification | All Apex processes all records in `Trigger.new`; no SOQL/DML in loops |
| Async error handling | Queueable/Batch `execute()` wrapped in try-catch with error logging |
| Platform Event replay | Subscribers handle replay correctly; idempotent processing |
| Flow fault paths | Every Apex action and DML element has a fault connector |
| Callout timeout | All callout methods set `HttpRequest.setTimeout()`; handle timeout exceptions |
| Retry logic | Idempotent operations support safe retry; non-idempotent operations have dedup |

## 4. Performant (Efficiency at Scale)

| Check | Guidance |
|---|---|
| Query selectivity | Leading WHERE clause on indexed field; avoid `LIKE '%value%'` on large objects |
| Async for bulk | Large-record processing uses Batch Apex or Queueable chains, not synchronous |
| Platform Cache | Frequently-read, rarely-changed data (program config, tier thresholds) cached |
| LDV awareness | Objects with >1M records flagged; skinny table or archive strategy evaluated |
| LWC rendering | No DOM thrashing; no expensive computation in `renderedCallback` |

## 5. Adaptable (Flexibility & Configurability)

| Check | Guidance |
|---|---|
| Custom Metadata Types | Configurable thresholds, rules, and mappings stored in CMT (not hardcoded) |
| Custom Labels | User-facing strings and error messages in Custom Labels (not literals) |
| Feature flags | Behavior switches in CMT; no code deploys to toggle features |
| Standard-first | Standard objects preferred over custom equivalents |
| API version currency | Components on latest (or within 2) API versions; no EOL API versions in production |

---

## WAF Rating in Output

When producing design reviews or impact assessments, add a WAF alignment summary:

```
WAF Alignment:
- Trusted: PASS — FLS enforced, Named Credentials used, with sharing declared
- Easy: PARTIAL — Service/Selector pattern followed; Flow element names need cleanup
- Resilient: FAIL — Queueable has no error handling in execute(); fault path missing on Flow DML element
- Performant: PASS — Selective queries confirmed; Platform Cache used for program config
- Adaptable: PARTIAL — Tier thresholds hardcoded; recommend CMT migration
```

---

## Output Templates

### Feedback Severity

- **Critical**: Must fix before merge (governor limit risk, security, bulkification, data loss)
- **Warning**: Should fix before merge (pattern violations, missing error handling, test gaps)
- **Suggestion**: Consider improving (readability, maintainability, adaptability)
- **Nice-to-have**: Optional enhancement (performance micro-optimization, cosmetic)

---

### Template 1: Code Review Report

```markdown
## Code Review: [ClassName / ComponentName]
**Reviewer:** sf-review-agent  
**Date:** [date]  
**Jira:** [ticket]

### Findings

| # | Severity | Location | Issue | Recommended Fix |
|---|---|---|---|---|
| 1 | Critical | `MemberHandler.cls:45` | SOQL inside for loop — governor limit failure at bulk | Move query above loop; use Map by Id |
| 2 | Warning | `MemberHandler.cls:12` | Class missing `with sharing` declaration | Add `with sharing` |
| 3 | Warning | `memberBadge.js:22` | Logic in `renderedCallback` mutates tracked property | Move to computed getter |
| 4 | Suggestion | `MemberHandler.cls:67` | Magic string `'Active'` hardcoded | Extract to constant or Custom Label |

### WAF Alignment
- Trusted: FAIL — missing `with sharing`, FLS not enforced
- Resilient: FAIL — SOQL in loop
- Easy: PARTIAL — logic in renderedCallback; magic strings

### Required Before Merge
- [ ] Fix items #1 and #2 (Critical / Warning — security and governor limit)
- [ ] Fix item #3 (Warning — LWC render loop risk)
```

---

### Template 2: Metadata Design Recommendation

```markdown
## Metadata Design: [Feature / Requirement Title]

### Problem
[1-2 sentences describing the business requirement or gap]

### Option A: [Preferred Approach]
**Components:**
- [Object/Field/Flow/Rule and its purpose]

**Pros:** [List]  
**Cons:** [List]  
**Effort:** [Low / Medium / High]

### Option B: [Alternative]
**Components:**
- [...]

**Pros:** [List]  
**Cons:** [List]  
**Effort:** [Low / Medium / High]

### Recommendation
Option A — [one sentence rationale].

### WAF Notes
- Trusted: [assessment]
- Adaptable: [e.g., CMT used for configurable thresholds]
```

---

### Template 3: Solution Option Analysis

```markdown
## Solution Options: [Feature Name]
**Context:** [Brief problem statement]  
**Jira:** [ticket]  
**Org:** [[TARGET_ORG], API 66.0]

---

### Option 1: [Name — e.g., Record-triggered Flow]

**Approach:** [1-2 sentence description]

**Fits requirements?**
- [Req 1]: Yes / No / Partial

**Risks:**
- [Risk 1]

**Governor limit exposure:** [Low / Medium / High — why]  
**Effort:** [Story points or T-shirt size]  
**Maintainability:** [Admin-maintainable / Developer-required]

---

### Option 2: [Name — e.g., Apex Trigger + Service]

[same structure as Option 1]

---

### Recommendation

**Recommended:** Option [N] — [one sentence rationale].

**Conditions / constraints:** [Any prerequisites, dependencies, or caveats]

### WAF Alignment
| Pillar | Option 1 | Option 2 |
|---|---|---|
| Trusted | PASS | PASS |
| Easy | HIGH (admin) | MEDIUM (dev) |
| Resilient | MEDIUM | HIGH |
| Performant | LOW | HIGH |
| Adaptable | HIGH | MEDIUM |
```

---

### Template 4: Design Suggestion (Inline)

```markdown
**Problem:** [Brief description of the issue]  
**Proposed change:** [What to change and where]  
**Rationale:** [Why it matters — governor limit, security, maintainability, WAF pillar]  
**Severity:** Critical / Warning / Suggestion
```
