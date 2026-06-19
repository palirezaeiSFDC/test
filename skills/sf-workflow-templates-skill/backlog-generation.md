# Workflow: Jira Backlog Generation from Confluence Spec

**Use when:** A Confluence specification exists and needs to be broken into a Jira epic with implementation tickets.
**Agents:** parent (reads Confluence directly, creates Jira tickets)
**Mode:** Agent

---

Confluence spec page: [URL or page title]
Target Jira project: [[JIRA_PROJECT_KEY]]
Epic name: [Feature name]

1. **Parent reads Confluence directly** (do NOT spawn sf-research-agent for this step):
   - Call `user-atlassian` → `getConfluencePage` for [URL] to read the specification
   - Analyze the specification and identify all discrete implementation tasks
   - Group tasks by component type: Apex, LWC, Flow, Metadata, Configuration, Testing
   - Estimate complexity for each (Low/Medium/High)
   - Produce a structured task breakdown

2. Use direct `user-atlassian` MCP calls to create and link backlog items:
   - Call `createJiraIssue` to create a Jira Epic in project [[JIRA_PROJECT_KEY]] for: [Epic name]
   - Call `createJiraIssue` for each child ticket with: summary, description, acceptance criteria, component label, estimated complexity
   - Call `createIssueLink` to link each child ticket to the epic

3. After creation, confirm: return the list of created ticket keys and their URLs
