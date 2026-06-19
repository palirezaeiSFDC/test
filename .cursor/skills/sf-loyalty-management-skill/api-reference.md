# Salesforce Loyalty Management — API Reference

Extracted from the Loyalty Management Developer Guide (Version 66.0, Spring '26). For complete field-level details not covered below, use the online [Apex Reference](https://developer.salesforce.com/docs/atlas.en-us.loyalty.meta/loyalty/loyalty_apex_reference.htm) and [Business APIs](https://developer.salesforce.com/docs/atlas.en-us.loyalty.meta/loyalty/loyalty_management_apis.htm).

---

## ConnectApi Namespace

### LoyaltyConnect Methods

Connect API methods for loyalty program operations.

### LoyaltyManagementConnect Methods

Primary Connect API class for loyalty management operations:

- Member enrollment (individual and corporate)
- Points credit/debit
- Tier assessment and change
- Voucher issuance
- Promotion enrollment and evaluation
- Membership merge/unmerge

### LoyaltyVoucherConnect Methods

Connect API methods for voucher-specific operations.

### Input Classes (ConnectApi)

| Class | Purpose |
|-------|---------|
| `ConnectApi.LoyaltyMemberEnrollmentInput` | Enroll a new member in a loyalty program |
| `ConnectApi.LoyaltyEngineInput` | Run the loyalty engine to process journals |
| `ConnectApi.LoyaltyMemberProfileInput` | Update member profile information |
| `ConnectApi.LoyaltyTransactionJournalInput` | Create a transaction journal entry |

### Output Classes (ConnectApi)

| Class | Purpose |
|-------|---------|
| `ConnectApi.LoyaltyMemberEnrollmentOutput` | Enrollment result with member ID and status |
| `ConnectApi.LoyaltyEngineOutput` | Engine processing result |
| `ConnectApi.LoyaltyMemberProfileOutput` | Profile update result |
| `ConnectApi.LoyaltyTransactionJournalOutput` | Journal creation result |

---

## LoyaltyManagement Namespace

Apex classes for programmatic loyalty operations. Prefer these over raw DML.

### Tier Operations

| Class | Purpose |
|-------|---------|
| `ChangeTierInput` | Input for changing a member's tier |
| `ChangeTierInputBuilder` | Builder pattern for ChangeTierInput |
| `ChangeTierOutput` | Result of tier change operation |
| `MemberTierInput` | Input for getting member tier information |
| `MemberTierInputBuilder` | Builder pattern for MemberTierInput |
| `MemberTierOutput` | Member tier assessment result |

### Points Operations

| Class | Purpose |
|-------|---------|
| `PointsInput` | Input for credit/debit points operations |
| `PointsInputBuilder` | Builder pattern for PointsInput |
| `CreditPointsOutput` | Result of credit points operation |
| `DebitPointsOutput` | Result of debit points operation |
| `MemberPointBalanceInput` | Input for getting member point balance |
| `MemberPointBalanceInputBuilder` | Builder pattern for MemberPointBalanceInput |
| `MemberPointBalanceOutput` | Member point balance result |
| `TransferMemberPointsToGroupsInput` | Input for transferring points to groups |
| `TransferMemberPointsToGroupsInputBuilder` | Builder for transfer input |

### Voucher Operations

| Class | Purpose |
|-------|---------|
| `IssueVoucherInput` | Input for issuing a voucher to a member |
| `IssueVoucherInputBuilder` | Builder pattern for IssueVoucherInput |
| `IssueVoucherOutput` | Result of voucher issuance |

### Promotion Operations

| Class | Purpose |
|-------|---------|
| `LoyaltyPromotionInput` | Input for loyalty promotion processing |
| `LoyaltyPromotionInputBuilder` | Builder pattern for LoyaltyPromotionInput |
| `LoyaltyPromotionOutput` | Promotion processing result |
| `CdpBasedLoyaltyPromotionInput` | Input for Data Cloud-based promotion processing |
| `CdpBasedLoyaltyPromotionInputBuilder` | Builder for CDP-based promotion input |
| `CdpBasedLoyaltyPromotionOutput` | CDP-based promotion result |
| `UpdateCumulativeUsageCompletedInput` | Input for updating cumulative promotion usage |
| `UpdateCumulativeUsageCompletedOutput` | Cumulative usage update result |

### Segment Operations

| Class | Purpose |
|-------|---------|
| `GetMemberActiveSegmentsInput` | Input for retrieving member's active Data Cloud segments |
| `GetMemberActiveSegmentsInputBuilder` | Builder for segment input |
| `GetMemberActiveSegmentsOutput` | Active segments result |

### Common Classes

| Class | Purpose |
|-------|---------|
| `LoyaltyActionError` | Error information from loyalty operations |
| `LoyaltyActionResult` | Base result class for loyalty actions |
| `LoyaltyResources` | Resource helper class for loyalty operations |

---

## REST Business APIs

Base URL: `/services/data/vXX.0/loyalty/programs/{programId}/`

### Key REST Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/members` | POST | Enroll a new member |
| `/members/{memberId}` | GET | Get member details |
| `/members/{memberId}` | PATCH | Update member profile |
| `/members/{memberId}/points/credit` | POST | Credit points to a member |
| `/members/{memberId}/points/debit` | POST | Debit points from a member |
| `/members/{memberId}/points/balance` | GET | Get member point balance |
| `/members/{memberId}/tiers` | GET | Get member tier info |
| `/members/{memberId}/tiers/change` | POST | Change member tier |
| `/members/{memberId}/vouchers` | POST | Issue voucher to member |
| `/members/{memberId}/promotions` | GET | Get member promotions |
| `/members/{memberId}/promotions/enroll` | POST | Enroll member in promotion |
| `/members/{memberId}/benefits` | GET | Get member benefits |
| `/members/{memberId}/merge` | POST | Merge memberships |
| `/members/{memberId}/unmerge` | POST | Unmerge memberships |
| `/transactionJournals` | POST | Create transaction journal |
| `/transactionJournals/{journalId}/process` | POST | Process transaction journal |

---

## Standard Invocable Actions

Use in Flows for declarative loyalty operations:

| Action | Purpose |
|--------|---------|
| **Adjust Points** | Adjust member point balance |
| **Assign Member Tier Benefits** | Assign tier-based benefits to a member |
| **Accrual Cancellation** | Cancel an accrual transaction |
| **Credit Points** | Credit points to a member's currency balance |
| **Change Tier** | Change a member's tier |
| **Change All Tiers or None** | Atomically change tiers across all tier groups |
| **Debit Points** | Debit points from a member's currency balance |
| **Generate Referral Code** | Generate a referral code for a promotion |
| **Get Member's Active Segments** | Get Data Cloud segments for a member |
| **Get Points Balance** | Get member's current point balance |
| **Get Loyalty Promotions Based on Member's Data Cloud** | Get eligible promotions via Data Cloud |
| **Get Promotions Based on Transaction Journal** | Get promotions triggered by a journal |
| **Get Tier** | Get member's current tier |
| **Issue Voucher Action** | Issue a voucher to a member |
| **Map Traceable Points for Redemption Transactions** | Map traceable points for redemption |
| **Merge Memberships Action** | Merge two member accounts |
| **Process Member Benefit** | Execute a benefit action for a member |
| **Redemption Cancellation** | Cancel a redemption transaction |
| **Run Program Process for Transaction Journal** | Run loyalty process for a journal entry |
| **Transfer Member Points to Groups** | Transfer points to group members |
| **Transfer Points** | Transfer points between currencies |
| **Unmerge Memberships Action** | Unmerge previously merged memberships |
| **Update Member Progress for Cumulative Promotion** | Update cumulative promotion progress |

---

## Custom Invocable Actions

| Action | Purpose |
|--------|---------|
| **Issue Digital Pass** | Issue a digital pass (mobile wallet) to a member |
| **Refresh Digital Pass** | Refresh an existing digital pass with updated data |
| **Run Program Process** | Run a loyalty program process programmatically |

---

## Metadata API Types

| Type | Purpose |
|------|---------|
| `AnalyticsDatasetDefinition` | Analytics dataset configuration |
| `BenefitAction` | Benefit action flow configuration |
| `Flow for Loyalty Management` | Loyalty-specific flow metadata |
| `LoyaltyProgramSetup` | Complete loyalty program setup metadata (program, currencies, tiers, processes) |
| `IndustriesGamificationSettings` | Gamification feature settings |
| `IndustriesLoyaltySettings` | Loyalty Management feature settings |
| `IndustriesUnifiedPromotionsSettings` | Unified promotions settings |

---

## StandardValueSet Names (Picklist Fields)

Standard picklist fields used across loyalty objects. For the complete list of standard value set names and their valid values, see the online [Apex Reference — StandardValueSet](https://developer.salesforce.com/docs/atlas.en-us.loyalty.meta/loyalty/loyalty_apex_reference.htm).

**Key picklist fields:**

- `TransactionJournal.Status` -- Processing status of a journal entry
- `TransactionJournal.JournalTypeId` -- Type of journal (Accrual, Redemption, etc.)
- `LoyaltyProgramMember.MemberStatus` -- Active, Inactive, etc.
- `LoyaltyProgramMember.MemberType` -- Individual, Corporate, Group
- `Promotion.Status` -- Draft, Active, Expired, etc.
- `Voucher.Status` -- Issued, Redeemed, Expired, etc.

---

## Usage Notes

- **Builder pattern:** Most input classes have corresponding `*Builder` classes. Use the builder for readable, fluent construction of input parameters
- **Error handling:** Check `LoyaltyActionResult.isSuccess()` and iterate `LoyaltyActionError` for failures
- **Governor limits:** Business API calls count toward SOQL/DML limits. Bulkify when processing multiple members/journals
- **API versioning:** Some classes require specific API versions (check [reference.md](reference.md) for object API version requirements)
- **Full reference:** For complete field definitions and method signatures not covered in this file, use the online [Apex Reference](https://developer.salesforce.com/docs/atlas.en-us.loyalty.meta/loyalty/loyalty_apex_reference.htm)
