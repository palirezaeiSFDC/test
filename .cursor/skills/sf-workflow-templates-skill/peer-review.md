# Workflow: Peer Code Review

**Use when:** Performing review of implementation by team member(s) for quality gate review before merge.
**Agents:** org-agent (retrieve) → review-agent + research-agent (parallel) → dev-agent (remediation plan) → Jira
**Mode:** Agent

---

Team / Individual(s): [Name]
Delivery: [Description of what was delivered, e.g., "Stay accrual trigger and handler"]
Files: [List file paths or "retrieve from org alias [alias]"]
Related Jira: [[JIRA_TICKET]]

Phase 1 — Retrieve (if files not yet local):
1. Use sf-org-agent to:
   - Retrieve the following components from org [alias]: [list ApexClass names, trigger names]
   - Save to force-app/main/default/classes/ and triggers/

Phase 2 — Run in PARALLEL after retrieval:
2. Use sf-review-agent to:
   - Perform a full mechanical review of all retrieved files
   - Apply the complete checklist including Loyalty Management-specific patterns
   - Produce findings table

3. Use sf-research-agent to:
   - Perform a deep architecture and security review of the same files
   - Assess trigger framework adherence, governor limit design, and security surface
   - Identify any patterns that will not scale to [expected volume] records

Phase 3 — Remediation Plan:
When both reviews complete:
4. **Conditional synthesis:**
   - If findings contain only Suggestions (no Critical or Warning): **Parent synthesizes directly** — produce a prioritized Remediation Plan and Suggestions list without spawning sf-dev-agent.
   - If findings contain Critical or Warning items: Use **sf-dev-agent** to:
     - Synthesize all findings
     - Produce a prioritized Remediation Plan: Critical fixes required before merge, Warnings recommended before merge, Suggestions for future improvement
     - Propose specific code fixes for all Critical and Warning items
