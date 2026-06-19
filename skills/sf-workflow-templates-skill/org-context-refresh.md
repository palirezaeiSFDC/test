# Workflow: Org Context Refresh

**Use when:** The org has changed and `org-context.md` needs to be updated (run periodically or after deployments).
**Agents:** org-agent (verify) → parent updates org-context.md
**Mode:** Agent

---

Target org: [TARGET_ORG]
Scope: All standard loyalty objects + custom objects from org-context.md

Use sf-org-agent to:
1. Run describeGlobal and filter for all Loyalty*, TransactionJournal, Voucher, Promotion*, Benefit*, JournalType, JournalSubType, GameDefinition, GameParticipant, GameReward, DigitalPass*, LoyaltyAggrPointExprLedger, LoyaltyLedger*, LoyaltyMembership* objects — report which exist
2. For each custom object listed in `.cursor/skills/sf-loyalty-management-skill/org-context.md`: verify existence in the org (do not hardcode object names here — read from org-context.md)
3. Verify Platform Events listed in org-context.md
4. Verify Custom Metadata Types listed in org-context.md
5. For LoyaltyProgramMember: verify custom fields listed in org-context.md
6. For LoyaltyProgram: verify custom fields listed in org-context.md
7. Report any new objects/fields not currently in org-context.md
8. Report any objects/fields in org-context.md that no longer exist

After org-agent reports:
- Update .cursor/skills/sf-loyalty-management-skill/org-context.md with:
  - New objects/fields found (add with "Yes")
  - Objects/fields that no longer exist (mark as "No — removed YYYY-MM-DD")
  - Update the "Last Verified" date to today
