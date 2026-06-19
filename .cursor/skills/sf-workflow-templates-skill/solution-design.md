# Workflow: Solution Design (Architecture Decision)

**Use when:** A new business requirement or platform capability needs a documented architectural decision.
**Agents:** research-agent + org-agent (parallel) → publish to Confluence
**Mode:** Plan

---

Design question: [e.g., "How should we integrate hotel POS stay data with Loyalty Management for accrual processing?"]
Constraints: [e.g., real-time vs batch, expected volume: X events/day, API limits, licensing]
Reference: [Jira epic [JIRA_TICKET], Confluence requirements page URL]

Run in PARALLEL:
1. Use sf-research-agent to:
   - Research at least 2 viable architectural options for [design question]
   - Apply sf-loyalty-management-skill skill for loyalty-specific context
   - For each option: describe approach, pros, cons, governor limit considerations, licensing requirements, Salesforce documentation links
   - Produce a recommendation with rationale
   - Include a Mermaid high-level architecture diagram
   - List objects/fields/metadata to verify in org

2. Use sf-org-agent to:
   - Verify that prerequisite objects and features exist in the org: [list from design question context]
   - Check if any relevant Flows, Apex classes, or Platform Events are already configured
   - Report feature flags enabled (e.g., DigitalPass, Gamification) that may affect the design

When both complete:
3. **Parent synthesizes directly** (do NOT spawn sf-research-agent again for this step — parent has both outputs in context):
   - Incorporate org-agent verification results into the design options
   - Flag any org gaps that affect option viability
   - Produce the final Solution Design document inline, following doc-standards-rule
   - After outputting, tell the user: "The Solution Design is complete. This session is in Plan mode — copy the output above and switch to Agent mode to save it to a file."

4. [Optional] Publish to Confluence:
   - Confirm with user: "I can publish the details as a document [document title] to Confluence space [space]. Confirm to proceed."
   - Use createConfluencePage to publish
   - Update the document's Confluence URL in the metadata header
   - [Optional] Create/update the Jira epic or user story [[JIRA_TICKET]] with a link to the design document
