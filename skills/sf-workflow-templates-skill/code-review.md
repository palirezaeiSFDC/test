# Workflow: Code Review (Full — Mechanical + Architectural)

**Use when:** Reviewing your own implementation (pre-merge review).
**Agents:** review-agent + research-agent (parallel) → consolidated report
**Mode:** Plan

---

Files to review: [list file paths, e.g., force-app/main/default/classes/[PROJECT_CLASS].cls]
Context: [Brief description of what the code does and the Jira ticket it implements: [JIRA_TICKET]]
Review type: [Pre-merge | Pre Org push | Periodic quality review]

Run in PARALLEL:
1. Use sf-review-agent to:
   - Perform a mechanical first-pass review of: [file list]
   - Apply the full review checklist (bulkification, FLS, naming, test patterns, trigger framework, async patterns)
   - If Loyalty Management objects are involved, load `sf-loyalty-management-skill/SKILL.md` and apply domain-specific checks (Business API usage, Platform Event handling, domain-specific field patterns)
   - Produce a structured findings table with Severity | Category | Location | Issue | Fix

2. Use sf-research-agent to:
   - Review the same files for: architecture anti-patterns, security risks (sharing, injection, secrets), governor limit design risks
   - Assess alignment with the Salesforce Well-Architected framework
   - Reference sf-analysis-design-skill skill
   - Flag any items that require refactoring strategy (escalate to dev-agent)

When both complete:
3. **Parent consolidates directly** (do NOT spawn another agent for this step):
   - Merge Critical findings first, then Warnings, then Suggestions
   - Remove duplicates (keep the finding with more detail)
   - List escalation items for dev-agent (refactoring, framework changes)
   - If items require refactoring or architectural changes, delegate those specific items to sf-dev-agent
