/*******************************************************************************************
 * @Name         MemberStayCecPostValidator.cls
 * @Author       Sai Vinay Thumu
 * @Date         24/03/2026
 * @Group        SF-Implementation
 * @Description  Consolidation class for CEC Add Stay / Post Stay aggregated validation.
 *               References (does not duplicate) existing validation methods from
 *               MemberStayValidator and MemberStayCecValidator to collect ALL applicable
 *               failures in a single pass before any stay record is created.
 *
 *               Trigger condition: Origin = CEC Empower (isCecRequest = true)
 *
 *               Behaviour:
 *               - Runs every MemberStayValidator check independently via collectAllValidationFailures()
 *               - Converts each ValidationResult failure to a CecDispositionResult (HTTP 406)
 *               - Returns an empty list when all validations pass (proceed to stay creation)
 *               - Returns a non-empty list when one or more failures exist (return 406, no stay created)
 *******************************************************************************************/
/* MODIFICATION LOG
 * Version          Developer          Date               Description
 *-------------------------------------------------------------------------------------------
 *  1.0             Sai Vinay Thumu   24/03/2026        Initial Creation — CEC aggregated POST validation
 *******************************************************************************************/
 public with sharing class MemberStayCecPostValidator {

    /**
     * @description Collects all applicable validation errors for a CEC Add Stay / Post Stay request.
     *              References MemberStayValidator.collectAllValidationFailures() for non-CEC validation
     *              checks (member, date/age, property, rate plan, duplicate/overlap) and converts each
     *              failure to a CecDispositionResult with HTTP 406.
     *              Returns an empty list when all validations pass.
     *
     * @param loyaltyProgramName  Loyalty program name
     * @param loyaltyProgramId    Pre-queried loyalty program Id (from prepareCommonContext)
     * @param firstRequest        First TransactionJournalRequest from the payload
     * @param preQueriedMember    Pre-queried LoyaltyProgramMember (from prepareCommonContext)
     * @param preQueriedProperty  Pre-queried Account/Property (from prepareCommonContext)
     * @param requests            Full list of TransactionJournalRequest objects
     * @return List<MemberStayCecValidator.CecDispositionResult> — empty if all pass, non-empty if any fail
     */
    public static List<MemberStayCecValidator.CecDispositionResult> collectAllErrors(
        String loyaltyProgramName,
        Id loyaltyProgramId,
        TransactionJournalRequest firstRequest,
        LoyaltyProgramMember preQueriedMember,
        Account preQueriedProperty,
        List<TransactionJournalRequest> requests
    ) {
        List<MemberStayCecValidator.CecDispositionResult> allErrors = new List<MemberStayCecValidator.CecDispositionResult>();

        // Run all non-CEC validations independently via MemberStayValidator and collect every failure
        MemberStayValidator validator = new MemberStayValidator(loyaltyProgramName, firstRequest);
        validator.setLoyaltyProgramId(loyaltyProgramId);
        List<MemberStayValidator.ValidationResult> validationFailures =
            validator.collectAllValidationFailures(preQueriedMember, preQueriedProperty);

        for (MemberStayValidator.ValidationResult failure : validationFailures) {
            allErrors.add(toCecDispositionResult(failure));
        }

        return allErrors;
    }

    // Error code stamped on ValidationResult by setFromMapping(VALIDATION_STAY_TOO_OLD_18M)
    // Same value used in processWithValidations non-CEC too-old check ('1124' or CEC_ERROR_1003).
    private static final String ERROR_CODE_STAY_TOO_OLD_18M = '1124';

    /**
     * @description Collects all applicable validation errors for a CEC Modify Stay / PUT request.
     *              Runs every MemberStayValidator check WITHOUT the duplicate/overlap check
     *              (PUT adjusts an existing stay, so a new duplicate is not applicable).
     *              Also evaluates CEC PUT-specific rules against the original stay:
     *                - Cancelled stay → S114 (NOT_EDITABLE)
     *                - Stay checkout ≥ 18 months ago → 1003
     *                - CEC_MISSING_STAY origin on a PUT → S114
     *              Returns an empty list when all validations pass.
     *
     * @param loyaltyProgramName   Loyalty program name
     * @param context              AdjustmentContext populated by findOriginalStayWithContext
     * @param requests             Full list of TransactionJournalRequest objects
     * @return List<MemberStayCecValidator.CecDispositionResult> — empty if all pass, non-empty if any fail
     */
    public static List<MemberStayCecValidator.CecDispositionResult> collectAllPutErrors(
        String loyaltyProgramName,
        StayAdjustmentService.AdjustmentContext context,
        List<TransactionJournalRequest> requests
    ) {
        List<MemberStayCecValidator.CecDispositionResult> allErrors = new List<MemberStayCecValidator.CecDispositionResult>();

        if (requests == null || requests.isEmpty() || requests[0] == null) {
            return allErrors;
        }

        TransactionJournalRequest firstRequest = requests[0];

        // Step 0: Required fields check per TJ (mirrors what runValidations does via validateAllRequests).
        // Return early if fields are missing — business validators below are meaningless without them.
        try {
            MemberStayValidator.validateAllRequests(requests);
        } catch (MemberStayService.MemberStayException e) {
            MemberStayCecValidator.CecDispositionResult reqError = new MemberStayCecValidator.CecDispositionResult();
            reqError.statusCode = 406;
            reqError.errorCode = String.isNotBlank(e.errorCode) ? e.errorCode : '';
            reqError.message = String.isNotBlank(e.getMessage()) ? e.getMessage() : StayAndEarnApexConstants.VALIDATION_FAILED_MESSAGE;
            allErrors.add(reqError);
            return allErrors;
        }

        // Step 1: Run all standard validations WITHOUT duplicate check (same as non-CEC PUT behaviour)
        MemberStayValidator validator = new MemberStayValidator(loyaltyProgramName, firstRequest);
        validator.setLoyaltyProgramId(context.loyaltyProgramId);
        List<MemberStayValidator.ValidationResult> validationFailures =
            validator.collectAllValidationFailures(context.memberRecord, context.propertyRecord, false);

        for (MemberStayValidator.ValidationResult failure : validationFailures) {
            allErrors.add(toCecDispositionResult(failure));
        }

        // Step 2: CEC PUT-specific checks against the original stay
        if (context.originalStay != null) {
            // Cancelled stay cannot be modified (S114)
            if (StayAndEarnApexConstants.STAY_STATUS_CANCELLED.equals(context.originalStay.Stay_Status__c)) {
                allErrors.add(MemberStayCecValidator.createCecResultFromMapping(
                    StayAndEarnApexConstants.VALIDATION_STAY_NOT_EDITABLE, 406
                ));
            }
            // Stay checkout ≥ 18 months → 1003, HTTP 400 (matches old MemberStayCecValidator line 95)
            if (context.originalStay.Checkout_Date__c != null) {
                Integer stayAgeDays = context.originalStay.Checkout_Date__c.daysBetween(Date.today());
                if (stayAgeDays >= StayAndEarnApexConstants.STAY_AGE_18_MONTHS_DAYS) {
                    allErrors.add(MemberStayCecValidator.createCecResultFromMapping(
                        StayAndEarnApexConstants.VALIDATION_STAY_TOO_OLD_18M_MODIFY, 400
                    ));
                }
            }
            // CEC_MISSING_STAY origin must not be used for PUT (missing stay should use POST)
            if (StayAndEarnApexConstants.CEC_MISSING_STAY.equals(firstRequest.origin)) {
                allErrors.add(MemberStayCecValidator.createCecResultFromMapping(
                    StayAndEarnApexConstants.VALIDATION_STAY_NOT_EDITABLE, 406
                ));
            }
        }

        return allErrors;
    }

    /**
     * @description Converts a MemberStayValidator.ValidationResult failure to a
     *              MemberStayCecValidator.CecDispositionResult with HTTP 406 for CEC POST.
     *              Resolves the message from dispositionReason (setFromMapping path) or
     *              errorMessage (setNotFound path), whichever is populated.
     *
     * @param failure  A ValidationResult that represents a single validation failure
     * @return MemberStayCecValidator.CecDispositionResult populated result for the error response
     */
    private static MemberStayCecValidator.CecDispositionResult toCecDispositionResult(
        MemberStayValidator.ValidationResult failure
    ) {
        MemberStayCecValidator.CecDispositionResult cecResult = new MemberStayCecValidator.CecDispositionResult();
        // STAY_TOO_OLD_18M (1124) is an input-level constraint for CEC → HTTP 400, not 406.
        // All other business validation failures use 406.
        cecResult.statusCode = ERROR_CODE_STAY_TOO_OLD_18M.equals(failure.errorCode) ? 400 : 406;
        cecResult.errorCode = String.isNotBlank(failure.errorCode) ? failure.errorCode : '';
        // setFromMapping → dispositionReason; setNotFound → errorMessage
        String msg = String.isNotBlank(failure.dispositionReason) ? failure.dispositionReason : failure.errorMessage;
        cecResult.message = String.isNotBlank(msg) ? msg : StayAndEarnApexConstants.VALIDATION_FAILED_MESSAGE;
        return cecResult;
    }
}