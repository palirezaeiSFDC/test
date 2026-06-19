/*******************************************************************************************
 * @Name         MemberStayMapper.cls
 * @Author       Salesforce
 * @Date         05/01/2026
 * @Group        SF-Implementation
 * @Description  Mapper class for Member Stay API.
 *               Maps request wrapper objects to TransactionJournal SObject records.
 *               Handles lookups for JournalType, JournalSubType, and Product.
 *               Member and Property IDs are provided by MemberStayValidator (validated there).
 *******************************************************************************************/
 /* MODIFICATION LOG
 * Version          Developer          Date               Description
 *-------------------------------------------------------------------------------------------
 *  1.0             Praveen      05/01/2026        Initial Creation for LYLT-7402
 *  2.0             sai vinay   11/02/2026         LYLT-367, LYLT-8556
 *  3.0             Sakshi      19/02/2026         LYLT-2868 - Settlement always set (NORMAL when absent)
 *  4.0             Akanksha     23/02/2026        LYLT-9096 - Unique Stay creation - Visit Type & POR field
 *  5.0             Praveen     09/03/2026         LYLT-7125 - Removed population of Origin field on TJ
 *******************************************************************************************/
public with sharing class MemberStayMapper {

    /******************************
     * Cache Maps for Lookups
     ******************************/
    private Map<String, Id> journalTypeCache;
    private Map<String, Id> journalSubTypeCache;
    private Map<String, Id> productCache;
    private Id loyaltyProgramId;

    // IDs from validator (member and property validated there)
    private Id memberId;
    private Id propertyId;

    /******************************
     * Constructor
     ******************************/
    /**
     * @description Constructor for MemberStayMapper
     * @param loyaltyProgramId - Id of the loyalty program (pre-queried to avoid duplicate query)
     */
    public MemberStayMapper(Id loyaltyProgramId) {
        this.journalTypeCache = new Map<String, Id>();
        this.journalSubTypeCache = new Map<String, Id>();
        this.productCache = new Map<String, Id>();
        this.loyaltyProgramId = loyaltyProgramId;
    }

    /******************************
     * Setters for Validated IDs (from MemberStayValidator)
     ******************************/
    /**
     * @description Sets the member ID (validated by MemberStayValidator)
     * @param memberId - Id of the loyalty program member
     */
    public void setMemberId(Id memberId) {
        this.memberId = memberId;
    }

    /**
     * @description Sets the property ID (validated by MemberStayValidator)
     * @param propertyId - Id of the property
     */
    public void setPropertyId(Id propertyId) {
        this.propertyId = propertyId;
    }

    /******************************
     * Main Mapping Method
     ******************************/

    /**
     * @description Maps a list of request wrappers to TransactionJournal records.
     *              NOTE: Call preloadLookups() before this method to bulk load lookup data.
     * @param requests - List of TransactionJournalRequest objects
     * @param stayId - Id of the Loyalty_Stay__c record to link TJs to
     * @param tjStatus - Status to set on all TransactionJournal records
     * @return List<TransactionJournal> - Mapped TransactionJournal records ready for insert
     */
    public List<TransactionJournal> mapToTransactionJournals(
        List<TransactionJournalRequest> requests,
        Id stayId,
        String tjStatus
    ) {
        List<TransactionJournal> journals = new List<TransactionJournal>();
        for (TransactionJournalRequest req : requests) {
            TransactionJournal tj = mapSingleRequest(req);
            tj.Loyalty_Stay__c = stayId;
            tj.Status = tjStatus;
            journals.add(tj);
        }
        return journals;
    }

    /******************************
     * Single Record Mapping
     ******************************/

    /**
     * @description Maps a single request wrapper to a TransactionJournal record
     * @param req TransactionJournalRequest object
     * @return TransactionJournal Mapped record
     */
    private TransactionJournal mapSingleRequest(TransactionJournalRequest req) {
        TransactionJournal tj = new TransactionJournal();
        tj.LoyaltyProgramId = this.loyaltyProgramId;
        
        // Journal Type and SubType
        if (String.isNotBlank(req.journalTypeId)) {
            tj.JournalTypeId = req.journalTypeId;
        } else if (String.isNotBlank(req.journalTypeName)) {
            tj.JournalTypeId = journalTypeCache.get(req.journalTypeName.toLowerCase());
        }
        if (String.isNotBlank(req.journalSubTypeId)) {
            tj.JournalSubTypeId = req.journalSubTypeId;
        } else if (String.isNotBlank(req.journalSubTypeName)) {
            tj.JournalSubTypeId = journalSubTypeCache.get(req.journalSubTypeName.toLowerCase());
        }
        
        // Member and Product
        tj.MemberId = String.isNotBlank(req.memberId) ? req.memberId : this.memberId;
        if (String.isNotBlank(req.productId)) {
            tj.ProductId = req.productId;
        } else if (String.isNotBlank(req.productCode)) {
            tj.ProductId = productCache.get(req.productCode.toLowerCase());
        }
        
        // Basic fields
        tj.Establishment = req.establishment;
        tj.Status = req.status;
        tj.Channel = req.channel;
        tj.CurrencyIsoCode = req.currencyIsoCode;
        tj.ExternalTransactionNumber = req.externalTransactionNumber;
        tj.Transaction_Type__c = req.transactionType;//LYLT-11011
        
        // Date fields
        tj.ActivityDate = req.activityDate;
        if (req.startDate != null) {
            tj.StartDate = DateTime.newInstance(req.startDate, Time.newInstance(0, 0, 0, 0));
        }
        if (req.endDate != null) {
            tj.EndDate = DateTime.newInstance(req.endDate, Time.newInstance(0, 0, 0, 0));
        }
        tj.BookingDate = req.bookingDate;
        
        // Amount fields
        tj.TransactionAmount = req.transactionAmount;
        tj.FX_Rate__c = req.fxRate;
        tj.USD_Value_Converted__c = req.usdValueConverted;
        tj.Quantity = req.quantity;
        
        // Boolean flags
        if (req.redemptionRateFlag != null) {
            tj.Redemption_Rate_Flag__c = req.redemptionRateFlag;
        }
        if (req.earnEligibility != null) {
            tj.Earn_Eligibility__c = req.earnEligibility;
        }
        if (req.isNUA != null) {
            tj.Is_NUA__c = req.isNUA;
        }
        if (req.isParentTransaction != null) {
            tj.IsParentTransaction = req.isParentTransaction;
        }
        
        // Reservation/Folio details
        tj.Reservation_Confirmation_Number__c = req.reservationConfirmationNumber;
        tj.Folio_Number__c = req.folioNumber;
        tj.Benefits__c = req.benefits;
        tj.Rate_Plan_Code__c = req.rateCodePlan;
		tj.Visit_Type__c = req.visitType;//LYLT-9096//Unique Stays
        tj.Program_Of_Record__c = req.programOfRecord;//LYLT-9096//Unique Stays

        // CEC / API spec 2026Q1.5.0: Associate_Id__c, Redemption_Transaction_Id__c
        if (String.isNotBlank(req.associateId)) {
            tj.Associate_Id__c = req.associateId;
        }
        if (String.isNotBlank(req.redemptionTransactionId)) {
            tj.Redemption_Transaction_Id__c = req.redemptionTransactionId;
        }

        // Extended Stay: Settlement (INTERIM/FINAL) from payload mapped to TJ for loyalty process
       // tj.Settlement__c = String.isNotBlank(req.settlement) ? req.settlement : null;
 tj.Settlement__c = String.isNotBlank(req.settlement) ? req.settlement : StayAndEarnApexConstants.SETTLEMENT_NORMAL;
        return tj;
    }


    /******************************
     * Bulk Lookup Loading
     ******************************/

    /**
     * @description Pre-loads lookup values for JournalType, JournalSubType, and Product.
     *              Member and Property IDs come from MemberStayValidator (set via setMemberId/setPropertyId).
     *              Throws error if any lookup value is not found.
     * @param requests - List of request wrappers
     */
    public void preloadLookups(List<TransactionJournalRequest> requests) {
        Set<String> journalTypeNames = new Set<String>();
        Set<String> journalSubTypeNames = new Set<String>();
        Set<String> productCodes = new Set<String>();

        // Collect unique values ONLY when Id is NOT provided
        for (TransactionJournalRequest req : requests) {
            // JournalType: skip lookup if journalTypeId is provided
            if (String.isBlank(req.journalTypeId) && String.isNotBlank(req.journalTypeName)) {
                journalTypeNames.add(req.journalTypeName);
            }

            // JournalSubType: skip lookup if journalSubTypeId is provided
            if (String.isBlank(req.journalSubTypeId) && String.isNotBlank(req.journalSubTypeName)) {
                journalSubTypeNames.add(req.journalSubTypeName);
            }

            // Product: skip lookup if productId is provided
            if (String.isBlank(req.productId) && String.isNotBlank(req.productCode)) {
                productCodes.add(req.productCode);
            }
        }

        // Load lookups and throw error if any not found
        loadJournalTypesAndSubTypes(journalTypeNames, journalSubTypeNames);
        loadProducts(productCodes);
    }

    /******************************
     * Individual Lookup Methods
     ******************************/

    /**
     * @description Loads JournalType and JournalSubType lookup values into cache maps
     * @param typeNames Set of JournalType names to load
     * @param subTypeNames Set of JournalSubType names to load
     */
    private void loadJournalTypesAndSubTypes(Set<String> typeNames, Set<String> subTypeNames) {
        if (typeNames.isEmpty() && subTypeNames.isEmpty()) {
            return;
        }

        List<SObject> journalSubTypes = MemberStayDataService.findJournalSubTypes(subTypeNames);
        MemberStayMapperHelper.LookupMaps maps = MemberStayMapperHelper.buildLookupMaps(journalSubTypes);

        // Populate caches
        journalSubTypeCache.putAll(maps.subTypeMap);
        journalTypeCache.putAll(maps.typeMap);

        // Validate lookups
        MemberStayMapperHelper.validateSubTypes(subTypeNames, maps.subTypeMap);
        MemberStayMapperHelper.validateTypes(typeNames, maps.typeMap);
    }

    /**
     * @description Loads Product lookup values into cache map
     * @param productCodes Set of ProductCode values to load
     */
    private void loadProducts(Set<String> productCodes) {
        if (productCodes.isEmpty()) {
            return;
        }

        Map<String, Id> productMap = MemberStayDataService.findProductsByCodes(productCodes);
        productCache.putAll(productMap);

        // Validate products
        MemberStayMapperHelper.validateProducts(productCodes, productMap);
    }

}