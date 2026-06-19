---
name: sf-loyalty-management-skill
description: Provides domain knowledge for Salesforce Loyalty Management product—data model, OOTB capabilities, APIs, and design best practices. Use when working with Loyalty Management, loyalty programs, LoyaltyProgram, LoyaltyProgramMember, TransactionJournal, promotions, vouchers, tiers, partners, or when designing/implementing loyalty solutions on Salesforce.
---

# Salesforce Loyalty Management

## Quick Start

Apply this skill when the user mentions: Loyalty Management, loyalty program, LoyaltyProgram, LoyaltyProgramMember, TransactionJournal, accrual, redemption, tiers, promotions, vouchers, partners, engagement attributes, loyalty API, BonvoyID, stay event, tier tenure, loyalty stay, Platform Event, POS integration.

**Data sources:** Use [sources.md](sources.md) for documentation URLs. For API class signatures and REST endpoints, use [api-reference.md](api-reference.md). For field-level detail on picklist values or method signatures not in `api-reference.md`, use the online [Apex Reference](https://developer.salesforce.com/docs/atlas.en-us.loyalty.meta/loyalty/loyalty_apex_reference.htm) or [Business APIs](https://developer.salesforce.com/docs/atlas.en-us.loyalty.meta/loyalty/loyalty_management_apis.htm) docs.

**Object reference:** For object lookups, assessment, and verification, use [objects-reference.md](objects-reference.md). Standard objects link to Salesforce API docs; use the **sf-org-agent** to verify existence in the connected org.

**Org context:** Reference [org-context.md](org-context.md) for verified custom objects and fields for the connected org.

---

## Data Model Overview

### Core Objects

| Object | Purpose |
|--------|---------|
| LoyaltyProgram | Root; members, tiers, currencies, partners, promotions |
| LoyaltyProgramMember | Member in a program (individual or corporate) |
| LoyaltyProgramCurrency | Qualifying (engagement) and non-qualifying (points) currencies |
| LoyaltyTierGroup | Tier groups; categorizes members by points |
| LoyaltyTier | Tiers within a tier group |
| LoyaltyMemberTier | Member's current tier across tier groups |
| LoyaltyMemberCurrency | Point balance per member per currency |
| LoyaltyLedger | Credits/debits for member transactions |
| TransactionJournal | Loyalty transactions (accrual, redemption, adjustments) |

Full list: [objects-reference.md](objects-reference.md).

### Supporting Objects

- **Journal/Types:** JournalSubType, JournalType
- **Partners:** LoyaltyProgramPartner, LoyaltyProgramPartnerLedger, LoyaltyPgmPtnrPrepaidPack, LoyaltyPgmPtnrLdgrSummary, LoyaltyPgmPartnerCurrency, LoyaltyPgmPartnerPromotion, LoyaltyPartnerProduct
- **Promotions:** Promotion, PromotionStage, PromotionLimit, PromotionChannel, PromotionProduct, PromotionProductCategory, PromotionLoyaltyPtnrProdt, PromotionMarketSegment, PromotionPartyUsage, PromotionStageEmailTemplate, PromotionLimitUsage
- **Benefits:** Benefit, BenefitType, BenefitParameterValue, MemberBenefit, LoyaltyTierBenefit
- **Product/Catalog:** Product2, ProductCatalog, ProductCategory, ProductCategoryProduct
- **Vouchers:** VoucherDefinition, Voucher
- **Clubs:** Loyalty Clubs data model (interest-based memberships)
- **Gamification:** GameDefinition, GameParticipant, GameReward (API 60.0+)
- **Digital passes:** DigitalPassTemplate, DigitalPass (API 66.0+)
- **Custom (from objects-reference.md):** Exception_Log__c, BonvoyID_Number_Pool__c, Global_Benefit_Mapping__c, Property_Product_Mapping__c, Benefit_Choice__c, Bonvoy_Hashkey_Pool__c, Brand__c, Loyalty_Stay__c, Rate_Plan_Exception__c, Referral_Type__c, Stay_Eligibility_Rule__c, data_cloud__Data_Cloud_Failure__c
- **Standard (partner linking):** LoyaltyPgmMbrLinkedPtnr (replaces deprecated Member_Partner_Link__c; API 66.0+)

See [reference.md](reference.md) for object relationships and API versions.

**Marriott custom extensions** (see [org-context.md](org-context.md)): Loyalty_Stay__c, Loyalty_Stay_Event__e, Loyalty_Tier_Tenure_Configuration__mdt; custom fields BonvoyID__c, PropertyCode__c, BrandCode__c; trigger handlers LoyaltyProgramMemberTriggerHandler, LoyaltyStayTriggerHandler.

---

## OOTB Capabilities

- **Member management:** Enroll, tier assignment, merge
- **Points:** Accrual, redemption, expiration (LoyaltyAggrPointExprLedger for fixed-model)
- **Partners:** Accrual/redemption partners; prepaid packs; postpaid billing
- **Promotions:** Enrollment, limits, channels, product/category eligibility
- **Vouchers:** Definitions and issuance
- **Invocable actions:** Standard and custom; use in Flows
- **Business APIs:** Apex classes for programmatic operations
- **OmniStudio:** FlexCards and widget templates (LoyaltyProgramWidget)

### Loyalty Rules Engine (Loyalty Processes)

`LoyaltyProgramProcess` is the orchestration layer that controls how transaction journals, tier assessments, and promotions are processed. Key concepts:

- **Process types:** Accrual, Redemption, Tier Processing, Qualification, Points Expiration, Promotion
- **Step types:**
  - **Condition:** Evaluate criteria (field comparisons, formula expressions) to branch logic
  - **Action:** Execute an operation (award points, issue voucher, update tier, call invocable action)
  - **Subroutine:** Call another LoyaltyProgramProcess for reusable logic
- **Decision Tables:** Lookup tables within the Business Rules Engine (BRE) that map inputs to outputs for complex multi-condition scenarios. Linked to processes via dataset links that map object fields to decision table inputs
- **Batch processes:**
  - **Tier assessment:** Scheduled batch evaluates members for tier upgrades/downgrades based on qualifying points
  - **Points expiration:** Batch expires non-qualifying points based on configured rules
  - **Qualifying points reset:** Resets on fixed date or enrollment anniversary per tier group configuration
- **Execution:** When a TransactionJournal is created, the matching LoyaltyProgramProcess runs its steps in sequence, evaluating conditions and executing actions

See [sources.md](sources.md) for Loyalty Processes and Decision Tables documentation links.

### Loyalty Connect / REST APIs

Programmatic entry points for loyalty operations (prefer these over raw DML):

| API / Class | Purpose |
|-------------|---------|
| `loyalty.IndividualMemberInput` / `IndividualMemberOutput` | Enroll individual members programmatically |
| `loyalty.CorporateMemberInput` / `CorporateMemberOutput` | Enroll corporate/group members |
| `loyalty.LoyaltyEngineInput` / `LoyaltyEngineOutput` | Run the loyalty engine (process journals, trigger rules) |
| `loyalty.MemberPointsInput` / `MemberPointsOutput` | Credit/debit points for a member |
| `loyalty.MemberTierInput` / `MemberTierOutput` | Assess or update member tier |
| `loyalty.MemberBenefitInput` / `MemberBenefitOutput` | Assign or manage member benefits |
| `loyalty.VoucherInput` / `VoucherOutput` | Issue or manage vouchers |
| `loyalty.MemberPromotionInput` / `MemberPromotionOutput` | Enroll members in promotions |

**Connect API endpoints** (`/services/data/vXX.0/loyalty/programs/`):
- Member enrollment, profile update, merge
- Transaction journal creation and processing
- Tier assessment and override
- Voucher issuance and redemption
- Promotion enrollment

See [sources.md](sources.md) for Business APIs and Apex Reference documentation links.

---

## Design Best Practices

### Data Model

- Use LoyaltyProgram as the single root; avoid multiple programs for the same business domain unless required.
- Qualifying currency = engagement (tier progression); non-qualifying = redeemable points.
- Tier groups support multiple currencies; map LoyaltyProgramCurrency to LoyaltyTierGroup.

### Transactions

- TransactionJournal records activities; LoyaltyLedger records point movements.
- Use JournalType, JournalSubType, JournalReason for categorization.
- LoyaltyProgramProcess controls how journals are processed.

### Integrations

- Prefer Loyalty Management Business APIs over raw DML.
- Use standard invocable actions in Flows when possible.
- For custom logic, extend via Apex; avoid modifying standard object behavior.

**Integration options:**
- **Unlocked Package (POS):** Simple mappings, point-to-point; Apex REST web services
- **MuleSoft:** Enterprise, multi-system; requires Anypoint Starter for Industries
- **Platform Events:** Decouple stay/transaction events from external systems (e.g., Loyalty_Stay_Event__e)
- **Person Accounts:** Required for some POS integrations

### Performance

- Bulkify all Apex; TransactionJournal and LoyaltyLedger can scale.
- Use batch processing for high-volume accruals/redemptions.
- Avoid SOQL in loops; leverage relationship queries.

---

## Verification and Agent Integration

Before implementing loyalty solutions, run verification against the connected org to validate object/field existence and custom extensions.

**Use the sf-org-agent** (if available) for **fast, org-backed** checks—prompts such as:
- "Use the sf-org-agent to verify that LoyaltyProgramMember and TransactionJournal exist and that Loyalty_Stay__c is configured before we implement the stay accrual flow"
- "Audit whether we can use the Industry field on Account for this loyalty requirement"

**Use the sf-research-agent** for **deep** loyalty solution design, architecture, documentation-led analysis, and extended security/governor reviews; it can delegate org verification to **sf-org-agent** when needed.

---

## Implementation Notes

- **API versions:** Object availability varies (e.g., DigitalPass 66.0, GameDefinition 60.0). Check [reference.md](reference.md).
- **Picklist values:** Do not change API names of default picklist values.
- **Metadata:** Before generating loyalty metadata, use `Salesforce DX` code-analysis tools (`scan_apex_class_for_antipatterns`, `run_code_analyzer`, `describe_code_analyzer_rule`) or `WebFetch` from the [Metadata API Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_intro.htm). Fallback to SF CLI (`sf sobject describe`) when MCP is unavailable.

---

## Location

**This skill is configured at project level** (`.cursor/skills/sf-loyalty-management-skill/`) and is available to all contributors working in this project.

All Loyalty Management API content has been extracted into the `.md` files within this skill:
- API classes, REST endpoints, picklist values → [api-reference.md](api-reference.md)
- Object list with SF doc URLs → [objects-reference.md](objects-reference.md)
- Object relationships, API versions, journal types → [reference.md](reference.md)
- Documentation URLs → [sources.md](sources.md)

Org-specific context is in [org-context.md](org-context.md); run the `org-context-refresh` workflow to update it when the org schema changes.
