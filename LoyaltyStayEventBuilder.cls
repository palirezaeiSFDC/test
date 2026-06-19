/*******************************************************************************************
* @Name         LoyaltyStayEventBuilder.cls
* @group        SF-Implementation
* @description  Builds Loyalty_Stay_Event__e platform events by querying stays, resolving
*               brand codes, and mapping stay/journal data to event fields.
*******************************************************************************************/
/* MODIFICATION LOG
* Version          Developer          Date               Description
*-------------------------------------------------------------------------------------------
*  1.0              Anand Pandey    02/03/2026        Initial Creation - Extracted from LoyaltyStayEventPublisher
*******************************************************************************************/
public with sharing class LoyaltyStayEventBuilder {

    /**
     * @description Queries stays with related TransactionJournal and Member data.
     * @param stayIds Set of Loyalty_Stay__c record IDs
     * @return List<Loyalty_Stay__c> Hydrated stay records
     */
    
    public static List<Loyalty_Stay__c> queryStays(Set<Id> stayIds) {
        return [
            SELECT Id, Name, Stay_Status__c, Stay_Source__c, Property_Code__c,
                   Checkin_Date__c, Checkout_Date__c,
                   Total_Elite_Qualifying_Nights__c,
                   CreatedDate,
                   Reservation_Confirmation_Number__c,
                   Membership_Number__r.MembershipNumber,
                   Related_Stay__r.Name,
                   Total_Revenue__c, Payment_Type_Identifier__c,
                   Is_Member_First_Stay__c,
                   (SELECT Folio_Number__c, Rate_Plan_Code__c, Associate_Id__c,
                           Visit_Type__c
                    FROM Transaction_Journal__r WHERE isParentTransaction = false AND Benefits__c = null LIMIT 1)
            FROM Loyalty_Stay__c
            WHERE Id IN :stayIds
            WITH USER_MODE
        ];
    }

    /**
     * @description Resolves Brand Codes by querying Property Accounts for each stay's Property Code.
     * @param stays List of stay records
     * @return Map<String, String> Property Code to Brand Code
     */
    
    public static Map<String, String> queryBrandCodes(List<Loyalty_Stay__c> stays) {
        Set<String> codes = new Set<String>();
        for (Loyalty_Stay__c s : stays) {
            if (String.isNotBlank(s.Property_Code__c)) {
                codes.add(s.Property_Code__c);
            }
        }
        Map<String, String> brandMap = new Map<String, String>();
        if (codes.isEmpty()) {
            return brandMap;
        }
        for (Account propertyAccount : [
            SELECT PropertyCode__c, Brand__r.Brand__c FROM Account
            WHERE RecordType.DeveloperName = :StayAndEarnApexConstants.RECORD_TYPE_PROPERTY
                AND PropertyCode__c IN :codes WITH USER_MODE
        ]) {
            if (String.isNotBlank(propertyAccount.PropertyCode__c) && propertyAccount.Brand__r != null) {
                brandMap.put(propertyAccount.PropertyCode__c, propertyAccount.Brand__r.Brand__c);
            }
        }
        return brandMap;
    }

    /**
     * @description Builds a single event using newSObject() to pre-populate EventUuid.
     * @param stay Hydrated Loyalty_Stay__c record
     * @param brandCodes Property Code to Brand Code map
     * @return Loyalty_Stay_Event__e Populated event
     */
    
    public static Loyalty_Stay_Event__e buildEvent(Loyalty_Stay__c stay, Map<String, String> brandCodes) {
        Loyalty_Stay_Event__e evt = (Loyalty_Stay_Event__e)
            Loyalty_Stay_Event__e.sObjectType.newSObject(null, true);

        evt.Loyalty_Stay__c = stay.Name;
        evt.Stay_Status__c = stay.Stay_Status__c;
        evt.Property_Code__c = stay.Property_Code__c;
        evt.Checkin_Date__c = stay.Checkin_Date__c;
        evt.Checkout_Date__c = stay.Checkout_Date__c;
        evt.Elite_Qualifying_Nights__c = stay.Total_Elite_Qualifying_Nights__c;
        evt.Stay_Posted_Date__c = stay.CreatedDate;
        evt.Reservation_Confirmation_Number__c = stay.Reservation_Confirmation_Number__c;
        evt.Membership_Number__c = stay.Membership_Number__r?.MembershipNumber;
        evt.Related_Stay__c = stay.Related_Stay__r?.Name;
        evt.Stay_Source__c = stay.Stay_Source__c;
        evt.Brand_Code__c = brandCodes.get(stay.Property_Code__c);
        evt.Total_Revenue__c = stay.Total_Revenue__c;
        evt.Payment_Type_Identifier__c = stay.Payment_Type_Identifier__c;
        evt.Is_Member_First_Stay__c = stay.Is_Member_First_Stay__c;

        List<TransactionJournal> journals = stay.Transaction_Journal__r;
        if (journals != null && !journals.isEmpty()) {
            TransactionJournal tj = journals[0];
            evt.Folio_Number__c = tj.Folio_Number__c;
            evt.Rate_Plan_Code__c = tj.Rate_Plan_Code__c;
            evt.Associate_Id__c = tj.Associate_Id__c;
            evt.Visit_Type__c = tj.Visit_Type__c;
        }
        return evt;
    }
}