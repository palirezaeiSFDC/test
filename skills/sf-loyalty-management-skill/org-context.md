# Org Context — Loyalty Management Verified Metadata

Verified metadata from the **[TARGET_ORG]** sandbox (API 66.0). Use this when designing or implementing loyalty solutions against the connected org.

> **Note:** This file reflects a metadata snapshot from a specific org. Before relying on it, verify the connected org alias at session start using `sf-org-agent` → `list_all_orgs`. If the connected org differs from the one that was verified, run the **`org-context-refresh`** workflow to update this file with current org state.

**Last Verified:** 2026-03-20 (against Marriott-TeamDev sandbox)

**Source:** Full list from [objects-reference.md](objects-reference.md). Use the **sf-org-agent** to re-verify with `sf sobject describe -s <Object> -o <TARGET_ORG>`.

---

## Standard Objects (from objects-reference.md)

| API Name | Description | Org Verified |
|----------|-------------|--------------|
| Account | Organization or person involved with your business | Yes |
| AnalyticsDatasetDefinition | Analytics dataset definition for loyalty reporting (API 65.0+) | Yes |
| Benefit | Benefits associated with the loyalty program; mapped to members by tier | Yes |
| BenefitParameterValue | Runtime value of a parameter for benefit action flow | Yes |
| BenefitType | Type of benefits (e.g., Support Benefits) for members | Yes |
| Contact | Person associated with an account | Yes |
| DigitalPass | Digital pass issued to a loyalty program member (API 66.0+) | Yes |
| DigitalPassTemplate | Template for creating digital passes (API 66.0+) | Yes |
| DigitalPassTmplParameter | Parameter on a digital pass template (API 66.0+) | Yes |
| GameDefinition | Game definition for loyalty gamification (API 60.0+) | Yes |
| GameParticipant | Member participation in a game (API 60.0+) | Yes |
| GameParticipantReward | Reward earned by a game participant (API 60.0+) | Yes |
| GameReward | Reward available in a game definition (API 60.0+) | Yes |
| JournalSubType | Subcategory of transaction journal; advocate/referred party activity | Yes |
| JournalType | Category of transactions (accrual, redemption) | Yes |
| LoyaltyAggrPointExprLedger | Fixed-type non-qualifying points set to expire (API 54.0+) | Yes |
| LoyaltyLedger | Points credited or debited for a member across transactions | Yes |
| LoyaltyLedgerTraceability | Traceability linking ledger entries to source transactions (API 62.0+) | Yes |
| LoyaltyMemberCurrency | Point balance for a member and a particular currency | Yes |
| LoyaltyMembershipLifecycle | Member's lifecycle in the loyalty program | Yes |
| LoyaltyMemberTier | Current tier of the member across tier groups | Yes |
| LoyaltyPartnerProduct | Products and product categories offered by loyalty partners | Yes |
| LoyaltyPgmCurrencySubtype | Subtype of fixed-model non-qualifying loyalty program currency | Yes |
| LoyaltyPgmEngmtAttribute | Engagement attribute for a loyalty program | Yes |
| LoyaltyPgmEngmtAttrProm | Junction: Loyalty Program Engagement Attribute and Promotion | Yes |
| LoyaltyPgmGroupMbrRlnsp | Junction: Corporate/Individual member in a group and Group member | Yes |
| LoyaltyPgmMbrAttributeVal | Value reached by a member for an engagement attribute | Yes |
| LoyaltyPgmMbrLinkedPtnr | Association between a member and partner membership (API 66.0+) | Yes |
| LoyaltyPgmMbrPromEligView | Virtual object: member eligibility and enrollment in promotions | Yes (requires LPM filter) |
| LoyaltyPgmPartnerCurrency | Junction: loyalty program partner and loyalty program currency | Yes |
| LoyaltyPgmPartnerPromotion | Junction: Promotion and Loyalty Program Partner | Yes |
| LoyaltyPgmPtnrLdgrSummary | Aggregated ledger for prepaid partner's points pack | Yes |
| LoyaltyPgmPtnrPrepaidPack | Prepaid set of points purchased by a loyalty program partner | Yes |
| LoyaltyProgram | Root loyalty program; members, tiers, currencies, partners, promotions | Yes |
| LoyaltyProgramBadge | Badge that's part of a loyalty program | Yes |
| LoyaltyProgramCurrency | Qualifying and non-qualifying currencies for the program | Yes |
| LoyaltyProgramCurrencyTier | Junction: non-qualifying currency and loyalty tier | Yes |
| LoyaltyProgramMbrPromotion | Junction: advocate and promotion; tracks promotion signup | Yes |
| LoyaltyProgramMember | Member in a loyalty program (individual or corporate) | Yes |
| LoyaltyProgramMemberBadge | Badge assigned to a loyalty program member | Yes |
| LoyaltyProgramMemberCase | Junction: loyalty program member and case | Yes |
| LoyaltyProgramMemberMerge | Merged loyalty program memberships | Yes |
| LoyaltyProgramPartner | Partners (accrual, redemption, or both) for a loyalty program | Yes |
| LoyaltyProgramPartnerLedger | Ledger for prepaid partner's pack or postpaid partner's balance | Yes |
| LoyaltyProgramProcess | Processes that determine how transaction journals are processed | Yes |
| LoyaltyProgramWidget | OmniStudio widget templates for loyalty UI (API 57.0+) | Yes |
| LoyaltyTier | Tiers of a loyalty program | Yes |
| LoyaltyTierBenefit | Junction: loyalty tier and benefit | Yes |
| LoyaltyTierEligibilitySrc | Source/criteria for tier eligibility (API 64.0+) | Yes |
| LoyaltyTierGroup | Tier groups; categorizes members by loyalty points | Yes |
| LoyaltyTierMshpFeeOption | Fee members must pay to enroll in a tier | Yes |
| LoyaltyTierPromotion | Junction: loyalty tier and promotion | Yes |
| MemberBenefit | Benefit assigned to a member with triggered benefit action | Yes |
| Product2 | Product that your company sells | Yes |
| ProductCatalog | Catalog holding a collection of products | Yes |
| ProductCategory | Category that products are organized in | Yes |
| ProductCategoryProduct | Relation between product and product category | Yes |
| Promotion | Referral promotion | Yes |
| PromotionActionableList | Actionable list for targeted promotion engagement (API 62.0+) | No (not supported in org) |
| PromotionChannel | Promotion's eligible channel | Yes |
| PromotionExecEvalGrpItem | Item in promotion execution evaluation group (API 65.0+) | No (not supported in org) |
| PromotionExecutionEvalGrp | Evaluation group for promotion execution rules (API 65.0+) | No (not supported in org) |
| PromotionLimit | Limit of a promotion | Yes |
| PromotionLimitUsage | Usage of a promotion limit | Yes |
| PromotionLoyaltyPtnrProdt | Junction: promotion and loyalty partner product | Yes |
| PromotionMarketSegment | Junction: promotion and Data Cloud segment | Yes |
| PromotionPartyUsage | Usage of a promotion by a party | Yes |
| PromotionProduct | Junction: promotion and eligible product | Yes |
| PromotionProductCategory | Junction: promotion and eligible product category | Yes |
| PromotionStage | Stage of a promotion | Yes |
| PromotionStageEmailTemplate | Junction: promotion stage and email template | Yes |
| TransactionJournal | Loyalty transactions; activities, member behavior, adjustments | Yes |
| Voucher | Voucher issued to a loyalty program member | Yes |
| VoucherDefinition | Voucher definition associated with a loyalty program | Yes |

---

## Custom Objects (from objects-reference.md)

| API Name | Description | Org Verified |
|----------|-------------|--------------|
| Exception_Log__c | Stores exceptions captured in Flows, Apex | Yes |
| BonvoyID_Number_Pool__c | Pool of available BonvoyIDs for Loyalty Program Member | Yes |
| data_cloud__Data_Cloud_Failure__c | Failures within Data Cloud for notifications | Yes |
| Global_Benefit_Mapping__c | Benefit rules and mapping to Regions and Brands | Yes |
| Property_Product_Mapping__c | Junction between Property and Product objects | Yes |
| Benefit_Choice__c | Mapping of benefit with its choices (modeled as Benefit) | Yes |
| ~~Member_Partner_Link__c~~ | **DEPRECATED** — Replaced by standard `LoyaltyPgmMbrLinkedPtnr` (see Standard Objects). Do not use for new development. | Yes (deprecated) |
| Bonvoy_Hashkey_Pool__c | Pool of hashkeys pointing to unassigned IDs in main pool | Yes |
| Brand__c | Master list of Brands for Marriott Properties | Yes |
| Loyalty_Stay__c | Stay details for members | Yes |
| Rate_Plan_Exception__c | Rate Plan Exception codes for exception scenarios | Yes |
| Referral_Type__c | Master list of Referral Types supported | Yes |
| Stay_Eligibility_Rule__c | Stay eligibility scenarios | Yes |

---

## Org-Specific Extensions

| API Name | Purpose | Org Verified |
|----------|---------|--------------|
| Loyalty_Stay_Event__e | Platform Event for stay event publishing (not queryable via SOQL) | Yes |
| Loyalty_Tier_Tenure_Configuration__mdt | Tier tenure configuration (Custom Metadata) | Yes |

---

## Key Custom Fields

### LoyaltyProgram

- Program_Code__c
- Global_Partner_Earn_Limit_Value__c
- Global_Partner_Earn_Limit_Frequency__c

### LoyaltyProgramMember

- BonvoyID__c
- FrequentFlierNumber__c
- PropertyCode__c
- BrandCode__c
- Partner__c
- Lifetime_Nights__c
- enrollmentLevelTypeCode__c

---

## Custom Apex Classes

| Class | Purpose |
|-------|---------|
| LoyaltyDynamicQuery | Dynamic SOQL for loyalty data |
| LoyaltyIntegrationUtils | Integration helpers |
| LoyaltyJournalActions | TransactionJournal operations |
| LoyaltyPartnerProductTriggerHandler | LoyaltyPartnerProduct trigger logic |
| LoyaltyProgramMemberTriggerHandler | LoyaltyProgramMember trigger logic |
| LoyaltyStayEventBuilder | Builds stay events |
| LoyaltyStayEventPublisher | Publishes stay events |
| LoyaltyStayTriggerHandler | Loyalty_Stay__c trigger logic |
| LoyaltyStayPublishFailureCallback | Failure handling for stay publish |

---

## Features Enabled

| Feature | Status |
|---------|--------|
| Core Program & Members | Enabled |
| Points & Ledger | Enabled |
| Tiers | Enabled |
| Transactions | Enabled |
| Promotions | Enabled |
| Vouchers | Enabled |
| Gamification (GameDefinition) | Enabled |
| Digital Passes | Enabled |
| Custom Stay Integration | Configured |
| Tier Tenure | Configured |

---

## API Version

**66.0** — Gamification and Digital Passes available.
