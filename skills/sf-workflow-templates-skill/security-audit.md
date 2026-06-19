# Workflow: Salesforce Org Security Audit

**Use when:** Conducting a comprehensive security review of a Salesforce org — sharing model analysis, profile/permission-set over-provisioning, FLS audit, connected apps, guest user access, session settings, Shield evaluation, and WAF Security Pillar alignment.
**Agents:** sf-org-agent (model: fast) + sf-research-agent (model: inherit) in parallel → parent synthesizes inline
**Mode:** Plan (read-only org analysis; no changes made)

---

**Input parameters:**
- `Target org alias` (required)
- `Scope` (optional): sharing | permissions | fls | connected-apps | session | shield | all (default: all)
- `Objects in scope` (optional): specific objects for FLS/sharing analysis

**Workflow steps:**

1. Input validation
   - Confirm org alias is provided; ask if missing.
   - Confirm scope (default: all). List objects in scope if provided.
   - Resolve org context: sf-org-agent → list_all_orgs → confirm alias is authorized.

2. [PARALLEL] Security configuration retrieval (sf-org-agent) + Research context (sf-research-agent)

   sf-org-agent retrieves (scope-dependent):
   - Sharing settings: Organization.DefaultAccountAccess, DefaultOpportunityAccess, DefaultLeadAccess, and related OWD settings
   - Profiles over-provisioned: query Profile for those with System Administrator or Modify All Data
   - Permission sets: query PermissionSet + PermissionSetAssignment for over-provisioned sets
   - FLS (if objects specified): query FieldPermissions for specified objects across Profiles/PermSets
   - Guest user profile: query Profile WHERE Name LIKE '%Site Guest%'; check object/field permissions
   - Connected apps: retrieve via metadata (ConnectedApp.*) or query ConnectedApplication
   - Named credentials: retrieve via metadata (NamedCredential.*)
   - Session settings: retrieve via SecuritySettings metadata
   - IP restrictions: query LoginIpRange on Profile
   - Shield: query TenantUsageEntitlement for Platform Encryption, Event Monitoring entitlements

   sf-research-agent provides:
   - WAF Security Pillar checklist assessment based on org configuration retrieved
   - Risk severity classification for each finding category
   - Remediation priority recommendations

3. Parent synthesizes inline Security Audit Report with these sections:
   a. Executive Summary — overall security posture score (High/Medium/Low risk), top 3 critical findings
   b. Sharing Model Analysis — OWD settings, public groups risk, apex sharing, criteria-based sharing
   c. Profile & Permission Set Over-Provisioning — table: Profile/PermSet | Issue | Risk | Recommendation
   d. FLS Audit — table: Object | Field | Profile/PermSet | Access | Risk (for specified objects)
   e. Guest User Access — list of exposed objects/fields, public site access, risk assessment
   f. Connected Apps & OAuth — table: App Name | Scopes | Users | Risk
   g. Named Credentials — list with authentication type and usage assessment
   h. Session & IP Settings — MFA status, session timeout, IP restrictions assessment
   i. Shield Encryption — entitlement status, encrypted fields (if Shield enabled), key management
   j. WAF Security Pillar Alignment — pillar item | Status (Met/Partial/Not Met) | Gap | Action
   k. Prioritized Remediation Backlog — table: Priority | Finding | Effort | Recommendation

4. Tell the user: "Security Audit complete. This session is in Plan mode — copy the output above and switch to Agent mode to save it to a file (suggested filename: docs/SecurityAudit_[OrgAlias]_[date]_v1.md)."
