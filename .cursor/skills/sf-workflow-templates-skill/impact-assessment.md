# Workflow: Impact Assessment

**Use when:** Assessing the impact of a proposed change (migration, new feature, object change, API change) before implementation begins.
**Agents:** explore + org-agent + research-agent (parallel) → parent synthesizes directly
**Mode:** Plan

---

Change: [Brief description of proposed change]
Reference: [Jira ticket [JIRA_TICKET], Confluence page URL, or design doc path]

Run in PARALLEL:
1. Use explore (fast) to:
   - Search force-app/main/default/ for all Apex classes, triggers, flows, and LWC that reference: [list of affected objects, fields, or API names]
   - Return file paths, line numbers, and brief context for each reference

2. Use sf-org-agent to:
   - Verify that [affected objects and fields] exist in the org with their current configuration
   - Describe [specific objects] and return field types, required flags, and relationships
   - Query: SELECT Id, [key fields] FROM [Object] LIMIT 5 to validate data exists

3. Use sf-research-agent to:
   - Analyze the architectural and dependency implications of [the change]
   - Reference the sf-loyalty-management-skill skill for loyalty-specific impacts
   - Assess governor limit risks, sharing model impacts, and integration touchpoints
   - Cite Salesforce documentation for any platform constraints

When all three complete:
4. **Parent synthesizes directly** (do NOT spawn sf-dev-agent for this step — parent already has all outputs in context):
   - Synthesize findings from all three agents
   - Produce the complete Impact Assessment inline, following doc-standards-rule
   - Identify: affected components (table), risk analysis (table), testing scope, deployment notes
   - After outputting, tell the user: "The Impact Assessment is complete. This session is in Plan mode — copy the output above and switch to Agent mode to save it to a file."
