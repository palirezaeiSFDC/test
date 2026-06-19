| API Name | Data Type | Description |
|---|---|---|
| ActivityDate | Date/Time | Date of Loyalty Event |
| Associate_Id__c | Text(20) | Identifier of the individual or system actor associated with the transaction. This field stores the originating agent or associate ID, depending on the use case (e.g., CEC agent for CEC scenarios or associate ID for partnership scenarios). |
| Base_Points__c | Number(18, 0) | This field stores the calculated base points value for this Transaction Journal |
| Benefits__c | Text(80) | An identifier associated with each benefit linked to the stay. This value is used to capture, reference, and track every benefit recorded for the stay, including those through which the member may earn points. |
| BookedFareClass | Picklist | — |
| BookedRoomType | Picklist | — |
| BookingDate | Date | — |
| Brand | Text(30) | — |
| Channel | Picklist | Represents the unique Client ID for the Source System. |
| Charge_Code_Type__c | Text(80) | Indicates whether the product tied to the transaction is Room Revenue or Incidental |
| CouponId | Lookup(Coupon) | — |
| CreatedById | Lookup(User) | — |
| CreatedDate | Date/Time | — |
| CurrencyIsoCode | Picklist | — |
| Destination | Text(30) | — |
| Distance | Number(16, 2) | — |
| Earn_Eligibility__c | Checkbox | Identifier to signify that member is eligible for earn |
| Eligible_Amount__c | Number(16, 2) | — |
| Elite_Bonus_Points__c | Number(18, 0) | This field stores the calculated elite bonus points value for this Transaction Journal |
| EndDate | Date/Time | — |
| EngagementChannelTypeId | Lookup(Engagement Channel Type) | — |
| ErrorDescription | Text(255) | The description of the error. |
| EscrowPointsCreditDate | Date | — |
| Establishment | Text(40) | The unique identifier for the location where the member stayed or purchased goods or services. |
| ExternalTransactionNumber | Text(40) | The transaction number from the external systems. MI has it. |
| Extra_Points__c | Number(18, 0) | This field stores the extra points value for this Transaction Journal. |
| FlightNumber | Text(10) | — |
| Folio_Number__c | Text(255) | The folio represents the document or account containing charges incurred by a member during a stay in a guest room at a Participating Property. Folio Number is the identifier of a folio |
| Free_Night_Indicator__c | Checkbox | This field tracks the Free Nights given to the member in a  Redemption Transaction |
| FX_Rate__c | Number(16, 2) | Foreign exchange rate based on currency of transaction. |
| Id | Lookup() | — |
| Industry | Picklist | — |
| IneligibleAmount__c | Currency(16, 2) | Ineligible amount sent by freedom pay needs to be tracked |
| InvoiceDate | Date | The date the invoice was generated. |
| Is_EQN_Qualified__c | Checkbox | This field stores an indicator of whether this Transaction Journal is eligible for Elite Qualifying Night(EQN) calculation. |
| Is_NUA__c | Checkbox | Indicates whether a Member has redeemed NUA as part of this stay |
| IsDeleted | Checkbox | — |
| IsParentTransaction | Checkbox | Indicates whether the transaction journal represents the primary activity within a group of activities. |
| JournalDate | Date/Time | The date when the transaction journal is processed. |
| JournalReason | Picklist | Additional information on the transaction. |
| JournalSubTypeId | Lookup(Journal Subtype) | The subtype of journal transaction. used to run rules and processes. Used in combination with Journal Type. |
| JournalTypeId | Lookup(Journal Type) | The type of journal transaction.Used to run rules and processes in combination with Journal Subtype. |
| LastModifiedById | Lookup(User) | — |
| LastModifiedDate | Date/Time | — |
| LastReferencedDate | Date/Time | — |
| LastViewedDate | Date/Time | — |
| Level_Upgrade_Code__c | Text(80) | levelUpgradeCode is a two-digit code received from a partner on a Transaction Journal. This code specifies the tier that should be assigned to a member. For example, ND represents NeedSilver. |
| Loyalty_Redemption_Booking__c | Lookup(Loyalty Redemption Booking) | A reference to the Loyalty Redemption Booking record. |
| Loyalty_Stay__c | Lookup(Loyalty Stay) | Indicates the related Stay record for this Transaction Journal. |
| LoyaltyProgramId | Lookup(Loyalty Program) | The loyalty program associated with the transaction. in this case Marriott Bonvoy. |
| MemberId | Lookup(Loyalty Program Member) | The member associated with the transaction. |
| Name | Auto Number | — |
| Notes__c | Text(255) | To collect additional details if necessary. |
| OrderId | Lookup(Order) | — |
| OrderItemId | Lookup(Order Product) | — |
| Origin | Text(30) | Stay source identifier used to capture the source of the stay on the TransactionJournal. Salesforce uses this value to derive and populate the Stay Source Description and Stay Source Category fields on the Loyalty_Stay__c record. |
| Partner_Account_Number__c | Text(255) | Manage Partner Account Number for Earn, Redeem, Partner, Promotions use cases. |
| PartnerId | Lookup(Loyalty Program Partner) | Partner related to the transaction. |
| PaymentMethod | Picklist | — |
| ProductCategoryId | Lookup(Category) | — |
| ProductId | Lookup(Product) | Codes such as Bonus Code, Award Codes, Charge Codes associated with the TJ. |
| Program_Of_Record__c | Picklist | Indicates whether the transaction is associated with the Delonix program. The value is set to ‘Delonix’ for Delonix transactions; otherwise, the field is null. |
| PromotionId | Lookup(Promotion) | — |
| Quantity | Number(16, 2) | This field will be used to record the quantity. |
| Quantity_Unit__c | Picklist | This field will be used to identify the type of unit (Points, Miles, FNA, NUA, Cash and Points). |
| QuantityUnitOfMeasureId | Lookup(Unit of Measure) | — |
| Rate_Plan_Code__c | Text(255) | This code identifies the specific room rate or promotional offering applied to a reservation. Loyalty benefits, earning potential, and status accumulation are often dependent on whether a reservation is booked under a Qualifying Rate or a Non-Qualifying Rate |
| RecordVisibilityId | Lookup(Record Visibility) | — |
| RedeemedPointsExpirationInformation | Long Text Area(131072) | — |
| Redemption_Rate_Flag__c | Checkbox | Indicates if the plan is a redemption rate plan |
| Redemption_Transaction_Id__c | Text(18)  (Unique Case Insensitive) | A system-generated identifier created by CLM to uniquely track a redemption transaction across its lifecycle. |
| ReferredMemberId | Lookup(Loyalty Program Member) | Member ID of the person who performed the referral |
| ReferredPartyId | Lookup(Contact,Account,Lead) | — |
| RelatedCorporateMembershipId | Lookup(Loyalty Program Member) | — |
| RelatedJournalId | Lookup(Transaction Journal) | — |
| Reservation_Confirmation_Number__c | Text(80) | An identifier associated with a booking. For systems utilizing MARSHA, this refers to the MARSHA confirmation number |
| Settlement__c | Picklist | Identifies the type of settlement for the record. INTERIM indicates the folio was settled to $0.00 while the member is in-house, FINAL indicates checkout, NORMAL is used for standard transactions where no specific settlement action has occurred (default for blank values). |
| StartDate | Date/Time | — |
| Status | Picklist | The status of the transaction. |
| SystemModstamp | Date/Time | — |
| TotalPromotionDiscount | Currency(16, 2) | — |
| Transaction_Type__c | Text(80) | Identifies whether a transaction is associated with an earning or redemption activity. This field is critical for downstream systems (such as LFS) for reporting purposes. Example values include RetailActivityEarning (for Partnership scenarios) and Group or Individual (for Stay scenarios) |
| TransactionAmount | Currency(16, 2) | For reservations, the total fees or prepaid balance. For goods and services, the total purchase price. |
| TransactionLocation | Text(50) | Identifies the retail outlet associated with the transaction or activity. Stores both the unique outlet ID (e.g., 116) and its descriptive name (e.g., Donuts Unlimited, Daffodil St.). i.e. "retailOutletId": "116", "retailOutletName": "Donuts Unlimited, Daffodil St." |
| TransactionSourceLocationId | Lookup(Retail Store) | — |
| TraveledFareClass | Picklist | — |
| UniqueIdentifier | Text(80) | Unique Identifier of the record from external system. |
| UsageType | Picklist | — |
| USD_Value_Converted__c | Currency(16, 2) | Currency converted value in USD. |
| UserRecordAccessId | Lookup(User Record Access) | — |
| Visit_Type__c | Picklist | Identifies the type of customer visit associated with the transaction. This picklist indicates how the stay was classified for processing and eligibility. |
| Voucher__c | Lookup(Voucher) | This field tracks the Voucher issued to the member in a  Redemption Transaction |
| VoucherCode | Text(255) | Voucher related to the transaction. |
