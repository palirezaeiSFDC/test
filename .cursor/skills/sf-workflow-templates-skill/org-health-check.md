# Workflow: Org Health Check

**Use when:** Performing a platform limits audit, security review, performance assessment, or technical debt scan across a Salesforce org.
**Agents:** org-agent (org data) + research-agent (analysis) in parallel → parent synthesizes inline
**Mode:** Plan

---

Target org: [TARGET_ORG]
Scope: [limits | security | performance | technical-debt | entitlements | all] (default: all)

**Guard rails:**
- If sf-org-agent fails/times out, proceed with research-agent findings only; flag as "Org data unavailable — manual verification required."
- Output inline in the plan document; do not auto-write to docs/. Ask user for file-write preference at end.

Run Phase 1 in PARALLEL:

1. Use sf-org-agent to:
   **Platform Limits Audit:**
   - Query LimitInfo for: DailyApiRequests, DailyBulkApiRequests, DailyWorkflowEmails, ActiveScratchOrgs, HourlyTimeBasedWorkflow
   - Run SOQL: SELECT OperationType, RequestsUsed, RequestsLastResetTime FROM AsyncApexJob LIMIT 50
   - Run SOQL: SELECT ApexClassName, NumLongRunningRequests, TotalInvocations FROM ApexCodeCoverage LIMIT 50
   - Check storage: SELECT SUM(BodyLength) TotalBytes FROM ApexClass

   **Security Audit:**
   - Run SOQL: SELECT Name, PermissionsModifyAllData, PermissionsViewAllData FROM Profile WHERE PermissionsModifyAllData = true LIMIT 50
   - Verify guest user profile access: check if Guest User profiles have field-level security on sensitive fields
   - Check for public groups with broad sharing rules (describe sharing model for top 5 custom objects)

   **Performance Indicators:**
   - Run SOQL: SELECT ApexClassName, NumLongRunningRequests FROM ApexCodeCoverage ORDER BY NumLongRunningRequests DESC LIMIT 20
   - Check for triggers without bulkification indicators: list all ApexTrigger metadata

   **Technical Debt Scan:**
   - List all Apex classes with test coverage < 75%: SELECT Name, NumLinesCovered, NumLinesUncovered FROM ApexCodeCoverage ORDER BY NumLinesUncovered DESC LIMIT 30
   - List flows with status = 'Active' and API version < 58: SELECT DeveloperName, ApiVersion, Status FROM FlowDefinitionView WHERE Status = 'Active' AND ApiVersion < 58 LIMIT 50

   **Entitlement & License Audit (run when scope includes 'entitlements' or 'all'):**
   - User licenses used vs. total: SELECT Name, UsedLicenses, TotalLicenses FROM UserLicense ORDER BY UsedLicenses DESC
   - Permission set licenses: SELECT MasterLabel, UsedLicenses, TotalLicenses FROM PermissionSetLicense ORDER BY UsedLicenses DESC
   - Feature entitlements: SELECT Setting, Value FROM TenantUsageEntitlement (note: not all tenants support this; handle gracefully if unavailable)
   - Sandbox entitlements: query SandboxInfo if available; list sandbox types and used vs. allowed
   - API usage: SELECT UserId, ApiType, CallsUsed, CallsAllowed FROM UserApiUsage LIMIT 50

2. Use sf-research-agent to:
   - Analyze org-agent's findings against Salesforce Well-Architected principles
   - Assess governor limit risk levels (Critical/Warning/Low) for each finding
   - Identify security model gaps and sharing model risks
   - Flag performance anti-patterns and technical debt priority items
   - Reference: .cursor/skills/sf-shared-reference/SKILL.md for documentation URLs

Phase 2 — Synthesis (parent synthesizes directly):
- Do NOT spawn sf-dev-agent for synthesis
- Produce a structured Health Check Report with sections:
  1. Executive Summary (RAG status: Red/Amber/Green per scope area)
  2. Platform Limits — findings table: Limit | Current Usage | Threshold | Risk | Recommendation
  3. Security — findings table: Area | Finding | Severity | Recommendation
  4. Performance — findings table: Component | Issue | Impact | Recommendation
  5. Technical Debt — findings table: Category | Count | Priority | Next Action
  6. Entitlements & Licenses (if in scope) — table: License/Entitlement | Used | Total | Utilization % | Risk (over/under-licensed)
- Tell the user: "Org Health Check complete. This session is in Plan mode — copy the output above and switch to Agent mode to save it to a file (suggested filename: docs/OrgHealthCheck_[date]_v1.md)."
