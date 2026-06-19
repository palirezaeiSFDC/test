/*******************************************************************************************
 * @Name         MemberStayCecValidator.cls
 * @Author       Salesforce
 * @Group        SF-Implementation
 * @Description  CEC (Empower) validation for Member Stay API.
 * Validates POST/PUT/PATCH requests for CEC flow: 18-month rule (1124 POST HTTP 400, 1003 PUT/MODIFY HTTP 400, 1119 PATCH HTTP 400), stay not found,
 * stay cancelled, CEC_MISSING_STAY block. Uses StayValidationCodeDispositionMapping.
 * S117/S118 remain as separate pre-DML checks in StayAdjustmentService.
 *******************************************************************************************/
/* MODIFICATION LOG
 * Version          Developer          Date               Description
 *-------------------------------------------------------------------------------------------
 * 1.0             Sai Vinay Thumu    13/02/2026        Extracted from MemberStayValidator (LYLT-12591)
 *******************************************************************************************/
public with sharing class MemberStayCecValidator {

    private static final Map<String, Map<String, String>> CEC_DISPOSITION_FALLBACK = new Map<String, Map<String, String>>{
        StayAndEarnApexConstants.VALIDATION_CANNOT_DELETE_STAY => new Map<String, String>{ ApexConstants.ERROR_CODE => StayAndEarnApexConstants.CEC_ERROR_S115, ApexConstants.ERROR_MESSAGE => StayAndEarnApexConstants.CEC_MSG_CANNOT_DELETE_ALREADY },
        StayAndEarnApexConstants.VALIDATION_STAY_NOT_EDITABLE => new Map<String, String>{ ApexConstants.ERROR_CODE => StayAndEarnApexConstants.CEC_ERROR_S114, ApexConstants.ERROR_MESSAGE => StayAndEarnApexConstants.CEC_MSG_CANNOT_MODIFY_ALREADY_DELETED },
        StayAndEarnApexConstants.VALIDATION_STAY_NOT_FOUND => new Map<String, String>{ ApexConstants.ERROR_CODE => StayAndEarnApexConstants.CEC_ERROR_5004, ApexConstants.ERROR_MESSAGE => StayAndEarnApexConstants.CEC_MSG_STAY_NOT_FOUND },
        StayAndEarnApexConstants.VALIDATION_STAY_TOO_OLD_18M_MODIFY => new Map<String, String>{ ApexConstants.ERROR_CODE => StayAndEarnApexConstants.CEC_ERROR_1003, ApexConstants.ERROR_MESSAGE => StayAndEarnApexConstants.CEC_MSG_STAY_TOO_OLD_18M },
        StayAndEarnApexConstants.VALIDATION_STAY_TOO_OLD_18M_DELETE => new Map<String, String>{ ApexConstants.ERROR_CODE => StayAndEarnApexConstants.CEC_ERROR_1119, ApexConstants.ERROR_MESSAGE => StayAndEarnApexConstants.CEC_MSG_STAY_TOO_OLD_18M_DELETE }
    };

    /**
     * @description Returns true when request origin indicates CEC (Empower) flow.
     * @param origin The origin string from the transaction request
     * @return Boolean True if origin is a CEC type
     */
    public static Boolean isCecRequest(String origin) {
        return StayAndEarnApexConstants.CEC_MODIFY_STAY.equals(origin)
            || StayAndEarnApexConstants.CEC_MISSING_STAY.equals(origin);
    }

    /**
     * @description CEC bulk validation. Runs all applicable CEC rules and returns disposition errors.
     * Callers check list and throw if non-empty.
     * @param operationType 'POST', 'PUT', or 'PATCH'
     * @param stayId Stay ID from URL (required for PUT, PATCH)
     * @param requests Transaction journal requests (required for POST, PUT)
     * @return List of CecDispositionResult - empty if all pass
     */
    public static List<CecDispositionResult> validateCecBulk(String operationType, String stayId, List<TransactionJournalRequest> requests) {
        List<CecDispositionResult> results = new List<CecDispositionResult>();

        if (operationType == StayAndEarnApexConstants.HTTP_METHOD_POST) {
            collectCecPostErrors(requests, results);
        } else if (operationType == StayAndEarnApexConstants.HTTP_METHOD_PUT) {
            collectCecPutErrors(stayId, requests, results);
        } else if (operationType == StayAndEarnApexConstants.HTTP_METHOD_PATCH) {
            collectCecDeleteErrors(stayId, results);
        }
        return results;
    }

    /**********************************************************************************
     * @description   Collects CEC POST errors.
     *                18-month rule (1124): Stay older than 18 months can't be created in Empower (HTTP 400).
     * @param         requests - List of TransactionJournalRequest objects
     * @param         results - List of CecDispositionResult objects
     * @return        void
     **************************************************************************************/
    private static void collectCecPostErrors(List<TransactionJournalRequest> requests, List<CecDispositionResult> results) {
        if (requests == null || requests.isEmpty() || requests[0] == null) {
            return;
        }
        TransactionJournalRequest req = requests[0];
        Date endDate = req.endDate;
        if (endDate == null) {
            return;
        }
        Integer stayAgeDays = endDate.daysBetween(Date.today());
        if (stayAgeDays >= StayAndEarnApexConstants.STAY_AGE_18_MONTHS_DAYS) {
            results.add(createCecResultFromMapping(StayAndEarnApexConstants.VALIDATION_STAY_TOO_OLD_18M, 400));
        }
    }
    /**********************************************************************************
     * @description   Collects CEC PUT errors.
     * @param         stayId - Stay ID
     * @param         requests - List of TransactionJournalRequest objects
     * @param         results - List of CecDispositionResult objects
     * @return        void
     **************************************************************************************/
    private static void collectCecPutErrors(String stayId, List<TransactionJournalRequest> requests, List<CecDispositionResult> results) {
        Loyalty_Stay__c stay = fetchStayByNameForCecPutValidation(stayId, results);
        if (stay == null) {
            return;
        }
        if (stay.Stay_Status__c == StayAndEarnApexConstants.STAY_STATUS_CANCELLED) {
            results.add(createCecResultFromMapping(StayAndEarnApexConstants.VALIDATION_STAY_NOT_EDITABLE, 406));
        }
        if (stay.Checkout_Date__c != null) {
            Integer stayAgeDays = stay.Checkout_Date__c.daysBetween(Date.today());
            if (stayAgeDays >= StayAndEarnApexConstants.STAY_AGE_18_MONTHS_DAYS) {
                results.add(createCecResultFromMapping(StayAndEarnApexConstants.VALIDATION_STAY_TOO_OLD_18M_MODIFY, 400));
            }
        }
        String reqOrigin = (requests != null && !requests.isEmpty() && requests[0] != null) ? requests[0].origin : null;
        if (StayAndEarnApexConstants.CEC_MISSING_STAY.equals(reqOrigin)) {
            results.add(createCecResultFromMapping(StayAndEarnApexConstants.VALIDATION_STAY_NOT_EDITABLE, 406));
        }
    }

    /**********************************************************************************
     * @description   Fetches stay by Name for CEC PUT validation.
     * @param         stayId - Stay record identifier (Name)
     * @param         results - List of CecDispositionResult objects
     * @return        Loyalty_Stay__c - Stay record
     **************************************************************************************/
    private static Loyalty_Stay__c fetchStayByNameForCecPutValidation(String stayId, List<CecDispositionResult> results) {
        // Use patch/delete name lookup so cancelled stays are still found and mapped to NOT_EDITABLE (instead of 5004).
        Loyalty_Stay__c stay = MemberStayDataService.findByNameForPatchDelete(stayId);
        if (stay == null) {
            results.add(createCecResultFromMapping(StayAndEarnApexConstants.VALIDATION_STAY_NOT_FOUND, 404));
            return null;
        }
        return stay;
    }

    /**********************************************************************************
     * @description   Collects CEC PATCH errors.
     *                18-month delete rule (1119): checkout too old — HTTP 400 when added to results.
     * @param         stayId - Stay ID
     * @param         results - List of CecDispositionResult objects
     * @return        void
     **************************************************************************************/
    private static void collectCecDeleteErrors(String stayId, List<CecDispositionResult> results) {
        Loyalty_Stay__c stay = fetchStayByNameForCecDeleteValidation(stayId, results);
        if (stay == null) {
            return;
        }
        if (stay.Stay_Status__c == StayAndEarnApexConstants.STAY_STATUS_CANCELLED) {
            results.add(createCecResultFromMapping(StayAndEarnApexConstants.VALIDATION_CANNOT_DELETE_STAY, 406));
        }
        if (stay.Checkout_Date__c != null) {
            Integer stayAgeDays = stay.Checkout_Date__c.daysBetween(Date.today());
            if (stayAgeDays >= StayAndEarnApexConstants.STAY_AGE_18_MONTHS_DAYS) {
                results.add(createCecResultFromMapping(StayAndEarnApexConstants.VALIDATION_STAY_TOO_OLD_18M_DELETE, 400));
            }
        }
    }

    /**********************************************************************************
     * @description   Fetches stay by Name for CEC PATCH validation.
     * @param         stayId - Stay record identifier (Name)
     * @param         results - List of CecDispositionResult objects
     * @return        Loyalty_Stay__c - Stay record
     **************************************************************************************/
    private static Loyalty_Stay__c fetchStayByNameForCecDeleteValidation(String stayId, List<CecDispositionResult> results) {
        Loyalty_Stay__c stay = StayDeleteService.fetchStayForPatchByName(stayId);
        if (stay == null) {
            results.add(createCecResultFromMapping(StayAndEarnApexConstants.VALIDATION_STAY_NOT_FOUND, 404));
            return null;
        }
        return stay;
    }

    /**********************************************************************************
     * @description   Fetches stay by ID for CEC validation.
     * @param         stayId - Stay ID
     * @param         results - List of CecDispositionResult objects
     * @return        Loyalty_Stay__c - Stay record
     **************************************************************************************/
    private static Loyalty_Stay__c fetchStayByIdForCecValidation(String stayId, List<CecDispositionResult> results) {
        Id validStayId = LoyaltyIntegrationUtils.parseStayId(stayId);
        if (validStayId == null) {
            if (String.isNotBlank(stayId)) {
                results.add(createCecResultFromMapping(StayAndEarnApexConstants.VALIDATION_STAY_NOT_FOUND, 404));
            }
            return null;
        }
        List<Loyalty_Stay__c> stays = MemberStayDataService.findByIdsForPostProcessing(new Set<Id>{ validStayId });
        if (stays.isEmpty()) {
            results.add(createCecResultFromMapping(StayAndEarnApexConstants.VALIDATION_STAY_NOT_FOUND, 404));
            return null;
        }
        return stays[0];
    }

    /**
     * @description Creates a CEC result from metadata or fallback map.
     * @param validationCode The key for the validation mapping
     * @param statusCode The HTTP status code to return
     * @return CecDispositionResult The populated result object
     */
    public static CecDispositionResult createCecResultFromMapping(String validationCode, Integer statusCode) {
        CecDispositionResult r = new CecDispositionResult();
        r.statusCode = statusCode;

        StayValidationCodeDispositionMapping__mdt mapping = resolveCecMapping(validationCode);
        if (mapping != null && String.isNotBlank(mapping.Error_Code__c) && String.isNotBlank(mapping.Disposition_Reason__c)) {
            r.errorCode = mapping.Error_Code__c;
            r.message = mapping.Disposition_Reason__c;
        } else {
            Map<String, String> fallback = CEC_DISPOSITION_FALLBACK.get(validationCode);
            if (fallback != null) {
                r.errorCode = fallback.get(ApexConstants.ERROR_CODE);
                r.message = fallback.get(ApexConstants.ERROR_MESSAGE);
            }
            if (String.isBlank(r.errorCode)) {
                r.errorCode = validationCode;
            }
            if (String.isBlank(r.message)) {
                r.message = StayAndEarnApexConstants.VALIDATION_FAILED_MESSAGE;
            }
        }
        return r;
    }

    /**********************************************************************************
     * @description   Resolves CEC mapping from metadata.
     * @param         validationCode - Validation code
     * @return        StayValidationCodeDispositionMapping__mdt - Mapping record
     **************************************************************************************/
    private static StayValidationCodeDispositionMapping__mdt resolveCecMapping(String validationCode) {
        if (String.isBlank(validationCode)) {
            return null;
        }
        StayValidationCodeDispositionMapping__mdt mapping = StayValidationCodeDispositionMapping__mdt.getInstance(validationCode);
        if (mapping != null) {
            return mapping;
        }
        Map<String, StayValidationCodeDispositionMapping__mdt> all = StayValidationCodeDispositionMapping__mdt.getAll();
        if (all != null) {
            mapping = all.get(validationCode);
            if (mapping != null) {
                return mapping;
            }
            for (StayValidationCodeDispositionMapping__mdt m : all.values()) {
                if (m != null && validationCode.equalsIgnoreCase(m.DeveloperName)) {
                    return m;
                }
            }
        }
        return null;
    }

    /**
     * @description Data wrapper for CEC validation results.
     */
    public class CecDispositionResult {
        /** @description The error code assigned to the result */
        public String errorCode;
        /** @description The descriptive message for the error */
        public String message;
        /** @description The HTTP status code */
        public Integer statusCode;
    }

    /**
     * @description Exception for CEC bulk validation failures. Carries list of disposition results.
     */
    public class MemberStayCecBulkException extends Exception {
        /** @description List of CEC validation results */
        public List<CecDispositionResult> dispositionResults { get; private set; }
        /** @description The HTTP status code for the response */
        public Integer statusCode { get; private set; }

        /**
         * @description Constructor for CEC bulk exception.
         * @param dispositionResults Results to include in the exception
         * @param statusCode HTTP status code
         */
        public MemberStayCecBulkException(List<CecDispositionResult> dispositionResults, Integer statusCode) {
            this('CEC validation failed');
            this.dispositionResults = dispositionResults;
            this.statusCode = statusCode;
        }
    }
}