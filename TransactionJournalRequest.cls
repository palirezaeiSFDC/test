/*******************************************************************************************
 * @Name         TransactionJournalRequest.cls
 * @Author       Salesforce
 * @Date         05/01/2026
 * @Group        SF-Implementation
 * @Description  Wrapper class for Post Member Stay API request payload.
 *               Represents TransactionJournal records for stay transactions.
 *******************************************************************************************/
 /* MODIFICATION LOG
 * Version          Developer          Date               Description
 *-------------------------------------------------------------------------------------------
 *  1.0             Praveen      05/01/2026        Initial Creation for LYLT-7402
 *  2.0             Sakshi      18/02/2026        LYLT-2868 - Extended Stay settlement field
 *  3.0             Akanksha     23/03/2026        LYLT-9096 - Unique Stay Visit Type & POR field
 *******************************************************************************************/

//Suppressing TooManyFields warning as this is a Wrapper class.
@SuppressWarnings('PMD.ExcessivePublicCount,PMD.TooManyFields')
public class TransactionJournalRequest {

    /******************************
     * Journal Type Fields (use Name OR Id)
     ******************************/
    public String journalTypeName;
    public String journalTypeId;
    public String journalSubTypeName;
    public String journalSubTypeId;

    /******************************
     * Member Identification (use membershipNumber OR MemberId)
     ******************************/
    public String membershipNumber;
    public String memberId;

    /******************************
     * Product Identification (use ProductCode OR ProductId)
     ******************************/
    public String productCode;
    public String productId;

    /******************************
     * Property/Establishment
     ******************************/
    public String establishment;  // Property Code

    /******************************
     * Transaction Details
     ******************************/
    public String transactionType;
    public String channel;
    public String origin;
    public String status;
    public String externalTransactionNumber;
    public String currencyIsoCode;

    /******************************
     * Date/Time Fields
     ******************************/
    public Date bookingDate;
    public DateTime activityDate;
    public Date startDate;
    public Date endDate;
    public Date pmsSetupDate;

    /******************************
     * Amount Fields
     ******************************/
    public Decimal transactionAmount;
    public Decimal fxRate;
    public Decimal usdValueConverted;
    public Decimal quantity;

    /******************************
     * Boolean Flags
     ******************************/
    public Boolean redemptionRateFlag;
    public Boolean earnEligibility;
    public Boolean isNUA;
    public Boolean isParentTransaction;

    /******************************
     * Reservation/Folio Details
     ******************************/
    public String reservationConfirmationNumber;
    public String folioNumber;
    public String benefits;
    public String rateCodePlan;
    public string groupIndustry;


    /******************************
     * Unique Stay Visit Type & POR field
     ******************************/
    public string visitType; //LYLT-9096//Unique Stays
    public string programOfRecord;//LYLT-9096//Unique Stays

    /******************************
     * Extended Stay Settlement Indicator (ACRS Connected PMS)
     * Values: INTERIM, FINAL. Only present in payload for Extended Stays; absent for other stays.
     * Mapped to TransactionJournal.Settlement__c and passed to loyalty process.
     ******************************/
    public String settlement;

    /******************************
     * CEC Audit Persistence (LYLT-6928 AC5)
     * reasonCode -> Reason_Code__c, stayComment -> Comment__c on Loyalty_Stay__c
     ******************************/
    public String reasonCode;
    public String stayComment;

    /******************************
     * CEC / API Spec Fields (2026Q1.5.0)
     * associateId -> TransactionJournal.Associate_Id__c
     * redemptionTransactionId -> TransactionJournal.Redemption_Transaction_Id__c
     ******************************/
    public String associateId;
    public String redemptionTransactionId;

    /******************************
     * Stay-level field: Payment_Type_Identifier__c on Loyalty_Stay__c
     ******************************/
    public String paymentTypeIdentifier;
}