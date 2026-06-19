# Workflow: Feature Implementation

**Use when:** Implementing a new feature end-to-end from a Jira ticket or Confluence spec.
**Agents:** research-agent + org-agent (parallel) → dev-agent → review-agent
**Mode:** Agent

---

Feature: [Brief description or Jira ticket: [JIRA_TICKET]]
Confluence spec: [URL or page title, or "N/A"]

**Guard rails:**
- **Sub-agent failure handling:** If sf-research-agent fails or times out in Phase 1, continue with org-agent results only and flag design gaps to the user before proceeding to Phase 2. If sf-org-agent fails in Phase 1, continue with local workspace discovery only and note unverified metadata.
- **Remediation iteration cap:** The review-remediation cycle in Phase 3 must not exceed **2 cycles**. After 2 cycles, report remaining issues to the user as a "Residual Issues" list with recommended next steps — do not continue auto-remediating.

Run Phase 1 in PARALLEL:
1. Use sf-research-agent to:
   - Read the Jira ticket [[JIRA_TICKET]] and/or Confluence page [URL]
   - Research design options for [feature area] against Salesforce documentation
   - Apply the sf-loyalty-management-skill skill if loyalty objects are involved
   - Produce a Solution Design with at least 2 options, pros/cons, recommendation, and list of org verification items
   - **On failure/timeout:** Parent notes "Research-agent unavailable — proceeding with org-agent results; design gaps flagged below" and continues to Phase 2.

2. Use sf-org-agent to:
   - Verify that the following objects/fields exist in the org: [list objects and fields referenced in the spec]
   - Check the local workspace for existing Apex classes or flows related to [feature area]
   - Report any gaps vs the proposed solution
   - **On failure/timeout:** Parent notes "Org-agent unavailable — proceeding with local workspace discovery only; unverified metadata flagged below" and continues.

When Phase 1 is complete (or after handling failures), run Phase 2:
3. Use sf-dev-agent to:
   - Read the research-agent's solution design and org-agent's verification report (or available partial results)
   - Produce an Implementation Plan (components to create/modify, sequence, test strategy)
   - Await user approval of the plan
   - After approval: implement the code locally in force-app/main/default/
   - Self-review using the sf-analysis-design-skill skill
   - Generate the Technical Design Document and save to docs/[Solution_Design_FeatureName_v1.md]

After implementation, run Phase 3 (max 2 review-remediation cycles):
4. Use sf-review-agent to:
   - Perform a mechanical first-pass review of all new/modified Apex files
   - Report findings by severity; flag items needing deep review

5. If review-agent flags Critical or Warning items needing architectural input:
   - Use sf-dev-agent to address Critical findings
   - Optionally use sf-research-agent for any architectural escalations
   - **Cycle 2:** If new issues arise after first remediation, repeat review-agent check once more (cycle 2). After 2 cycles total, output "Residual Issues" list and ask the user for next steps.
