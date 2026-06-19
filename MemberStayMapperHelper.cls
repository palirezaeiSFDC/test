/*******************************************************************************************
 * @Name         MemberStayMapperHelper.cls
 * @Author       Salesforce
 * @Date         01/29/2026
 * @Group        SF-Implementation
 * @Description  Helper class for Member Stay API mapper.
 *               Provides parsing and lookup helper methods for MemberStayMapper.
 *               Handles JSON parsing, validation, field mapping, and lookup operations.
 *******************************************************************************************/
/* MODIFICATION LOG
 * Version          Developer          Date               Description
 *-------------------------------------------------------------------------------------------
 *  1.0             Praveen      01/29/2026        Initial Creation - Extracted from MemberStayMapper
 *  2.0             sai vinay     10/02/2026        udpated as part of lylt-8556
 *  3.0             Akanksha      23/02/2026        LYLT-9096 - Unique Stay Creation
 *******************************************************************************************/
public with sharing class MemberStayMapperHelper {

    /******************************
     * Request Body Parsing Methods
     ******************************/

    /**
     * @description Parses the JSON request body into wrapper objects
     *              Manually maps JSON fields from API spec to wrapper class properties
     * @param requestBody - JSON request body string
     * @param res - RestResponse for error handling
     * @return List<TransactionJournalRequest> - Parsed request objects, or null if error
     */
    public static List<TransactionJournalRequest> parseRequestBody(String requestBody, RestResponse res) {
        try {
            // Validation 1: Blank request body
            if (String.isBlank(requestBody)) {
                LoyaltyIntegrationUtils.setStayErrorArrayResponse(res, 400, new List<Map<String, String>>{
                    new Map<String, String>{
                        ApexConstants.ERROR_CODE    => String.valueOf(ApexConstants.ErrorCode.JSON_PARSER_ERROR),
                        ApexConstants.ERROR_MESSAGE => StayAndEarnApexConstants.ERR_MSG_EMPTY_OR_MALFORMED_JSON
                    }
                });
                return null;
            }

            Object deserializedPayload = JSON.deserializeUntyped(requestBody);
            List<Object> jsonArray;
            String wrapperReasonCode;
            String wrapperStayComment;

            // Support both wrapper object and legacy top-level array payloads.
            if (deserializedPayload instanceof List<Object>) {
                jsonArray = (List<Object>) deserializedPayload;
            } else if (deserializedPayload instanceof Map<String, Object>) {
                Map<String, Object> wrapperMap = (Map<String, Object>) deserializedPayload;
                Object transactionJournalObject = getValueCaseInsensitive(wrapperMap, StayAndEarnApexConstants.JSON_KEY_TRANSACTION_JOURNALS);
                if (!(transactionJournalObject instanceof List<Object>)) {
                    LoyaltyIntegrationUtils.setStayErrorArrayResponse(res, 400, new List<Map<String, String>>{
                        new Map<String, String>{
                            ApexConstants.ERROR_CODE    => String.valueOf(ApexConstants.ErrorCode.INVALID_API_INPUT),
                            ApexConstants.ERROR_MESSAGE => StayAndEarnApexConstants.ERR_MSG_EMPTY_OR_MALFORMED_JSON
                        }
                    });
                    return null;
                }
                jsonArray = (List<Object>) transactionJournalObject;
                // Wrapper-level CEC audit fields (LYLT-6928 AC5) - applied to first request if not in TJ
                wrapperReasonCode = (String) getValueCaseInsensitive(wrapperMap, StayAndEarnApexConstants.JSON_KEY_REASON_CODE);
                wrapperStayComment = (String) getValueCaseInsensitive(wrapperMap, StayAndEarnApexConstants.JSON_KEY_COMMENT);
            } else {
                LoyaltyIntegrationUtils.setStayErrorArrayResponse(res, 400, new List<Map<String, String>>{
                    new Map<String, String>{
                        ApexConstants.ERROR_CODE    => String.valueOf(ApexConstants.ErrorCode.INVALID_API_INPUT),
                        ApexConstants.ERROR_MESSAGE => StayAndEarnApexConstants.ERR_MSG_EMPTY_OR_MALFORMED_JSON
                    }
                });
                return null;
            }

            // Manually map each JSON object to TransactionJournalRequest
            List<TransactionJournalRequest> requests = new List<TransactionJournalRequest>();
            for (Object obj : jsonArray) {
                Map<String, Object> jsonMap = (Map<String, Object>) obj;
                TransactionJournalRequest req = mapJsonToRequest(jsonMap);
                requests.add(req);
            }

            // Apply wrapper-level reasonCode/stayComment to first request if not already set
            if (!requests.isEmpty()) {
                TransactionJournalRequest first = requests[0];
                if (String.isNotBlank(wrapperReasonCode) && String.isBlank(first.reasonCode)) {
                    first.reasonCode = wrapperReasonCode;
                }
                if (String.isNotBlank(wrapperStayComment) && String.isBlank(first.stayComment)) {
                    first.stayComment = wrapperStayComment;
                }
            }

            if (requests.isEmpty()) {
                LoyaltyIntegrationUtils.setStayErrorArrayResponse(res, 400, new List<Map<String, String>>{
                    new Map<String, String>{
                        ApexConstants.ERROR_CODE    => String.valueOf(ApexConstants.ErrorCode.INVALID_API_INPUT),
                        ApexConstants.ERROR_MESSAGE => StayAndEarnApexConstants.ERR_MSG_REQUEST_BODY_EMPTY
                    }
                });
                return null;
            }

            return requests;

        } catch (Exception ex) {
            LoyaltyIntegrationUtils.setStayErrorArrayResponse(res, 400, new List<Map<String, String>>{
                new Map<String, String>{
                    ApexConstants.ERROR_CODE    => String.valueOf(ApexConstants.ErrorCode.JSON_PARSER_ERROR),
                    ApexConstants.ERROR_MESSAGE => StayAndEarnApexConstants.ERR_MSG_JSON_PARSER_ERROR + ex.getMessage()
                }
            });
            return null;
        }
    }

    /**
     * @description Returns a value from map using case-insensitive key match.
     * @param sourceMap Wrapper map
     * @param expectedKey Logical key name
     * @return Object matching value or null when not found
     */
    private static Object getValueCaseInsensitive(Map<String, Object> sourceMap, String expectedKey) {
        if (sourceMap == null || String.isBlank(expectedKey)) {
            return null;
        }
        if (sourceMap.containsKey(expectedKey)) {
            return sourceMap.get(expectedKey);
        }
        for (String key : sourceMap.keySet()) {
            if (key != null && key.equalsIgnoreCase(expectedKey)) {
                return sourceMap.get(key);
            }
        }
        return null;
    }

    /**
     * @description Manually maps JSON field names from API spec to TransactionJournalRequest properties
     *              Maps API spec field names (with __c and snake_case) to wrapper class camelCase properties
     * @param jsonMap - Map containing JSON field names from API spec
     * @return TransactionJournalRequest - Mapped request object
     */
    public static TransactionJournalRequest mapJsonToRequest(Map<String, Object> jsonMap) {
        TransactionJournalRequest req = new TransactionJournalRequest();
        mapBasicFields(req, jsonMap);
        mapDateFields(req, jsonMap);
        mapAmountFields(req, jsonMap);
        mapBooleanFlags(req, jsonMap);
        return req;
    }

    /**
     * @description Maps basic string fields from JSON to request object
     * @param req TransactionJournalRequest to populate
     * @param jsonMap JSON map containing field values
     */
    private static void mapBasicFields(TransactionJournalRequest req, Map<String, Object> jsonMap) {
        req.journalTypeName = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_JOURNAL_TYPE_NAME);
        req.journalTypeId = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_JOURNAL_TYPE_ID);
        req.journalSubTypeName = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_JOURNAL_SUBTYPE_NAME);
        req.journalSubTypeId = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_JOURNAL_SUBTYPE_ID);
        req.membershipNumber = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_MEMBERSHIP_NUMBER);
        req.memberId = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_MEMBER_ID);
        req.productCode = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_PRODUCT_CODE);
        req.productId = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_PRODUCT_ID);
        req.establishment = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_ESTABLISHMENT);
        req.transactionType = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_TRANSACTION_TYPE);
        req.channel = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_CHANNEL);
        req.origin = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_ORIGIN);
        req.status = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_STATUS);
        req.externalTransactionNumber = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_EXTERNAL_TRANSACTION_NUMBER);
        req.currencyIsoCode = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_CURRENCY_ISO_CODE);
        req.reservationConfirmationNumber = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_RESERVATION_CONFIRMATION_NUMBER);
        req.folioNumber = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_FOLIO_NUMBER);
        req.benefits = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_BENEFITS);
        req.rateCodePlan = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_RATE_CODE_PLAN);
        req.GroupIndustry = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_GROUP_INDUSTRY);
        req.visitType = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_VISIT_TYPE);//LYLT-9096//Unique Stays
        req.programOfRecord = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_PROGRAM_OF_RECORD);//LYLT-9096//Unique Stays
        req.settlement = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_SETTLEMENT); // Extended Stay only
        req.reasonCode = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_REASON_CODE); // CEC audit (LYLT-6928 AC5)
        req.stayComment = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_COMMENT); // CEC audit - maps to Loyalty_Stay__c.Comment__c
        req.associateId = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_ASSOCIATE_ID); // CEC (API spec 2026Q1.5.0)
        req.redemptionTransactionId = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_REDEMPTION_TRANSACTION_ID);
        req.paymentTypeIdentifier = (String) jsonMap.get(StayAndEarnApexConstants.JSON_KEY_PAYMENT_TYPE_IDENTIFIER);
    }

    /**
     * @description Maps date/time fields from JSON to request object
     * @param req TransactionJournalRequest to populate
     * @param jsonMap JSON map containing field values
     */
    private static void mapDateFields(TransactionJournalRequest req, Map<String, Object> jsonMap) {
        Object bookingDateObj = jsonMap.get(StayAndEarnApexConstants.JSON_KEY_BOOKING_DATE);
        if (bookingDateObj != null) {
            DateTime bookingDateTime = LoyaltyIntegrationUtils.parseDateTime(String.valueOf(bookingDateObj));
            req.bookingDate = bookingDateTime?.dateGmt();
        }
        Object activityDateObj = jsonMap.get(StayAndEarnApexConstants.JSON_KEY_ACTIVITY_DATE);
        if (activityDateObj != null) {
            req.activityDate = LoyaltyIntegrationUtils.parseDateTime(String.valueOf(activityDateObj));
        }
        Object startDateObj = jsonMap.get(StayAndEarnApexConstants.JSON_KEY_START_DATE);
        if (startDateObj != null) {
            DateTime startDateTime = LoyaltyIntegrationUtils.parseDateTime(String.valueOf(startDateObj));
            req.startDate = startDateTime?.dateGmt();
        }
        Object endDateObj = jsonMap.get(StayAndEarnApexConstants.JSON_KEY_END_DATE);
        if (endDateObj != null) {
            DateTime endDateTime = LoyaltyIntegrationUtils.parseDateTime(String.valueOf(endDateObj));
            req.endDate = endDateTime?.dateGmt();
        }
        Object pmsSetupDateObj = jsonMap.get(StayAndEarnApexConstants.JSON_KEY_PMS_SETUP_DATE);
        if (pmsSetupDateObj != null) {
            DateTime pmsSetupDateTime = LoyaltyIntegrationUtils.parseDateTime(String.valueOf(pmsSetupDateObj));
            req.pmsSetupDate = pmsSetupDateTime?.dateGmt();
        }
    }

    /**
     * @description Maps amount fields from JSON to request object
     * @param req TransactionJournalRequest to populate
     * @param jsonMap JSON map containing field values
     */
    private static void mapAmountFields(TransactionJournalRequest req, Map<String, Object> jsonMap) {
        req.transactionAmount = LoyaltyIntegrationUtils.convertToDecimal(jsonMap.get(StayAndEarnApexConstants.JSON_KEY_TRANSACTION_AMOUNT));
        req.fxRate = LoyaltyIntegrationUtils.convertToDecimal(jsonMap.get(StayAndEarnApexConstants.JSON_KEY_FX_RATE));
        req.usdValueConverted = LoyaltyIntegrationUtils.convertToDecimal(jsonMap.get(StayAndEarnApexConstants.JSON_KEY_USD_VALUE_CONVERTED));
        req.quantity = LoyaltyIntegrationUtils.convertToDecimal(jsonMap.get(StayAndEarnApexConstants.JSON_KEY_QUANTITY));
    }

    /**
     * @description Maps boolean flag fields from JSON to request object
     * @param req TransactionJournalRequest to populate
     * @param jsonMap JSON map containing field values
     */
    private static void mapBooleanFlags(TransactionJournalRequest req, Map<String, Object> jsonMap) {
        req.redemptionRateFlag = LoyaltyIntegrationUtils.convertToBoolean(jsonMap.get(StayAndEarnApexConstants.JSON_KEY_REDEMPTION_RATE_FLAG));
        Object earnEligibilityObj = findEarnEligibilityValue(jsonMap);
        req.earnEligibility = LoyaltyIntegrationUtils.convertToBoolean(earnEligibilityObj);
        req.isNUA = LoyaltyIntegrationUtils.convertToBoolean(jsonMap.get(StayAndEarnApexConstants.JSON_KEY_IS_NUA));
        Object isParentVal = jsonMap.get(StayAndEarnApexConstants.JSON_KEY_IS_PARENT_TRANSACTION);
        req.isParentTransaction = LoyaltyIntegrationUtils.convertToBoolean(isParentVal) ?? false;
    }

    /**
     * @description Finds EarnEligibility value with case-insensitive lookup
     *              Supports both "Earn_Eligibility__c" (correct) and "EarnEligibility__c" (incorrect but common)
     * @param jsonMap JSON map containing field values
     * @return Object EarnEligibility value or null
     */
    private static Object findEarnEligibilityValue(Map<String, Object> jsonMap) {
        Object earnEligibilityObj = jsonMap.get(StayAndEarnApexConstants.JSON_KEY_EARN_ELIGIBILITY);
        if (earnEligibilityObj != null) {
            return earnEligibilityObj;
        }
        for (String key : jsonMap.keySet()) {
            if (key != null && (key.equalsIgnoreCase(StayAndEarnApexConstants.JSON_KEY_EARN_ELIGIBILITY)
                || key.equalsIgnoreCase('EarnEligibility__c'))) {
                return jsonMap.get(key);
            }
        }
        return null;
    }

    /******************************
     * Lookup Helper Methods
     ******************************/

    /**
     * @description Builds lookup maps for JournalSubTypes and JournalTypes from query results
     * @param journalSubTypes - List of JournalSubType records with JournalType relationship
     * @return LookupMaps - Wrapper containing both maps
     */
    public static LookupMaps buildLookupMaps(List<SObject> journalSubTypes) {
        Map<String, String> subTypeMap = new Map<String, String>();
        Map<String, String> typeMap = new Map<String, String>();

        for (SObject tjst : journalSubTypes) {
            String subTypeName = ((String) tjst.get('Name'))?.toLowerCase();
            String subTypeId = (String) tjst.get('Id');
            String typeId = (String) tjst.get('JournalTypeId');
            String typeName = ((String) tjst.getSObject('JournalType')?.get('Name'))?.toLowerCase();

            if (String.isNotBlank(subTypeName) && String.isNotBlank(subTypeId)) {
                subTypeMap.put(subTypeName, subTypeId); // de-dupe by name
            }
            if (String.isNotBlank(typeName) && String.isNotBlank(typeId)) {
                typeMap.put(typeName, typeId); // de-dupe by name
            }
        }

        return new LookupMaps(subTypeMap, typeMap);
    }

    /**
     * @description Validates that all requested JournalSubTypes were found
     * @param requestedNames - Set of requested JournalSubType names
     * @param foundMap - Map of found JournalSubType names to IDs
     */
    public static void validateSubTypes(Set<String> requestedNames, Map<String, String> foundMap) {
        validateLookups(requestedNames, foundMap, 'JournalSubTypeName');
    }

    /**
     * @description Validates that all requested JournalTypes were found
     * @param requestedNames - Set of requested JournalType names
     * @param foundMap - Map of found JournalType names to IDs
     */
    public static void validateTypes(Set<String> requestedNames, Map<String, String> foundMap) {
        validateLookups(requestedNames, foundMap, 'JournalTypeName');
    }

    /**
     * @description Validates that all requested Products were found
     * @param requestedCodes - Set of requested ProductCode values
     * @param foundMap - Map of found ProductCode values to IDs
     */
    public static void validateProducts(Set<String> requestedCodes, Map<String, Id> foundMap) {
        Map<String, String> stringMap = new Map<String, String>();
        for (String key : foundMap.keySet()) {
            stringMap.put(key, String.valueOf(foundMap.get(key)));
        }
        validateLookups(requestedCodes, stringMap, 'ProductCode');
    }

    /**
     * @description Generic validation method for lookups
     * @param requestedValues - Set of requested values
     * @param foundMap - Map of found values (lowercase keys) to IDs
     * @param fieldName - Field name for error message
     */
    private static void validateLookups(Set<String> requestedValues, Map<String, String> foundMap, String fieldName) {
        List<String> missing = new List<String>();
        for (String requestedValue : requestedValues) {
            if (!foundMap.containsKey(requestedValue.toLowerCase())) {
                missing.add(requestedValue);
            }
        }
        if (!missing.isEmpty()) {
            throw new MemberStayService.MemberStayException(
                'Invalid ' + fieldName + ': ' + String.join(missing, ', '),
                String.valueOf(ApexConstants.ErrorCode.INVALID_API_INPUT)
            );
        }
    }

    /**
     * @description Inner class to hold lookup maps for JournalTypes and JournalSubTypes
     */
    public class LookupMaps {
        public Map<String, String> subTypeMap;
        public Map<String, String> typeMap;

        /**
         * @description Constructor for LookupMaps wrapper class
         * @param subTypeMap - Map of JournalSubType names (lowercase) to their IDs
         * @param typeMap - Map of JournalType names (lowercase) to their IDs
         */
        public LookupMaps(Map<String, String> subTypeMap, Map<String, String> typeMap) {
            this.subTypeMap = subTypeMap;
            this.typeMap = typeMap;
        }
    }
}