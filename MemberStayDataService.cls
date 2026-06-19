/*******************************************************************************************
 * @Name         MemberStayDataService.cls
 * @Author       Salesforce
 * @Date         01/29/2026
 * @Group        SF-Implementation
 * @Description  Repository pattern implementation for Member Stay API data access.
 *               Centralizes all queries for Stay, Member, TransactionJournal, Account, 
 *               JournalSubType, and Product records for consistency and testability.
 *******************************************************************************************/
/* MODIFICATION LOG
* Version          Developer          Date               Description
*-------------------------------------------------------------------------------------------
*  1.0             Sai Vinay Thumu   11/02/2026        Initial Creation for LYLT-367, LYLT-8556
*  2.0             Akanksha Gautam   23/02/2026        Update for Unique Stay Creation LYLT - 9096
*  3.0             Naman Gupta      04/03/2026         Add logic for eligible revenue calculation LYLT-12396
*  4.0             Praveen          09/03/2026         LYLT-10400 - Stay Too High Dollar
*  5.0             Sai Vinay Thumu  13/03/2026          Add Name, Program.Name, MemberId, JournalSubTypeId, GET Stay API fields to findByIdsForPostProcessing; add findPropertyInfoByCodes (LYLT-8586, LYLT-6928)
*  6.0             Anand Pandey     16/03/2026        Added logic for annually sum for CurrentYear and Previous Year (LYLT-12077)
*******************************************************************************************/
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity')
public with sharing class MemberStayDataService {

    /**
     * @description Finds a stay by its ID with transaction journals
     * @param stayId Stay ID to query
     * @param loyaltyProgramName Optional loyalty program name for filtering
     * @return Loyalty_Stay__c Stay record with transaction journals, or null if not found
     */
    public static Loyalty_Stay__c findById(Id stayId, String loyaltyProgramName) {
        if (stayId == null) {
            return null;
        }

        List<Loyalty_Stay__c> stays = [
            SELECT Id, Name, Stay_Status__c, Membership_Number__c,
                   Membership_Number__r.Id, Membership_Number__r.MemberStatus,
                   Membership_Number__r.MembershipNumber, Membership_Number__r.Program.Name,
                   Checkin_Date__c, Checkout_Date__c, Reservation_Confirmation_Number__c,
                   Property_Code__c, Loyalty_Tier__c, Total_Eligible_Revenue__c,EQN_Type__c,
                   Total_Elite_Qualifying_Nights__c, Stay_Scenario__c, Stay_Source_Category__c,
                   Payment_Type_Identifier__c,
                   (SELECT Id, Status, USD_Value_Converted__c, Earn_Eligibility__c, 
                           Loyalty_Stay__c, MemberId, JournalSubTypeId
                    FROM Transaction_Journal__r
                    WHERE Status != :StayAndEarnApexConstants.TJ_STATUS_CANCELLED)
            FROM Loyalty_Stay__c
            WHERE Id = :stayId
              AND Stay_Status__c != :StayAndEarnApexConstants.STAY_STATUS_CANCELLED
            WITH USER_MODE
            LIMIT 1
        ];

        // Filter by loyalty program if provided (post-query filter to avoid SOQL complexity)
        if (String.isNotBlank(loyaltyProgramName) && !stays.isEmpty()) {
            Loyalty_Stay__c stay = stays[0];
            if (stay.Membership_Number__r?.Program?.Name != loyaltyProgramName) {
                return null; // Stay belongs to different program
            }
        }

        return stays.isEmpty() ? null : stays[0]; // Cannot use ?? here - checking isEmpty(), not null
    }

    /**
     * @description Finds a stay by Name with transaction journals (used by CEC PUT).
     * @param stayName Stay identifier from URL (Loyalty_Stay__c.Name)
     * @param loyaltyProgramName Optional loyalty program name for filtering
     * @return Loyalty_Stay__c Stay record with transaction journals, or null if not found
     */
    public static Loyalty_Stay__c findByName(String stayName, String loyaltyProgramName) {
        if (String.isBlank(stayName)) {
            return null;
        }

        List<Loyalty_Stay__c> stays = [
            SELECT Id, Name, Stay_Status__c, Membership_Number__c,
                   Membership_Number__r.Id, Membership_Number__r.MemberStatus,
                   Membership_Number__r.MembershipNumber, Membership_Number__r.Program.Name,
                   Checkin_Date__c, Checkout_Date__c, Reservation_Confirmation_Number__c,
                   Property_Code__c, Loyalty_Tier__c, Total_Eligible_Revenue__c,EQN_Type__c,
                   Total_Elite_Qualifying_Nights__c, Stay_Scenario__c, Stay_Source_Category__c,
                   Payment_Type_Identifier__c,
                   (SELECT Id, Status, USD_Value_Converted__c, Earn_Eligibility__c,
                           Loyalty_Stay__c, MemberId, JournalSubTypeId
                    FROM Transaction_Journal__r
                    WHERE Status != :StayAndEarnApexConstants.TJ_STATUS_CANCELLED)
            FROM Loyalty_Stay__c
            WHERE Name = :stayName
              AND Stay_Status__c != :StayAndEarnApexConstants.STAY_STATUS_CANCELLED
            WITH USER_MODE
            LIMIT 1
        ];

        if (String.isNotBlank(loyaltyProgramName) && !stays.isEmpty()) {
            Loyalty_Stay__c stay = stays[0];
            if (stay.Membership_Number__r?.Program?.Name != loyaltyProgramName) {
                return null;
            }
        }

        return stays.isEmpty() ? null : stays[0];
    }

    /**
     * @description Gets current Stay_Status__c for a stay (S117/S118 concurrent modification check).
     * @param stayId Stay ID to query
     * @return String Current Stay_Status__c, or null if not found
     */
    public static String getCurrentStayStatus(Id stayId) {
        if (stayId == null) {
            return null;
        }
        List<Loyalty_Stay__c> stays = [
            SELECT Id, Stay_Status__c
            FROM Loyalty_Stay__c
            WHERE Id = :stayId
            WITH USER_MODE
            LIMIT 1
        ];
        return stays.isEmpty() ? null : stays[0].Stay_Status__c;
    }

    /**
     * @description Gets current Stay_Status__c for a stay and locks the row (FOR UPDATE)
     *              to serialize concurrent CEC PUT adjustments.
     * @param stayId Stay ID to query and lock
     * @return String Current Stay_Status__c, or null if not found
     */
    public static String getCurrentStayStatusForUpdate(Id stayId) {
        if (stayId == null) {
            return null;
        }
        List<Loyalty_Stay__c> stays = [
            SELECT Id, Stay_Status__c
            FROM Loyalty_Stay__c
            WHERE Id = :stayId
            WITH USER_MODE
            LIMIT 1
            FOR UPDATE
        ];
        return stays.isEmpty() ? null : stays[0].Stay_Status__c;
    }

    /**
     * @description Re-queries stay to get Name (auto-number) after insert.
     *              Auto-number Name is not populated in sObject after DML; re-query is required.
     * @param stay Stay record with Id (Name may be null after insert)
     * @return Loyalty_Stay__c Stay with Name and response fields populated, or original if not found
     */
    public static Loyalty_Stay__c refreshStayForResponse(Loyalty_Stay__c stay) {
        if (stay == null || String.isNotBlank(stay.Name)) {
            return stay;
        }
        List<Loyalty_Stay__c> refreshed = [
            SELECT Id, Name, Stay_Status__c, Disposition_Error_Code__c, Stay_Disposition_Reason__c, Total_Eligible_Revenue__c
            FROM Loyalty_Stay__c
            WHERE Id = :stay.Id
            WITH USER_MODE
            LIMIT 1
        ];
        return refreshed.isEmpty() ? stay : refreshed[0];
    }

    /**
     * @description Finds stays by member, dates, reservation, and property criteria
     * @param memberId Member ID
     * @param checkIn Check-in date
     * @param checkOut Check-out date
     * @param confirmationNumber Reservation confirmation number
     * @param propertyCode Property code
     * @return List<Loyalty_Stay__c> List of matching stays, ordered by CreatedDate DESC
     */
    public static List<Loyalty_Stay__c> findByCriteria(
        Id memberId,
        Date checkIn,
        Date checkOut,
        String confirmationNumber,
        String propertyCode
    ) {
        if (memberId == null || checkIn == null || checkOut == null || String.isBlank(confirmationNumber)) {
            return new List<Loyalty_Stay__c>();
        }

        return [
            SELECT Id, Name, Stay_Status__c, Membership_Number__c, 
                   Membership_Number__r.MembershipNumber,
                   Checkin_Date__c, Checkout_Date__c, Reservation_Confirmation_Number__c,
                   Property_Code__c, Loyalty_Tier__c, Total_Eligible_Revenue__c,EQN_Type__c, 
                   Total_Elite_Qualifying_Nights__c, Stay_Scenario__c, Stay_Source_Category__c,
                   Payment_Type_Identifier__c,
                   (SELECT Id, Status, USD_Value_Converted__c, Earn_Eligibility__c,Program_Of_Record__c, 
                           Loyalty_Stay__c, MemberId, JournalSubTypeId
                    FROM Transaction_Journal__r
                    WHERE Status != :StayAndEarnApexConstants.TJ_STATUS_CANCELLED)
            FROM Loyalty_Stay__c
            WHERE Membership_Number__c = :memberId
              AND Checkin_Date__c = :checkIn
              AND Checkout_Date__c = :checkOut
              AND Reservation_Confirmation_Number__c = :confirmationNumber
              AND Property_Code__c = :propertyCode
              AND Stay_Status__c != :StayAndEarnApexConstants.STAY_STATUS_CANCELLED
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ];
    }

    /**
     * @description Finds stays by IDs for GET Member Stay API using dynamic SOQL from custom labels.
     *              Uses LoyaltyStayFieldstoQueryforGetStayAPI and TransactionJournalFieldstoQueryforGetStayAPI.
     * @param stayIds Set of stay IDs to query
     * @return List<Loyalty_Stay__c> List of stays with transaction journals
     */
    public static List<Loyalty_Stay__c> findByIdsForGetApi(Set<Id> stayIds) {
        if (stayIds == null || stayIds.isEmpty()) {
            return new List<Loyalty_Stay__c>();
        }
        Map<String, List<String>> fieldMappings = LoyaltyIntegrationUtils.getGetStayFieldMappingsFromLabels();
        String soql = buildGetStayDynamicSoql(fieldMappings);
        if (String.isBlank(soql)) {
            return new List<Loyalty_Stay__c>();
        }
        soql += ' WHERE Id IN :stayIds WITH USER_MODE';
        return Database.query(soql);
    }

    /**
     * @description Finds a single stay by Name for GET Member Stay API using dynamic SOQL from custom labels.
     *              Uses LoyaltyStayFieldstoQueryforGetStayAPI and TransactionJournalFieldstoQueryforGetStayAPI.
     * @param stayName Stay identifier (Loyalty_Stay__c.Name) from URL
     * @return List<Loyalty_Stay__c> Single matching stay (or empty list if not found)
     */
    public static List<Loyalty_Stay__c> findByNameForGetApi(String stayName) {
        if (String.isBlank(stayName)) {
            return new List<Loyalty_Stay__c>();
        }
        Map<String, List<String>> fieldMappings = LoyaltyIntegrationUtils.getGetStayFieldMappingsFromLabels();
        String soql = buildGetStayDynamicSoql(fieldMappings);
        if (String.isBlank(soql)) {
            return new List<Loyalty_Stay__c>();
        }
        soql += ' WHERE Name = :stayName WITH USER_MODE LIMIT 1';
        return Database.query(soql);
    }

    /**
     * @description Finds stays by membership number and date range for GET Member Stay API using dynamic SOQL from custom labels.
     *              Requires both startDate and endDate; returns empty list if either is missing.
     *              Uses LoyaltyStayFieldstoQueryforGetStayAPI and TransactionJournalFieldstoQueryforGetStayAPI.
     * @param membershipNumber Membership number (string)
     * @param startDate Required check-in filter
     * @param endDate Required check-out filter
     * @return List<Loyalty_Stay__c> List of stays with transaction journals, ordered by Checkin_Date__c DESC
     */
    public static List<Loyalty_Stay__c> findStaysByMemberAndDateRangeForGetApi(String membershipNumber, Date startDate, Date endDate) {
        if (String.isBlank(membershipNumber) || startDate == null || endDate == null) {
            return new List<Loyalty_Stay__c>();
        }
        Map<String, List<String>> fieldMappings = LoyaltyIntegrationUtils.getGetStayFieldMappingsFromLabels();
        String soql = buildGetStayDynamicSoql(fieldMappings);
        if (String.isBlank(soql)) {
            return new List<Loyalty_Stay__c>();
        }
        soql += ' WHERE Membership_Number__r.MembershipNumber = :membershipNumber';
        soql += ' AND Checkin_Date__c >= :startDate AND Checkout_Date__c <= :endDate';
        soql += ' WITH USER_MODE ORDER BY Checkin_Date__c DESC';
        return Database.query(soql);
    }

    /**
     * @description Builds dynamic SOQL for GET Stay API from custom labels.
     *              LoyaltyStayFieldstoQueryforGetStayAPI, TransactionJournalFieldstoQueryforGetStayAPI.
     */
    private static String buildGetStayDynamicSoql(Map<String, List<String>> fieldMappings) {
        List<String> stayFields = fieldMappings != null ? fieldMappings.get(StayAndEarnApexConstants.OBJECT_LOYALTY_STAY) : null;
        List<String> tjFields = fieldMappings != null ? fieldMappings.get(StayAndEarnApexConstants.REL_OBJECT_TRANSACTION_JOURNAL) : null;
        if (stayFields == null || stayFields.isEmpty() || tjFields == null || tjFields.isEmpty()) {
            return '';
        }
        String staySelect = String.join(stayFields, ', ');
        String tjSelect = String.join(tjFields, ', ');
        return 'SELECT ' + staySelect + ', (SELECT ' + tjSelect + ' FROM Transaction_Journal__r) FROM Loyalty_Stay__c ';
    }

    /**
     * @description Finds stays by IDs for post-processing (includes aggregation fields)
     *              Used by StayPostProcessingService for aggregating points and EQN
     * @param stayIds Set of stay IDs to query
     * @return List<Loyalty_Stay__c> List of stays with transaction journals for aggregation
     */
    public static List<Loyalty_Stay__c> findByIdsForPostProcessing(Set<Id> stayIds) {
        if (stayIds == null || stayIds.isEmpty()) {
            return new List<Loyalty_Stay__c>();
        }

        return [
            SELECT Id, Name, Membership_Number__c, Membership_Number__r.Id, Membership_Number__r.EarningPrefCode__c, Membership_Number__r.Program.Name,
                   Total_Base_Points__c, Total_Elite_Bonus_Points__c, Total_Extra_Points__c,
                   Total_Elite_Qualifying_Nights__c, Stay_Status__c, Checkin_Date__c, Checkout_Date__c, Stay_Source__c,
                   Is_Source_CEC__c, Is_Source_GXP__c,
                   Property_Code__c, Total_Eligible_Revenue__c, Total_Eligible_Revenue_Local__c,
                   Earning_Preference__c, Payment_Type_Identifier__c, CreatedDate, Reservation_Confirmation_Number__c,
                   (SELECT Id, Loyalty_Stay__c, MemberId, JournalSubTypeId, Base_Points__c, Elite_Bonus_Points__c, Extra_Points__c,
                           Is_EQN_Qualified__c, StartDate, EndDate, Establishment, Visit_Type__c, Program_Of_Record__c,
                           Earn_Eligibility__c, USD_Value_Converted__c, Status, ErrorDescription, IsParentTransaction, TransactionAmount, ActivityDate,
                           Folio_Number__c, Redemption_Transaction_Id__c, Transaction_Type__c, CurrencyIsoCode, Partner.Partner_Id__c
                    FROM Transaction_Journal__r)
            FROM Loyalty_Stay__c
            WHERE Id IN :stayIds
            WITH USER_MODE
        ];
    }

    /**
     * @description Finds a stay by Name for CEC PATCH/delete flow.
     * @param stayName Stay identifier from URL (Loyalty_Stay__c.Name)
     * @return Loyalty_Stay__c Stay with journals, or null if blank/not found
     */
    public static Loyalty_Stay__c findByNameForPatchDelete(String stayName) {
        if (String.isBlank(stayName)) {
            return null;
        }

        List<Loyalty_Stay__c> stays = [
            SELECT Id, Name, Membership_Number__c, Membership_Number__r.Id,
                   Checkout_Date__c, Total_Base_Points__c, Total_Elite_Bonus_Points__c, Total_Extra_Points__c,
                   Total_Elite_Qualifying_Nights__c, Stay_Status__c,
                   (SELECT Id, Loyalty_Stay__c, MemberId, JournalSubTypeId, Base_Points__c, Elite_Bonus_Points__c, Extra_Points__c,
                           Is_EQN_Qualified__c, StartDate, EndDate, Establishment, Visit_Type__c, Program_Of_Record__c,
                           Earn_Eligibility__c, USD_Value_Converted__c, Status, ErrorDescription, IsParentTransaction, TransactionAmount, ActivityDate,
                           Folio_Number__c, Redemption_Transaction_Id__c, Transaction_Type__c, CurrencyIsoCode, Partner.Partner_Id__c
                    FROM Transaction_Journal__r)
            FROM Loyalty_Stay__c
            WHERE Name = :stayName
            WITH USER_MODE
            LIMIT 1
        ];
        return stays.isEmpty() ? null : stays[0];
    }

    /**
     * @description Finds existing stays for duplicate/overlap validation
     *              Queries stays that overlap with the given date range for a member
     *              Excludes Suspended and Exception status stays
     * @param memberId Member ID
     * @param startDate Check-in date (start of date range)
     * @param endDate Check-out date (end of date range)
     * @return List<Loyalty_Stay__c> List of overlapping stays
     */
    public static List<Loyalty_Stay__c> findOverlappingStays(Id memberId, Date startDate, Date endDate) {
        if (memberId == null || startDate == null || endDate == null) {
            return new List<Loyalty_Stay__c>();
        }

        return [
            SELECT Id, Membership_Number__c, Property_Code__c, Checkin_Date__c, Checkout_Date__c,
                   Reservation_Confirmation_Number__c, Stay_Status__c
            FROM Loyalty_Stay__c
            WHERE Membership_Number__c = :memberId
              AND Checkin_Date__c <= :endDate
              AND Checkout_Date__c >= :startDate
              AND Stay_Status__c NOT IN (:StayAndEarnApexConstants.STAY_STATUS_SUSPENDED, :StayAndEarnApexConstants.STAY_STATUS_EXCEPTION, :StayAndEarnApexConstants.STAY_STATUS_CANCELLED)
            WITH USER_MODE
        ];
    }

    /******************************
     * Member (LoyaltyProgramMember) Queries
     ******************************/

    /**
     * @description Queries LoyaltyProgramMember with tier information using program ID (optimized)
     *              Centralized method to query member with current tier information
     *              for use across Member Stay API operations.
     * @param membershipNumber Membership number to query
     * @param loyaltyProgramId Program ID (pre-queried to avoid duplicate query)
     * @return LoyaltyProgramMember Member record with tier subquery, or null if not found
     */
    public static LoyaltyProgramMember findMemberWithTier(String membershipNumber, Id loyaltyProgramId) {
        if (String.isBlank(membershipNumber) || loyaltyProgramId == null) {
            return null;
        }

        List<LoyaltyProgramMember> members = [
            SELECT Id, MemberStatus, MembershipNumber, EarningPrefCode__c,
                   (SELECT Id, LoyaltyTier.Id, LoyaltyTier.Name, LoyaltyTierGroup.Name, EffectiveDate, TierExpirationDate
                    FROM Loyalty_Member_Tier
                    WHERE LoyaltyTierGroup.Name = :TierAssessmentConstants.LOYALTYTIERGROUP_TIERS
                    ORDER BY EffectiveDate DESC
                    LIMIT 1)
            FROM LoyaltyProgramMember
            WHERE MembershipNumber = :membershipNumber
              AND ProgramId = :loyaltyProgramId
            WITH USER_MODE
            LIMIT 1
        ];

        return members.isEmpty() ? null : members[0];
    }

    /**
     * @description Overloaded method for backward compatibility - queries program ID first
     * @param membershipNumber Membership number to query
     * @param loyaltyProgramName Program name (will be converted to ID)
     * @return LoyaltyProgramMember Member record with tier subquery, or null if not found
     */
    public static LoyaltyProgramMember findMemberWithTier(String membershipNumber, String loyaltyProgramName) {
        if (String.isBlank(membershipNumber) || String.isBlank(loyaltyProgramName)) {
            return null;
        }
        Id loyaltyProgramId = LoyaltyIntegrationUtils.getLoyaltyProgramId(loyaltyProgramName);
        return findMemberWithTier(membershipNumber, loyaltyProgramId);
    }

    /******************************
     * Property (Account) Queries
     ******************************/

    /**
     * @description Queries Account (Property) record by property code.
     *              Centralized method to query property with all fields needed for validation
     *              for use across Member Stay API operations.
     * @param propertyCode The property code to query
     * @return Account The property record with brand relationship, or null if not found
     */
    public static Account findPropertyByCode(String propertyCode) {
        if (String.isBlank(propertyCode)) {
            return null;
        }

        String propertyRecordType = StayAndEarnApexConstants.RECORD_TYPE_PROPERTY;
        List<Account> properties = [
            SELECT Id, PropertyCode__c, Property_Open_Date__c, Property_Close_Date__c,
                   Marriott_Rewards_Eligibility__c, Stay_High_Dollar__c, Brand__c,
                   Brand__r.Id, Brand__r.Rewards_Eligible__c, Brand__r.Earn_Day_Use_Stay_Eligible__c, Brand__r.Max_Stay_Amount__c
            FROM Account
            WHERE PropertyCode__c = :propertyCode
            AND RecordType.DeveloperName = :propertyRecordType
            WITH USER_MODE
            LIMIT 1
        ];

        return properties.isEmpty() ? null : properties[0];
    }

    /**
     * @description Queries Account (Property) records by property codes for GET Stay API.
     *              Returns propertyName (Brand__r.Name) and brandCode (Brand__r.Brand__c).
     * @param propertyCodes Set of property codes to query
     * @return Map<PropertyCode, Map<propertyName|brandCode, value>>
     */
    public static Map<String, Map<String, String>> findPropertyInfoByCodes(Set<String> propertyCodes) {
        Map<String, Map<String, String>> propMap = new Map<String, Map<String, String>>();
        if (propertyCodes == null || propertyCodes.isEmpty()) {
            return propMap;
        }
        for (Account a : [
            SELECT PropertyCode__c, Name, Brand__r.Name, Brand__r.Brand__c
            FROM Account
            WHERE RecordType.DeveloperName = :StayAndEarnApexConstants.RECORD_TYPE_PROPERTY
              AND PropertyCode__c IN :propertyCodes
            WITH USER_MODE
        ]) {
            if (String.isNotBlank(a.PropertyCode__c)) {
                propMap.put(a.PropertyCode__c, new Map<String, String>{
                    StayAndEarnApexConstants.PROP_INFO_PROPERTY_NAME => String.isNotBlank(a.Name) ? a.Name : (a.Brand__r != null ? a.Brand__r.Name : null),
                    StayAndEarnApexConstants.PROP_INFO_BRAND_CODE => a.Brand__r != null ? a.Brand__r.Brand__c : null
                });
            }
        }
        return propMap;
    }

    /******************************
     * TransactionJournal Queries
     ******************************/

    /**
     * @description Queries TransactionJournals by their IDs
     *              Used for querying reversal TransactionJournals created by cancelAccrual action
     * @param tjIds List of TransactionJournal IDs
     * @return List<TransactionJournal> TransactionJournal records
     */
    public static List<TransactionJournal> findTransactionJournalsByIds(List<Id> tjIds) {
        if (tjIds == null || tjIds.isEmpty()) {
            return new List<TransactionJournal>();
        }

        return [
            SELECT Id, MemberId, CreatedDate, Status, JournalReason, JournalType.Name, JournalSubTypeId, Loyalty_Stay__c
            FROM TransactionJournal
            WHERE Id IN :tjIds
            WITH USER_MODE
        ];
    }

    /**
     * @description Calculates total eligible revenue using aggregation for journals with Base_Points__c > 0
     *              Used for synchronous Total_Eligible_Revenue__c calculation (Stay File source)
     * @param stayId Stay ID
     * @return Decimal Total eligible revenue, or 0 if no qualifying journals found
     */
    public static Decimal calculateTotalEligibleRevenue(Id stayId) {

        List<AggregateResult> results = [
            SELECT SUM(USD_Value_Converted__c) totalRevenue
            FROM TransactionJournal
            WHERE Loyalty_Stay__c = :stayId
                AND Base_Points__c > 0
            WITH USER_MODE
        ];
        
        Decimal revenue = (results[0].get('totalRevenue') != null) ? (Decimal)results[0].get('totalRevenue') : 0;

        return revenue;
    }

    /**
     * @description Queries reversal TransactionJournals by criteria (fallback when IDs not available)
     *              Used when cancelAccrual action doesn't return reversal TJ IDs in output
     * @param memberId Member ID
     * @param stayId Stay ID (can be null)
     * @param journalTypeName Journal type name (e.g., "Accrual Reversal")
     * @param journalReason Journal reason (e.g., "Stay Adjusted")
     * @param createdAfter DateTime threshold for finding recently created reversal TJs
     * @param limitCount Maximum number of records to return
     * @return List<TransactionJournal> Reversal TransactionJournals
     */
    public static List<TransactionJournal> findReversalTransactionJournalsByCriteria(
        Id memberId,
        Id stayId,
        String journalTypeName,
        String journalReason,
        DateTime createdAfter,
        Integer limitCount
    ) {
        if (memberId == null) {
            return new List<TransactionJournal>();
        }

        return [
            SELECT Id, MemberId, CreatedDate, Status, JournalReason, JournalType.Name, JournalSubTypeId, Loyalty_Stay__c
            FROM TransactionJournal
            WHERE JournalType.Name = :journalTypeName
                AND JournalReason = :journalReason
                AND CreatedDate >= :createdAfter
                AND MemberId = :memberId
                AND (Loyalty_Stay__c = :stayId OR Loyalty_Stay__c = null)
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT :limitCount
        ];
    }

    /******************************
     * JournalSubType Queries
     ******************************/

    /**
     * @description Queries JournalSubType records with related JournalType data
     * @param subTypeNames Set of JournalSubType names to query
     * @return List<SObject> JournalSubType records with JournalType relationship
     */
    public static List<SObject> findJournalSubTypes(Set<String> subTypeNames) {
        if (subTypeNames == null || subTypeNames.isEmpty()) {
            return new List<SObject>();
        }

        return Database.query(
            'SELECT Id, Name, JournalTypeId, JournalType.Name FROM JournalSubType WHERE Name IN :subTypeNames WITH USER_MODE'
        );
    }

    /******************************
     * Product Queries
     ******************************/

    /**
     * @description Queries Product records by ProductCode
     * @param productCodes Set of ProductCode values to query
     * @return Map<String, Id> Map of ProductCode (lowercase) to Product Id
     */
     public static Map<String, Id> findProductsByCodes(Set<String> productCodes) {
        Map<String, Id> productMap = new Map<String, Id>();

        if (productCodes == null || productCodes.isEmpty()) {
            return productMap;
        }

        for (Product2 prod : [
            SELECT Id, ProductCode
            FROM Product2
            WHERE ProductCode IN :productCodes
            WITH USER_MODE
        ]) {
            productMap.put(prod.ProductCode.toLowerCase(), prod.Id);
        }

        return productMap;
    }

        /******************************
     * Extended Stay Grouping Queries (LYLT-13089)
     ******************************/
    /**
     * @description Queries Loyalty_Stay__c records sharing the same Extended Stay Group Key,
     *              ordered by CreatedDate ASC so index 0 is always the anchor (earliest) stay.
     *              Used by MemberStayService.setExtendedStayGroupingFields to resolve the parent/anchor stay.
     * @param groupKey The Extended_Stay_Group_Key__c value to match
     * @return List<Loyalty_Stay__c> Matching stays ordered oldest-first, or empty list if key is blank
     */
    public static List<Loyalty_Stay__c> findByGroupKey(String groupKey) {
        return [
            SELECT Id, CreatedDate, Parent_Extended_Stay__c, Stay_Scenario__c
            FROM Loyalty_Stay__c
            WHERE Extended_Stay_Group_Key__c = :groupKey
            WITH USER_MODE
            ORDER BY CreatedDate ASC
        ];
    }


    /******************************
     * LoyaltyLedger Queries
     ******************************/

    /**
     * @description Queries LoyaltyLedger entries for given transaction journals and currency names.
     *              Used by MemberCurrencyYearTotalsHelper to aggregate Points and EQS year totals.
     * @param tjIds Set of TransactionJournal IDs
     * @param currencyNames Set of LoyaltyProgramCurrency names to filter by
     * @return List<LoyaltyLedger> Ledger entries matching the criteria
     */
    public static List<LoyaltyLedger> findLedgerEntriesByTransactionJournals(Set<Id> tjIds, Set<String> currencyNames) {
        return [
            SELECT TransactionJournalId, Points, LoyaltyProgramMemberId,
                   LoyaltyProgramCurrency.Name
            FROM LoyaltyLedger
            WHERE TransactionJournalId IN :tjIds
            AND LoyaltyProgramCurrency.Name IN :currencyNames
            WITH USER_MODE
        ];
    }

    /******************************
     * LoyaltyMemberCurrency Queries
     ******************************/

    /**
     * @description Queries LoyaltyMemberCurrency records for given members and currency names.
     *              Used by MemberCurrencyYearTotalsHelper to apply accumulated year totals.
     * @param memberIds Set of LoyaltyProgramMember IDs
     * @param currencyNames Set of LoyaltyProgramCurrency names to filter by
     * @return List<LoyaltyMemberCurrency> Member currency records matching the criteria
     */
    public static List<LoyaltyMemberCurrency> findMemberCurrencies(Set<Id> memberIds, Set<String> currencyNames) {
        return [
            SELECT Id, LoyaltyMemberId, LoyaltyProgramCurrency.Name, Current_Year__c, Previous_Year__c
            FROM LoyaltyMemberCurrency
            WHERE LoyaltyMemberId IN :memberIds
            AND LoyaltyProgramCurrency.Name IN :currencyNames
            WITH USER_MODE
        ];
    }
}