/*******************************************************************************************
 * @Name         MemberStayValidator.cls
 * @Author       Praveen
 * @Date         05/01/2026
 * @Group        SF-Implementation
 * @Description  Validator class for Member Stay API.
 *               Performs member, stay date & age, property, rate plan, and duplicate/overlap validations.
 *               CEC (Empower) validation is in MemberStayCecValidator.
 *               Assumes a SINGLE STAY per request - all TJs belong to that one stay.
 *               Stay-level data is extracted from the FIRST TJ in the request.
 *               Executes single queries for each validation category and validates in sequence.
 *******************************************************************************************/
 /* MODIFICATION LOG
 * Version          Developer          Date               Description
 *-------------------------------------------------------------------------------------------
 *  1.0             Praveen                   05/01/2026        Initial Creation for LYLT-7402
 *  2.0             Sakshi                    05/02/2026        New Logic Added For Host Multiple and Back to Back Stay
 *  3.0             Sai Vinay Thumu           11/02/2026        LYLT-367, LYLT-8556
 *  4.0             Praveen                   13/02/2026        LYLT-10257 - Product Code is required if not a parent transaction
 *  5.0             Sai Vinay Thumu           13/02/2026        LYLT-8896 - 1015 No Points Earned on Incidental Stays (POST and PUT)
 *  6.0				Astha Goyal				  01/03/2026		LYLT-12088
 *  7.0             Sai Vinay Thumu           13/03/2026        Extended Stay: allow same confirmation when previous checkout = current checkin (Connected PMS only)
 *  8.0             Praveen                   09/03/2026        LYLT-10400 - Added Validation for Max Eligibile Amount Exceeded
 *  9.0             Anisha Kurmana            12/03/2026        LYLT-12416 Day Use differentiator for backtoback and hostmultiple
 *******************************************************************************************/

@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssCount')
public with sharing class MemberStayValidator {

    private String loyaltyProgramName;
    private Id loyaltyProgramId;
    private String membershipNumber;
    private String establishmentCode;
    private Date startDate;
    private Date endDate;
    private String confirmationNumber;
    private String origin;
    private String staySourceCategory;
    private String visitType;
    private Boolean redemptionRateFlag;
    private ValidationResult result;
    private String rateCodePlan;
    private Boolean skipRatePlanForCec = false;

    // ACCT_STOP_CUST continues validation but tracks pending validation code
    private String pendingValidationCode;

    private static Map<String, StayValidationCodeDispositionMapping__mdt> dispositionMappings;
    private static List<Map<String, String>> requiredFieldRulesCache;

    static {
        loadDispositionMappings();
    }

    private static void loadDispositionMappings() {
        dispositionMappings = StayValidationCodeDispositionMapping__mdt.getAll();
    }

    /**
     * @description Initializes validator with loyalty program and request data
     * @param loyaltyProgramName The name of the loyalty program
     * @param firstRequest The transaction journal request containing stay details
     */
    public MemberStayValidator(String loyaltyProgramName, TransactionJournalRequest firstRequest) {
        this.loyaltyProgramName = loyaltyProgramName;
        this.result = new ValidationResult();

        if (firstRequest != null) {
            this.membershipNumber = firstRequest.membershipNumber;
            this.establishmentCode = firstRequest.establishment;
            this.startDate = firstRequest.startDate;
            this.endDate = firstRequest.endDate;
            this.confirmationNumber = firstRequest.reservationConfirmationNumber;
            this.origin = firstRequest.origin;
            this.visitType = firstRequest.visitType;
            this.redemptionRateFlag = firstRequest.redemptionRateFlag;
            this.rateCodePlan = firstRequest.rateCodePlan;
        }

        loadStaySourceCategory();
    }

    /**
     * @description Sets the cached loyalty program ID to avoid duplicate queries
     * @param loyaltyProgramId Program ID (pre-queried)
     */
    public void setLoyaltyProgramId(Id loyaltyProgramId) {
        this.loyaltyProgramId = loyaltyProgramId;
    }

    /**
     * @description When true (CEC PUT), skips rate plan exception validation
     */
    public void setSkipRatePlanForCec(Boolean skip) {
        this.skipRatePlanForCec = skip == true;
    }

    /**
     * @description Validates the structure of the parsed JSON request body.
     *              Checks for missing transactionJournals key and empty array.
     * @param wrapperMap Parsed JSON map (already deserialized)
     * @param res RestResponse for error handling
     * @return Boolean - true if valid, false if invalid (error response already set)
     */
    public static Boolean validateRequestBodyStructure(Map<String, Object> wrapperMap, RestResponse res) {
        if (!wrapperMap.containsKey(StayAndEarnApexConstants.JSON_KEY_TRANSACTION_JOURNALS)) {
            LoyaltyIntegrationUtils.setStayErrorArrayResponse(res, 400, new List<Map<String, String>>{
                new Map<String, String>{
                    ApexConstants.ERROR_CODE    => String.valueOf(ApexConstants.ErrorCode.INVALID_API_INPUT),
                    ApexConstants.ERROR_MESSAGE => StayAndEarnApexConstants.ERR_MSG_EMPTY_OR_MALFORMED_JSON
                }
            });
            return false;
        }

        List<Object> jsonArray = (List<Object>) wrapperMap.get(StayAndEarnApexConstants.JSON_KEY_TRANSACTION_JOURNALS);
        if (jsonArray == null || jsonArray.isEmpty()) {
            LoyaltyIntegrationUtils.setStayErrorArrayResponse(res, 400, new List<Map<String, String>>{
                new Map<String, String>{
                    ApexConstants.ERROR_CODE    => String.valueOf(ApexConstants.ErrorCode.INVALID_API_INPUT),
                    ApexConstants.ERROR_MESSAGE => StayAndEarnApexConstants.ERR_MSG_REQUEST_BODY_EMPTY
                }
            });
            return false;
        }

        return true;
    }

    /**
     * @description Validates that all required fields are present in a TransactionJournalRequest.
     *              Uses getRequiredFieldRules() for iteration. Adding a new required field = one map entry.
     *              productCode uses STRING_UNLESS_PARENT (required unless isParentTransaction).
     * @param req TransactionJournalRequest to validate
     * @return List of missing required field names (API display names)
     */
    public static List<String> getMissingRequiredFields(TransactionJournalRequest req) {
        List<String> missingFields = new List<String>();
        Map<String, Object> reqMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(req));

        for (Map<String, String> rule : getRequiredFieldRules()) {
            Object value = reqMap.get(rule.get(StayAndEarnApexConstants.RULE_KEY_FIELD_KEY));
            if (isFieldEmpty(value, rule.get(StayAndEarnApexConstants.RULE_KEY_CHECK_TYPE), req) == true) {
                missingFields.add(rule.get(StayAndEarnApexConstants.RULE_KEY_DISPLAY_NAME));
            }
        }
        return missingFields;
    }

    /**
     * @description Determines if a field value is considered empty based on check type.
     * @param value Field value from request (may be null)
     * @param checkType STRING, DATETIME, or STRING_UNLESS_PARENT
     * @param req Full request (needed for STRING_UNLESS_PARENT to check isParentTransaction)
     * @return True when the field is missing/empty
     */
    private static Boolean isFieldEmpty(Object value, String checkType, TransactionJournalRequest req) {
        if (StayAndEarnApexConstants.CHECK_TYPE_STRING_UNLESS_PARENT.equals(checkType)) {
            return isStringEmpty(value) && req.isParentTransaction != true;
        }
        if (StayAndEarnApexConstants.CHECK_TYPE_DATETIME.equals(checkType)) {
            return value == null;
        }
        return isStringEmpty(value);  // CHECK_TYPE_STRING
    }

    private static Boolean isStringEmpty(Object value) {
        return value == null || (value instanceof String && String.isBlank((String) value));
    }

    /**
     * @description Validates that ALL requests have required fields
     * @param requests List of all request wrappers
     * @throws MemberStayService.MemberStayException if validation fails
     */
    public static void validateAllRequests(List<TransactionJournalRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            throw new MemberStayService.MemberStayException(
                StayAndEarnApexConstants.ERR_MSG_REQUEST_BODY_EMPTY,
                String.valueOf(ApexConstants.ErrorCode.INVALID_API_INPUT)
            );
        }

        List<String> validationErrors = new List<String>();
        Integer index = 0;

        for (TransactionJournalRequest req : requests) {
            List<String> missingFields = getMissingRequiredFields(req);
            if (!missingFields.isEmpty()) {
                validationErrors.add(
                    StayAndEarnApexConstants.ERR_MSG_TRANSACTION_MISSING_FIELDS_PREFIX + index + StayAndEarnApexConstants.ERR_MSG_TRANSACTION_MISSING_FIELDS_SUFFIX +
                    String.join(missingFields, ', ')
                );
            }
            index++;
        }

        if (!validationErrors.isEmpty()) {
            throw new MemberStayService.MemberStayException(
                String.join(validationErrors, '; '),
                String.valueOf(ApexConstants.ErrorCode.INVALID_API_INPUT)
            );
        }
    }

    /**
     * @description Main entry point for stay validation. Executes all validation checks in sequence:
     *              1. Member  2. Date/Age  3. Property  4. Duplicate/Overlap
     *              Also detects and sets Stay Scenarios (HostMultiple, BackToBack).
     * @return ValidationResult containing validation outcome, error details, and scenario flags
     */
    public ValidationResult validate() {
        return validate(null, null);
    }

    /**
     * @description Overloaded validate with pre-queried records to avoid duplicate queries.
     * @param preQueriedMember Optional pre-queried LoyaltyProgramMember record
     * @param preQueriedProperty Optional pre-queried Account (Property) record
     * @return ValidationResult containing validation outcome and error details
     */
    public ValidationResult validate(LoyaltyProgramMember preQueriedMember, Account preQueriedProperty) {
        return validateWithDuplicateCheck(preQueriedMember, preQueriedProperty, true);
    }

    /**
     * @description Internal method that performs validation with optional duplicate check control.
     * @param preQueriedMember Optional pre-queried LoyaltyProgramMember record
     * @param preQueriedProperty Optional pre-queried Account (Property) record
     * @param includeDuplicateCheck Whether to include duplicate/overlap validations
     * @return ValidationResult containing validation outcome and error details
     */
    private ValidationResult validateWithDuplicateCheck(LoyaltyProgramMember preQueriedMember, Account preQueriedProperty, Boolean includeDuplicateCheck) {
        result.staySourceCategory = this.staySourceCategory;
        result.startDate = this.startDate;
        result.endDate = this.endDate;

        if (!validateMember(preQueriedMember)) {
            return result;
        }
        if (!validateStayDateAndAge()) {
            return result;
        }
        if (!validateProperty(preQueriedProperty)) {
            return result;
        }
        if (!skipRatePlanForCec && !validateRatePlanException()) {
            return result;
        }
        if (includeDuplicateCheck) {
            if (!validateDuplicateOverlap()) {
                return result;
            }
        }

        if (String.isNotBlank(this.pendingValidationCode)) {
            result.setFromMapping(this.pendingValidationCode);
        }

        return result;
    }

    /**
     * @description Adjustment validation — runs all checks EXCEPT duplicate/overlap (LYLT-367).
     * @param preQueriedMember Optional pre-queried LoyaltyProgramMember record
     * @param preQueriedProperty Optional pre-queried Account (Property) record
     * @return ValidationResult containing validation outcome and error details
     */
    public ValidationResult validateForAdjustment(LoyaltyProgramMember preQueriedMember, Account preQueriedProperty) {
        return validateWithDuplicateCheck(preQueriedMember, preQueriedProperty, false);
    }

    /**
     * @description Runs ALL validations independently and returns every failure without short-circuiting.
     *              Convenience overload — includes duplicate/overlap check (POST behaviour).
     * @param preQueriedMember Optional pre-queried LoyaltyProgramMember record
     * @param preQueriedProperty Optional pre-queried Account (Property) record
     * @return List of ValidationResult objects — one entry per failed check, empty when all pass
     */
    public List<ValidationResult> collectAllValidationFailures(LoyaltyProgramMember preQueriedMember, Account preQueriedProperty) {
        return collectAllValidationFailures(preQueriedMember, preQueriedProperty, true);
    }

    /**
     * @description Runs ALL validations independently and returns every failure without short-circuiting.
     *              Used by CEC POST and CEC PUT aggregated validation flows to collect all errors in one pass.
     *              Each check runs against a fresh result so failures do not block subsequent checks.
     *              ACCT_STOP_CUST is treated as a hard failure for CEC (no stay creation allowed).
     * @param preQueriedMember Optional pre-queried LoyaltyProgramMember record
     * @param preQueriedProperty Optional pre-queried Account (Property) record
     * @param includeDuplicateCheck When true runs duplicate/overlap check (POST); false skips it (PUT)
     * @return List of ValidationResult objects — one entry per failed check, empty when all pass
     */
    public List<ValidationResult> collectAllValidationFailures(LoyaltyProgramMember preQueriedMember, Account preQueriedProperty, Boolean includeDuplicateCheck) {
        List<ValidationResult> failures = new List<ValidationResult>();

        // 1. Member validation
        result.staySourceCategory = this.staySourceCategory;
        result.startDate = this.startDate;
        result.endDate = this.endDate;
        Boolean memberPassed = validateMember(preQueriedMember);
        LoyaltyProgramMember resolvedMember = result.memberRecord;
        if (!memberPassed) {
            failures.add(result);
        }
        // ACCT_STOP_CUST continues the standard flow but must be a hard failure for CEC
        if (String.isNotBlank(this.pendingValidationCode)) {
            ValidationResult pendingFailure = new ValidationResult();
            pendingFailure.setFromMapping(this.pendingValidationCode);
            failures.add(pendingFailure);
            this.pendingValidationCode = null;
        }

        // 2. Date/age validation — independent of member result
        this.result = new ValidationResult();
        if (!validateStayDateAndAge()) {
            failures.add(result);
        }

        // 3. Property validation — independent of member result
        this.result = new ValidationResult();
        if (!validateProperty(preQueriedProperty)) {
            failures.add(result);
        }

        // 4. Rate plan exception validation — independent check
        this.result = new ValidationResult();
        if (!skipRatePlanForCec && !validateRatePlanException()) {
            failures.add(result);
        }

        // 5. Duplicate/overlap — POST only; PUT skips this check (adjusting an existing stay)
        if (includeDuplicateCheck && resolvedMember != null) {
            this.result = new ValidationResult();
            this.result.memberRecord = resolvedMember;
            if (!validateDuplicateOverlap()) {
                failures.add(result);
            }
        }

        return failures;
    }

    /**
     * @description Looks up Stay Source Category from Stay_Source_Mapping__mdt custom metadata
     *              based on the origin field. Maps origin values to categories for conditional validation.
     */
    private void loadStaySourceCategory() {
        if (String.isBlank(this.origin)) {
            return;
        }

        Stay_Source_Mapping__mdt mapping = Stay_Source_Mapping__mdt.getInstance(this.origin);

        if (mapping != null) {
            this.staySourceCategory = mapping.Category__c;
        }
    }

    /**
     * @description Performs member-level validations: ACCT_NOT_FOUND, ACCT_DECEASED,
     *              ACCT_STOP_CUST (continues validation), ACCT_STOP_MARR.
     * @param preQueriedMember Optional pre-queried LoyaltyProgramMember record
     * @return Boolean - true if validation passes, false if validation fails
     */
    private Boolean validateMember(LoyaltyProgramMember preQueriedMember) {
        LoyaltyProgramMember member = null;

        if (preQueriedMember != null && preQueriedMember.Id != null
            && preQueriedMember.MembershipNumber == membershipNumber) {
            member = preQueriedMember;
        }

        if (member == null) {
            if (loyaltyProgramId != null) {
                member = MemberStayDataService.findMemberWithTier(membershipNumber, loyaltyProgramId);
            } else {
                member = MemberStayDataService.findMemberWithTier(membershipNumber, loyaltyProgramName);
            }

            if (member == null) {
                result.setNotFound(StayAndEarnApexConstants.VALIDATION_ACCT_NOT_FOUND);
                return false;
            }
        }

        result.memberRecord = member;

        if (member.MemberStatus == StayAndEarnApexConstants.MEMBER_STATUS_DECEASED) {
            result.setFromMapping(StayAndEarnApexConstants.VALIDATION_ACCT_DECEASED);
            return false;
        }

        // ACCT_STOP_CUST: special case — continue validations but track pending code
        if (member.MemberStatus == StayAndEarnApexConstants.MEMBER_STATUS_STOPPED_BY_CUSTOMER) {
            this.pendingValidationCode = StayAndEarnApexConstants.VALIDATION_ACCT_STOP_CUST;
        }

        if (member.MemberStatus == StayAndEarnApexConstants.MEMBER_STATUS_STOPPED_BY_MARRIOTT) {
            result.setFromMapping(StayAndEarnApexConstants.VALIDATION_ACCT_STOP_MARR);
            return false;
        }

        return true;
    }

    /**
     * @description Performs stay date and age validations: INVALID_DATE_RANGE, FUTURE_STAY
     *              (check-in future → SM01; check-out only future → 1005; both future → SM01),
     *              STAY_TOO_OLD_24M, STAY_TOO_OLD_18M.
     * @return Boolean - true if validation passes, false if validation fails
     */
    private Boolean validateStayDateAndAge() {
        Date today = Date.today();

        if (startDate == null || endDate == null) {
            return true;
        }

        if (endDate < startDate) {
            result.setFromMapping(StayAndEarnApexConstants.VALIDATION_INVALID_DATE_RANGE);
            return false;
        }

        if (startDate > today || endDate > today) {
            Boolean isFutureCheckIn = startDate > today;
            Boolean isConnectedPms = this.staySourceCategory == StayAndEarnApexConstants.STAY_SOURCE_CONNECTED_PMS;
            String mappingKey = isConnectedPms
                ? (isFutureCheckIn ? StayAndEarnApexConstants.VALIDATION_FUTURE_STAY_CONNECTED_PMS_CHECK_IN  : StayAndEarnApexConstants.VALIDATION_FUTURE_STAY_CONNECTED_PMS_CHECK_OUT)
                : (isFutureCheckIn ? StayAndEarnApexConstants.VALIDATION_FUTURE_STAY_STAY_FILE_CHECK_IN      : StayAndEarnApexConstants.VALIDATION_FUTURE_STAY_STAY_FILE_CHECK_OUT);
            result.setFromMapping(mappingKey);
            return false;
        }

        Integer stayAgeDays = endDate.daysBetween(today);

        if (stayAgeDays > StayAndEarnApexConstants.STAY_AGE_24_MONTHS_DAYS) {
            result.setFromMapping(StayAndEarnApexConstants.VALIDATION_STAY_TOO_OLD_24M);
            return false;
        }

        if (stayAgeDays >= StayAndEarnApexConstants.STAY_AGE_18_MONTHS_DAYS) {
            result.setFromMapping(StayAndEarnApexConstants.VALIDATION_STAY_TOO_OLD_18M);
            return false;
        }

        return true;
    }

    /**
     * @description Performs property-level validations: PROP_CODE_EMPTY, PROP_NOT_FOUND,
     *              PROP_NOT_OPEN, PROP_NON_PARTICIPATING, BRAND_NON_PARTICIPATING.
     * @param preQueriedProperty Optional pre-queried Account (Property) record
     * @return Boolean - true if validation passes, false if validation fails
     */
    private Boolean validateProperty(Account preQueriedProperty) {
        if (String.isBlank(establishmentCode)) {
            result.setFromMapping(StayAndEarnApexConstants.VALIDATION_PROP_CODE_EMPTY);
            return false;
        }

        Account property = null;

        if (preQueriedProperty != null && preQueriedProperty.Id != null
            && preQueriedProperty.PropertyCode__c == establishmentCode) {
            property = preQueriedProperty;
        }

        if (property == null) {
            property = MemberStayDataService.findPropertyByCode(establishmentCode);

            if (property == null) {
                result.setFromMapping(StayAndEarnApexConstants.VALIDATION_PROP_NOT_FOUND);
                return false;
            }
        }

        result.propertyRecord = property;

        if (!isPropertyOpenDuringStay(property)) {
            result.setFromMapping(StayAndEarnApexConstants.VALIDATION_PROP_NOT_OPEN);
            return false;
        }

        if (property.Marriott_Rewards_Eligibility__c == false) {
            result.setFromMapping(StayAndEarnApexConstants.VALIDATION_PROP_NON_PARTICIPATING);
            return false;
        }

        if (property.Brand__c != null && property.Brand__r.Rewards_Eligible__c == false) {
            result.setFromMapping(StayAndEarnApexConstants.VALIDATION_BRAND_NON_PARTICIPATING);
            return false;
        }

        // 1015 – No Points Earned on Incidental Stays 
        if (property != null && property.Brand__r != null 
            && (StayAndEarnApexConstants.VISIT_TYPE_REDEMPTION_DAY_USE_STAY.equals(visitType)
                || StayAndEarnApexConstants.VISIT_TYPE_PAID_DAY_USE_STAY.equals(visitType))
            && redemptionRateFlag == true
            && property.Brand__r.Earn_Day_Use_Stay_Eligible__c == false) {
                result.setFromMapping(StayAndEarnApexConstants.VALIDATION_INCIDENTAL_NO_EARN);
                return false;   
            }

        return true;
    }

    /**
     * @description Checks if the property was open during the entire stay period.
     * @param property The Account (Property) record to check
     * @return Boolean - true if property was open during stay, false otherwise
     */
    private Boolean isPropertyOpenDuringStay(Account property) {
        if (startDate == null || endDate == null) {
            return true;
        }

        Boolean openBeforeStart = (property.Property_Open_Date__c == null ||
                                   startDate >= property.Property_Open_Date__c);
        Boolean openAfterEnd = (property.Property_Close_Date__c == null ||
                                endDate <= property.Property_Close_Date__c);

        return openBeforeStart && openAfterEnd;
    }
    
    /**
     * @description Checks if the rate plan code has a corresponding StayValidationCodeDispositionMapping__mdt record.
     * @return Boolean - true if rate plan is not ineligible, false if a matching metadata record is found
     */
    private Boolean validateRatePlanException() {
        if (String.isNotBlank(this.rateCodePlan) && dispositionMappings.containsKey(this.rateCodePlan)) {
            result.setFromMapping(this.rateCodePlan);
            return false;
        }
        return true;
    }

    /**
     * @description Performs duplicate and overlap validations against existing Loyalty_Stay__c records.
     *              Same Property: DUPLICATE_STAY, MULTI_ROOM_EXCEEDED.
     *              Different Property: OVERLAPPING_STAY.
     *              Scenario Detection: HostMultiple (2nd/3rd room), BackToBack (consecutive nights).
     *              Extended Stay: same confirmation, previous checkout = current checkin — allowed (Connected PMS only).
     *              Host Multiple takes precedence over Back-to-Back.
     * @return Boolean - true if validation passes, false if validation fails
     */
    private Boolean validateDuplicateOverlap() {
        if (startDate == null || endDate == null) {
            return true;
        }

        List<Loyalty_Stay__c> existingStays = MemberStayDataService.findOverlappingStays(result.memberRecord.Id, startDate, endDate);

        if (existingStays.isEmpty()) {
            return true;
        }

        List<Loyalty_Stay__c> samePropertyStays = new List<Loyalty_Stay__c>();
        List<Loyalty_Stay__c> diffPropertyStays = new List<Loyalty_Stay__c>();
        Integer sameRangeCount = 0;

        for (Loyalty_Stay__c stay : existingStays) {
            if (stay.Property_Code__c == establishmentCode) {
                samePropertyStays.add(stay);
            } else {
                diffPropertyStays.add(stay);
            }
        }

        Integer hostMultipleCount = 0;
        Integer backToBackCount = 0;

        for (Loyalty_Stay__c stay : samePropertyStays) {
            Boolean isSameDates = (stay.Checkin_Date__c == startDate &&
                                   stay.Checkout_Date__c == endDate);

            Boolean isExactDuplicate = (isSameDates &&
                                        stay.Reservation_Confirmation_Number__c == confirmationNumber);

            // Extended stay: same confirmation, previous checkout = current checkin (adjacent segments)
            // Only for Connected PMS — TIP sends Settlement Indicator only from Connected PMS
            if (this.staySourceCategory == StayAndEarnApexConstants.STAY_SOURCE_CONNECTED_PMS
                    && stay.Reservation_Confirmation_Number__c == confirmationNumber
                    && stay.Checkout_Date__c == startDate) {
                continue;
            }

            // Back-to-back: consecutive nights, different reservation, Posted status — skip overlap check
            if (stay.Checkout_Date__c == startDate &&
                stay.Reservation_Confirmation_Number__c != confirmationNumber &&
                stay.Stay_Status__c == StayAndEarnApexConstants.STAY_STATUS_POSTED && !isSameDates) { //LYLT-12416 added condition to skip samedates
                backToBackCount++;
                continue;
            }

            Boolean isOverlap = (stay.Checkin_Date__c <= endDate &&
                                 stay.Checkout_Date__c >= startDate &&
                                 !isSameDates);

            if (isExactDuplicate || isOverlap) {
                result.setFromMapping(StayAndEarnApexConstants.VALIDATION_DUPLICATE_STAY);
                return false;
            }

            // Multi-room: same dates, different confirmation — max 3 rooms allowed
            if (isSameDates &&
                stay.Reservation_Confirmation_Number__c != confirmationNumber) {
                sameRangeCount++;

                if (sameRangeCount >= 3) {
                    result.setFromMapping(StayAndEarnApexConstants.VALIDATION_MULTI_ROOM_EXCEEDED);
                    return false;
                } else if (stay.Stay_Status__c == StayAndEarnApexConstants.STAY_STATUS_POSTED) {
                    hostMultipleCount++;
                }
            }
        }

        for (Loyalty_Stay__c stay : diffPropertyStays) {
            Boolean isExactDuplicate = (stay.Checkin_Date__c == startDate &&
                                        stay.Checkout_Date__c == endDate);

            Boolean isOverlap = (stay.Checkin_Date__c <= endDate &&
                                 stay.Checkout_Date__c >= startDate &&
                                 !isExactDuplicate);

            if (isExactDuplicate || isOverlap) {
                result.setFromMapping(StayAndEarnApexConstants.VALIDATION_OVERLAPPING_STAY);
                return false;
            }
        }

        // Priority: Host Multiple > Back-to-Back
        if (hostMultipleCount > 0 && hostMultipleCount <= StayAndEarnApexConstants.HOST_MULTIPLE_MAX_ROOM_COUNT) {
            result.stayScenario = StayAndEarnApexConstants.STAY_SCENARIO_HOST_MULTIPLE;
        } else if (backToBackCount >= 1) {
            result.stayScenario = StayAndEarnApexConstants.STAY_SCENARIO_BACK_TO_BACK;
        }

        return true;
    }

    /**
     * @description Checks if the stay's total eligible revenue exceeds the property maximum.
     *              If exceeded, sets REVENUE_TOO_LARGE disposition on the validation result.
     *              Skips the check for Connected PMS stays.
     * @param validationResult - ValidationResult containing stay dates and property record
     * @param stay - The created Loyalty_Stay__c record with stamped totalEligibleRevenue
     * @return true if revenue exceeds max and disposition was set, false otherwise
     */
    public static Boolean checkRevenueExceedsMax(ValidationResult validationResult, Loyalty_Stay__c stay) {
        if (stay.Stay_Source_Category__c == StayAndEarnApexConstants.STAY_SOURCE_CONNECTED_PMS
            || validationResult.startDate == null || validationResult.endDate == null) {
            return false;
        }
        Integer stayDuration = Math.max(validationResult.startDate.daysBetween(validationResult.endDate), 1);
        Decimal maxEligibleRevenue = Math.min(
            (validationResult.propertyRecord?.Stay_High_Dollar__c ?? 0) * stayDuration,
            (validationResult.propertyRecord?.Brand__r.Max_Stay_Amount__c ?? 0) * stayDuration
        );
        if (stay.Total_Eligible_Revenue__c > maxEligibleRevenue) {
            validationResult.setFromMapping(StayAndEarnApexConstants.REVENUE_TOO_LARGE);
            return true;
        }
        return false;
    }

    /**
     * @description Returns the required field rules for TransactionJournalRequest validation.
     *              Cached for reuse (avoids allocation when validating many requests).
     *              Each rule maps displayName (API error), fieldKey (property name), and checkType.
     *              Adding a new required field = one map entry in this method.
     * @return List of rule maps
     */
    private static List<Map<String, String>> getRequiredFieldRules() {
        if (requiredFieldRulesCache == null) {
            requiredFieldRulesCache = new List<Map<String, String>>{
                new Map<String, String>{ StayAndEarnApexConstants.RULE_KEY_DISPLAY_NAME => StayAndEarnApexConstants.REQ_FIELD_DISPLAY_MEMBERSHIP_NUMBER, StayAndEarnApexConstants.RULE_KEY_FIELD_KEY => 'membershipNumber', StayAndEarnApexConstants.RULE_KEY_CHECK_TYPE => StayAndEarnApexConstants.CHECK_TYPE_STRING },
                new Map<String, String>{ StayAndEarnApexConstants.RULE_KEY_DISPLAY_NAME => StayAndEarnApexConstants.REQ_FIELD_DISPLAY_ACTIVITY_DATE, StayAndEarnApexConstants.RULE_KEY_FIELD_KEY => 'activityDate', StayAndEarnApexConstants.RULE_KEY_CHECK_TYPE => StayAndEarnApexConstants.CHECK_TYPE_DATETIME },
                new Map<String, String>{ StayAndEarnApexConstants.RULE_KEY_DISPLAY_NAME => StayAndEarnApexConstants.REQ_FIELD_DISPLAY_STATUS, StayAndEarnApexConstants.RULE_KEY_FIELD_KEY => 'status', StayAndEarnApexConstants.RULE_KEY_CHECK_TYPE => StayAndEarnApexConstants.CHECK_TYPE_STRING },
                new Map<String, String>{ StayAndEarnApexConstants.RULE_KEY_DISPLAY_NAME => StayAndEarnApexConstants.REQ_FIELD_DISPLAY_CURRENCY_ISO_CODE, StayAndEarnApexConstants.RULE_KEY_FIELD_KEY => 'currencyIsoCode', StayAndEarnApexConstants.RULE_KEY_CHECK_TYPE => StayAndEarnApexConstants.CHECK_TYPE_STRING },
                new Map<String, String>{ StayAndEarnApexConstants.RULE_KEY_DISPLAY_NAME => StayAndEarnApexConstants.REQ_FIELD_DISPLAY_JOURNAL_TYPE_NAME, StayAndEarnApexConstants.RULE_KEY_FIELD_KEY => 'journalTypeName', StayAndEarnApexConstants.RULE_KEY_CHECK_TYPE => StayAndEarnApexConstants.CHECK_TYPE_STRING },
                new Map<String, String>{ StayAndEarnApexConstants.RULE_KEY_DISPLAY_NAME => StayAndEarnApexConstants.REQ_FIELD_DISPLAY_JOURNAL_SUBTYPE_NAME, StayAndEarnApexConstants.RULE_KEY_FIELD_KEY => 'journalSubTypeName', StayAndEarnApexConstants.RULE_KEY_CHECK_TYPE => StayAndEarnApexConstants.CHECK_TYPE_STRING },
                new Map<String, String>{ StayAndEarnApexConstants.RULE_KEY_DISPLAY_NAME => StayAndEarnApexConstants.REQ_FIELD_DISPLAY_ESTABLISHMENT, StayAndEarnApexConstants.RULE_KEY_FIELD_KEY => 'establishment', StayAndEarnApexConstants.RULE_KEY_CHECK_TYPE => StayAndEarnApexConstants.CHECK_TYPE_STRING },
                new Map<String, String>{ StayAndEarnApexConstants.RULE_KEY_DISPLAY_NAME => StayAndEarnApexConstants.REQ_FIELD_DISPLAY_PRODUCT_CODE, StayAndEarnApexConstants.RULE_KEY_FIELD_KEY => 'productCode', StayAndEarnApexConstants.RULE_KEY_CHECK_TYPE => StayAndEarnApexConstants.CHECK_TYPE_STRING_UNLESS_PARENT },
                new Map<String, String>{ StayAndEarnApexConstants.RULE_KEY_DISPLAY_NAME => StayAndEarnApexConstants.REQ_FIELD_DISPLAY_RATE_CODE_PLAN, StayAndEarnApexConstants.RULE_KEY_FIELD_KEY => 'rateCodePlan', StayAndEarnApexConstants.RULE_KEY_CHECK_TYPE => StayAndEarnApexConstants.CHECK_TYPE_STRING }
            };
        }
        return requiredFieldRulesCache;
    }

    /**
     * @description Encapsulates the result of stay validation — outcome flags, error details,
     *              status values, scenario flags, and queried record references.
     */
    public class ValidationResult {

        public Boolean isNotFound { get; set; }
        public String errorCode { get; set; }
        public String errorMessage { get; set; }
        public String stayStatus { get; set; }
        public String dispositionReason { get; set; }
        public String transactionJournalStatus { get; set; }
        public String staySourceCategory { get; set; }
        public String stayScenario { get; set; }
        public LoyaltyProgramMember memberRecord { get; set; }
        public Account propertyRecord { get; set; }
        public Date startDate { get; set; }
        public Date endDate { get; set; }

        public ValidationResult() {
            this.isNotFound = false;
            this.stayStatus = StayAndEarnApexConstants.STAY_STATUS_IN_PROGRESS;
            this.transactionJournalStatus = StayAndEarnApexConstants.TJ_STATUS_PENDING;
            this.errorCode = '';
            this.errorMessage = '';
            this.dispositionReason = '';
            this.staySourceCategory = '';
            this.stayScenario = '';
        }

        /**
         * @description Sets 404 Not Found state from custom metadata mapping
         * @param validationCode DeveloperName from StayValidationCodeDispositionMapping__mdt
         */
        public void setNotFound(String validationCode) {
            this.isNotFound = true;
            StayValidationCodeDispositionMapping__mdt mapping = dispositionMappings.get(validationCode);
            if (mapping != null) {
                this.errorCode = mapping.Error_Code__c;
                this.errorMessage = mapping.Disposition_Reason__c;
                this.stayStatus = mapping.Stay_Status__c;
                this.transactionJournalStatus = mapping.TJ_Status__c;
            }
        }

        /**
         * @description Sets validation outcome from custom metadata mapping
         * @param validationCode DeveloperName from StayValidationCodeDispositionMapping__mdt
         */
        public void setFromMapping(String validationCode) {
            StayValidationCodeDispositionMapping__mdt mapping = dispositionMappings.get(validationCode);
            if (mapping != null) {
                this.errorCode = mapping.Error_Code__c;
                this.dispositionReason = mapping.Disposition_Reason__c;
                this.stayStatus = mapping.Stay_Status__c;
                this.transactionJournalStatus = mapping.TJ_Status__c;
            }
        }
    }
}