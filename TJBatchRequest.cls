/*******************************************************************************************
 * @Name         TJBatchRequest.cls
 * @Author       Salesforce
 * @Date         04/30/2026
 * @Group        SF-Implementation
 * @Description  Request wrapper for the generic Transaction Journal batch API.
 *               Supports any JournalSubType (Events, eBonus, etc.).
 *               All TJs in a single request must share the same JournalSubType.
 *******************************************************************************************/
/* MODIFICATION LOG
 * Version          Developer          Date               Description
 *-------------------------------------------------------------------------------------------
 *  1.0             Pegah.Alirezaei    04/30/2026         Initial Creation - LYLT-363
 *******************************************************************************************/
public class TJBatchRequest {

    /** Outer wrapper received from TIP */
    public List<TJInput> transactionJournals;

    /** Single TJ entry in the batch request */
    public class TJInput {

        /******************************
         * Required – validated before TJ creation
         ******************************/
        public String   MemberId;               // Member account number (required)
        public String   JournalType;            // e.g. Accrual
        public String   JournalSubType;         // e.g. Events, eBonus (drives processor selection)
        public DateTime ActivityDate;           // Required – date of the activity (required)
        public String   CurrencyIsoCode;        // ISO currency code e.g. USD (required)

        /******************************
         * Split indicator
         * true  → earn is being split 50/50 between 2 members; base cap = 30k per member,
         *          EQN is halved per member. TIP sends 2 TJs with the same ExternalTransactionId.
         * false → single member earns the full event; base cap = 60k, full EQN awarded.
         ******************************/
        public Boolean  isSplit;

        /******************************
         * Transaction Identification
         ******************************/
        public String  ExternalTransactionId;  // Quote number / external reference

        /******************************
         * Property
         ******************************/
        public String  Establishment;          // MARSHA property code

        /******************************
         * Dates
         ******************************/
        public Date    StartDate;
        public Date    EndDate;
        public Date    BookingDate;            // Contract signed date

        /******************************
         * Revenue / Earn Amounts
         ******************************/
        public Decimal TransactionAmount;      // Total qualifying revenue (TIP pre-sums)
        public Decimal Quantity;               // Purchase bonus points
        public String  Quantity_Unit__c;       // Fixed: Points

        /******************************
         * Payment / Partner
         ******************************/
        public String  PaymentMethod;
        public String  PartnerName;
        public String  Partner_Account_Number__c;

        /******************************
         * Operational
         ******************************/
        public String  Associate_Id__c;        // Operator EID
        public String  Notes__c;               // Free-form comments
        public String  status;                 // Always Pending on submission

        /******************************
         * Subtype-specific extended payload
         * Serialized JSON – each processor owns its own deserialization
         ******************************/
        public Additional_Details__c Additional_Details__c;
    }

    /**
     * Extended attributes for Events subtype.
     * Add a parallel class (e.g. EBonusDetails) when new subtypes are introduced.
     */
    public class Additional_Details__c {
        public String  organizationType;
        public String  otherOrganizationType;
        public String  eventType;
        public String  otherEventType;
        public String  eventName;

        // ── Promotion ──────────────────────────────────────────────────────────
        public String  promotionCode;
        // DBPT | TRPT – business label for the promotion (informational)

        public Integer pointsMultiplier;
        // Numeric multiplier applied to capped base points before elite bonus.
        // 1 = no promotion (default when absent), 2 = DBPT, 3 = TRPT.
        // CLM uses this value directly; avoids string parsing of promotionCode.

        public Decimal averageDailyRate;
        public Decimal meetingSpace;
        public Decimal catering;
        public Decimal additional;
        public Decimal qualifying;
    }
}
