/*******************************************************************************************
 * @Name         MemberStayService.cls
 * @Author       Praveen
 * @Date         05/01/2026
 * @Group        SF-Implementation
 * @Description  Service class for Member Stay API.
 *               Handles business logic for validating and creating Stay/TransactionJournal records.
 *               Assumes a SINGLE STAY per request - all TJs belong to that one stay.
 *               Stay-level data is extracted from the FIRST TransactionJournal in the request.
 *******************************************************************************************/
 /* MODIFICATION LOG
 * Version          Developer          Date               Description
 *-------------------------------------------------------------------------------------------
 *  1.0             Praveen           05/01/2026        Initial Creation for LYLT-7402
 *  2.0             Sai Vinay Thumu   11/02/2026        Added PUT method for stay adjustments (LYLT-367, LYLT-8556)
 *  3.0             Praveen           09/03/2026        LYLT-10400 - Stay Too High Dollar
 *******************************************************************************************/
@SuppressWarnings('PMD.CyclomaticComplexity')
public with sharing class MemberStayService {

    /******************************
     * Main Service Method
     ******************************/

    /**
     * @description Creates Stay and TransactionJournal records from request data.
     *              Assumes all TJs in the request belong to a SINGLE STAY.
     *              Stay-level data is extracted from the first TJ.
     * @param loyaltyProgramName - Name of the loyalty program
     * @param requests - List of TransactionJournalRequest objects (all for the same stay)
     * @return TransactionJournalResponse - Response containing created record IDs
     */
    public static TransactionJournalResponse createStayTransactions(
        String loyaltyProgramName,
        List<TransactionJournalRequest> requests
    ) {
        TransactionJournalRequest firstRequest = requests[0];
        String reqOrigin = (firstRequest != null) ? firstRequest.origin : null;
        Boolean isCec = MemberStayCecValidator.isCecRequest(reqOrigin);

        CommonContext commonContext = prepareCommonContext(loyaltyProgramName, firstRequest);

        // CEC POST: run ALL validations upfront, aggregate every failure, and return 406 without
        // creating any stay record. This replaces the old single-stop + separate 18M check pattern.
        // Under no circumstances will a CEC stay be created with a non-Posted-Eligible status.
        if (isCec) {
            List<MemberStayCecValidator.CecDispositionResult> allErrors = MemberStayCecPostValidator.collectAllErrors(
                loyaltyProgramName, commonContext.loyaltyProgramId,
                firstRequest, commonContext.memberRecord, commonContext.propertyRecord, requests
            );
            if (!allErrors.isEmpty()) {
                throwCecBulkException(allErrors);
            }
        }

        MemberStayValidator.ValidationResult validationResult = runValidations(
            requests, loyaltyProgramName, commonContext.loyaltyProgramId,
            firstRequest, commonContext.memberRecord, commonContext.propertyRecord, true, isCec
        );

        if (validationResult.isNotFound) {
            String errCode = String.isNotBlank(validationResult.errorCode) ? validationResult.errorCode : String.valueOf(ApexConstants.ErrorCode.INVALID_API_INPUT);
            String errMsg = String.isNotBlank(validationResult.errorMessage) ? validationResult.errorMessage : StayAndEarnApexConstants.VALIDATION_FAILED_MESSAGE;
            throw new MemberStayException(errMsg, errCode);
        }

        // Note: For POST method, non-CEC validation errors (like FUTURE_STAY, STAY_TOO_OLD, etc.)
        // still create Stay/TJ records with Suspended/Exception status — non-CEC behaviour is unchanged.
        // CEC requests reaching this point have already passed all validations and will produce
        // an In Progress stay that posts as Posted-Eligible via the program process.

        MemberStayMapper mapper = initializeMapper(
            commonContext.loyaltyProgramId, validationResult.memberRecord?.Id,
            validationResult.propertyRecord?.Id, requests
        );

        Savepoint sp = Database.setSavepoint();

        try {
            //LYLT-10400
            TransactionJournalResponse result = processStayAndTransactionJournalsRecords(validationResult, mapper, requests, sp);
            return result;
        } catch (Exception e) {
            Database.rollback(sp);
            if (!(e instanceof MemberStayService.MemberStayException) && 
                !(e instanceof MemberStayService.MemberStayNotFoundException)) {
                ExceptionLogger.logException(
                    e,
                    StayAndEarnApexConstants.PROCESS_NAME_MEMBER_STAY_SERVICE + '.createStayTransactions',
                    null,
                    ApexConstants.ERROR,
                    ApexConstants.ERROR,
                    JSON.serialize(new Map<String, Object>{'loyaltyProgramName' => loyaltyProgramName})
                );
            }
            throw e;
        }
    }

    /**
     * @description Creates Stay and TransactionJournal records, runs program process when applicable,
     *              stamps total eligible revenue, and returns the response.
     *              On the first call (sp != null), checks if revenue exceeds the property maximum;
     *              if so, rolls back and retries with REVENUE_TOO_LARGE disposition (LYLT-10400).
     * @param validationResult - Validation result from runValidations
     * @param mapper - MemberStayMapper instance
     * @param requests - List of TransactionJournalRequest objects (all for the same stay)
     * @param sp - Savepoint for rollback on revenue breach (null on retry)
     * @return TransactionJournalResponse - Response containing created record IDs
     */
    private static TransactionJournalResponse processStayAndTransactionJournalsRecords(
        MemberStayValidator.ValidationResult validationResult,
        MemberStayMapper mapper,
        List<TransactionJournalRequest> requests,
        Savepoint sp
    ) {
        List<Loyalty_Stay__c> stays = createStayRecord(
            new List<MemberStayValidator.ValidationResult>{ validationResult }, requests[0]
        );
        Loyalty_Stay__c stay = stays[0];

        CreateTransactionJournalsRequest tjRequest = new CreateTransactionJournalsRequest(
            mapper, requests, stay.Id, validationResult.transactionJournalStatus
        );
        List<TransactionJournal> journals = createTransactionJournals(tjRequest);

        if (validationResult.stayStatus == StayAndEarnApexConstants.STAY_STATUS_IN_PROGRESS) {
            runProgramProcess(journals);

            // LYLT-10400: calculate revenue, check against property max, rollback and retry if exceeded
            stay.Total_Eligible_Revenue__c = StayAggregationHelper.calculateRevenueBySourceCategory(stay, requests); //[LYLT-12396]
            if (sp != null && MemberStayValidator.checkRevenueExceedsMax(validationResult, stay)) {
                Database.rollback(sp);
                return processStayAndTransactionJournalsRecords(validationResult, mapper, requests, null);
            }

            String membershipNumber = validationResult.memberRecord?.MembershipNumber;
            publishStayProcessorEvent(stay, membershipNumber);
        } else {
            LoyaltyStayEventPublisher.publishEvents(new List<Loyalty_Stay__c>{stay});
        }

        Loyalty_Stay__c stayForResponse = MemberStayDataService.refreshStayForResponse(stay);
        return TransactionJournalResponse.fromRecords(stayForResponse, journals);
    }

    /******************************
     * Common Service Methods (Shared between POST and PUT)
     ******************************/

    /**
     * @description Common context for member stay operations
     *              Contains pre-queried records to avoid duplicate queries
     */
    public class CommonContext {
        public Id loyaltyProgramId { get; set; }
        public LoyaltyProgramMember memberRecord { get; set; }
        public Account propertyRecord { get; set; }
    }

    /**
     * @description Validates requests and queries common records (member, property, program)
     *              Shared logic used by both POST and PUT methods
     * @param loyaltyProgramName Name of the loyalty program
     * @param firstRequest First TransactionJournalRequest (for extracting member/property info)
     * @return CommonContext Context containing queried records
     */
    public static CommonContext prepareCommonContext(
        String loyaltyProgramName,
        TransactionJournalRequest firstRequest
    ) {
        CommonContext context = new CommonContext();
        context.loyaltyProgramId = LoyaltyIntegrationUtils.getLoyaltyProgramId(loyaltyProgramName);

        if (firstRequest != null && String.isNotBlank(firstRequest.membershipNumber)) {
            context.memberRecord = MemberStayDataService.findMemberWithTier(
                firstRequest.membershipNumber, context.loyaltyProgramId
            );
        }

        if (firstRequest != null && String.isNotBlank(firstRequest.establishment)) {
            context.propertyRecord = MemberStayDataService.findPropertyByCode(firstRequest.establishment);
        }

        return context;
    }

    /**
     * @description Runs validations (convenience overload without isCecPut; runs full validations including rate plan).
     */
    public static MemberStayValidator.ValidationResult runValidations(
        List<TransactionJournalRequest> requests,
        String loyaltyProgramName,
        Id loyaltyProgramId,
        TransactionJournalRequest firstRequest,
        LoyaltyProgramMember member,
        Account property,
        Boolean includeDuplicateCheck
    ) {
        return runValidations(requests, loyaltyProgramName, loyaltyProgramId, firstRequest, member, property, includeDuplicateCheck, false);
    }

    /**
     * @description Runs validations with pre-queried member and property.
     *              When isCecPut is true, skips rate plan exception validation.
     * @param isCecPut When true (CEC PUT), skips rate plan exception validation
     */
    public static MemberStayValidator.ValidationResult runValidations(
        List<TransactionJournalRequest> requests,
        String loyaltyProgramName,
        Id loyaltyProgramId,
        TransactionJournalRequest firstRequest,
        LoyaltyProgramMember member,
        Account property,
        Boolean includeDuplicateCheck,
        Boolean isCecPut
    ) {
        MemberStayValidator.validateAllRequests(requests);
        MemberStayValidator validator = new MemberStayValidator(loyaltyProgramName, firstRequest);
        validator.setLoyaltyProgramId(loyaltyProgramId);
        if (isCecPut) {
            validator.setSkipRatePlanForCec(true);
        }

        if (includeDuplicateCheck) {
            return validator.validate(member, property);
        } else {
            return validator.validateForAdjustment(member, property);
        }
    }

    /**
     * @description Initializes mapper with program ID and validated IDs
     *              Shared logic used by both POST and PUT methods
     * @param loyaltyProgramId Pre-queried program ID
     * @param memberId Member ID from validation result
     * @param propertyId Property ID from validation result
     * @param requests List of TransactionJournalRequest objects for preloading lookups
     * @return MemberStayMapper Initialized mapper
     */
    public static MemberStayMapper initializeMapper(
        Id loyaltyProgramId,
        Id memberId,
        Id propertyId,
        List<TransactionJournalRequest> requests
    ) {
        MemberStayMapper mapper = new MemberStayMapper(loyaltyProgramId);
        mapper.setMemberId(memberId);
        mapper.setPropertyId(propertyId);
        mapper.preloadLookups(requests);
        return mapper;
    }

    /******************************
     * Stay Record Creation
     ******************************/

    /**
     * @description Creates Loyalty_Stay__c records in bulk
     *              Creates one stay record for each validation result using the same request data
     * @param validationResults - List of validation results with status info
     * @param firstRequest - Request to extract stay-level fields (used for all stays)
     * @return List<Loyalty_Stay__c> - List of inserted Stay records
     * @throws MemberStayException if any stay creation fails
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static List<Loyalty_Stay__c> createStayRecord(
        List<MemberStayValidator.ValidationResult> validationResults,
        TransactionJournalRequest firstRequest
    ) {
        List<Loyalty_Stay__c> stays = new List<Loyalty_Stay__c>();
        for (MemberStayValidator.ValidationResult validationResult : validationResults) {
            Loyalty_Stay__c stay = buildStayRecord(validationResult, firstRequest);
            stay.Stay_Action_Type__c = StayAndEarnApexConstants.STAY_ACTION_ADD;
            stays.add(stay);
        }
        try {
            // Use 'as user' to respect field-level security and enforce CRUD permissions
            insert as user stays;
            return stays;
        } catch (DmlException e) {
            ExceptionLogger.logException(
                e,
                StayAndEarnApexConstants.PROCESS_NAME_MEMBER_STAY_SERVICE + '.' + StayAndEarnApexConstants.METHOD_NAME_CREATE_STAY_RECORD,
                null,
                ApexConstants.ERROR,
                ApexConstants.ERROR,
                JSON.serialize(stays)
            );
            throw new MemberStayException(
                StayAndEarnApexConstants.ERR_MSG_FAILED_CREATE_STAY_RECORD + e.getMessage(),
                StayAndEarnApexConstants.ERR_CODE_STAY_TRANSACTION_ERROR
            );
        }
    }

    /**
     * @description Builds a single Loyalty_Stay__c record from validation result and request
     * @param validationResult Validation result containing member, property, and status info
     * @param firstRequest First transaction journal request containing stay-level data
     * @return Loyalty_Stay__c configured stay record
     */
    public static Loyalty_Stay__c buildStayRecord(
        MemberStayValidator.ValidationResult validationResult,
        TransactionJournalRequest firstRequest
    ) {
        Loyalty_Stay__c stay = new Loyalty_Stay__c();
        setBasicStayFields(stay, validationResult, firstRequest);
        setMemberFields(stay, validationResult);
        setPropertyFields(stay, validationResult, firstRequest);
        setExtendedStayGroupingFields(stay, validationResult, firstRequest);
        return stay;
    }


    /**
     * @description Sets basic stay fields from request and validation result
     * @param stay Stay record to populate
     * @param validationResult Validation result
     * @param firstRequest First transaction journal request
     */
    private static void setBasicStayFields(
        Loyalty_Stay__c stay,
        MemberStayValidator.ValidationResult validationResult,
        TransactionJournalRequest firstRequest
    ) {
        if (firstRequest.startDate != null) {
            stay.Checkin_Date__c = firstRequest.startDate;
        }
        if (firstRequest.endDate != null) {
            stay.Checkout_Date__c = firstRequest.endDate;
        }

        stay.Reservation_Confirmation_Number__c = firstRequest.reservationConfirmationNumber;
        stay.Stay_Source__c = firstRequest.origin;
        stay.Stay_Source_Category__c = validationResult.staySourceCategory;
        stay.Stay_Status__c = validationResult.stayStatus;
        stay.Disposition_Error_Code__c = validationResult.errorCode;

        if (String.isNotBlank(validationResult.dispositionReason)) {
            stay.Stay_Disposition_Reason__c = validationResult.dispositionReason;
        }

        if (String.isNotBlank(validationResult.stayScenario)) {
            stay.Stay_Scenario__c = validationResult.stayScenario;
        }

        if (firstRequest.pmsSetupDate != null) {
            stay.PMS_Setup_Date__c = firstRequest.pmsSetupDate;
        }
        if (String.isNotBlank(firstRequest.paymentTypeIdentifier)) {
            stay.Payment_Type_Identifier__c = firstRequest.paymentTypeIdentifier;
        }
        // CEC audit persistence (LYLT-6928 AC5) - use JSON extraction for deployment compatibility when target org lacks TransactionJournalRequest.reasonCode
        String auditReason = getCecFieldFromRequest(firstRequest, 'reasonCode');
        String auditComment = getCecFieldFromRequest(firstRequest, 'stayComment');
        if (String.isNotBlank(auditReason)) {
            stay.Reason_Code__c = auditReason;
        }
        if (String.isNotBlank(auditComment)) {
            stay.Comment__c = auditComment;
        }
    }

    /**
     * @description Extracts CEC audit field from request via JSON to avoid compile dependency on TransactionJournalRequest.reasonCode/stayComment.
     * @param req TransactionJournalRequest
     * @param fieldName Property name (e.g. 'reasonCode', 'stayComment')
     * @return String Field value or null
     */
    private static String getCecFieldFromRequest(TransactionJournalRequest req, String fieldName) {
        if (req == null || String.isBlank(fieldName)) {
            return null;
        }
        try {
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(req));
            Object val = m.get(fieldName);
            return val != null ? String.valueOf(val) : null;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * @description Sets member-related fields on stay record
     * @param stay Stay record to populate
     * @param validationResult Validation result containing member info
     */
    private static void setMemberFields(
        Loyalty_Stay__c stay,
        MemberStayValidator.ValidationResult validationResult
    ) {
        if (validationResult.memberRecord == null) {
            return;
        }
        stay.Membership_Number__c = validationResult.memberRecord.Id;
        if (validationResult.memberRecord.Loyalty_Member_Tier != null && !validationResult.memberRecord.Loyalty_Member_Tier.isEmpty()
            && validationResult.memberRecord.Loyalty_Member_Tier[0].LoyaltyTier != null
            && validationResult.memberRecord.Loyalty_Member_Tier[0].LoyaltyTier.Id != null) {
            stay.Loyalty_Tier__c = validationResult.memberRecord.Loyalty_Member_Tier[0].LoyaltyTier.Id;
        }
        if (String.isNotBlank(validationResult.memberRecord.EarningPrefCode__c)) {
            stay.Earning_Preference__c = validationResult.memberRecord.EarningPrefCode__c;
        }
    }

    /**
     * @description Sets property-related fields on stay record
     * @param stay Stay record to populate
     * @param validationResult Validation result containing property info
     * @param firstRequest First transaction journal request (for fallback establishment code)
     */
    private static void setPropertyFields(
        Loyalty_Stay__c stay,
        MemberStayValidator.ValidationResult validationResult,
        TransactionJournalRequest firstRequest
    ) {
        // Prefer property code from validated property record
        if (validationResult.propertyRecord != null && String.isNotBlank(validationResult.propertyRecord.PropertyCode__c)) {
            stay.Property_Code__c = validationResult.propertyRecord.PropertyCode__c;
            return;
        }

        // Fallback: Use establishment code from request if property validation failed or propertyRecord is null
        // This ensures Property_Code__c is always set even when property validation fails
        if (firstRequest != null && String.isNotBlank(firstRequest.establishment)) {
            stay.Property_Code__c = firstRequest.establishment;
        }
    }


    /**
     * @description Sets Extended Stay grouping fields on stay record (LYLT-13089).
     *              Populates Extended_Stay_Group_Key__c and Parent_Extended_Stay__c for
     *              INTERIM / FINAL Connected PMS intervals before insert, so no extra DML is needed.
     *
     *              Group key format: {ConfirmationNumber}_{PropertyCode}_{MembershipNumber}
     *              Anchor logic:
     *               - No prior stays with this key → current stay is anchor (Parent = null)
     *               - Prior stays exist → earliest CreatedDate stay is anchor; Parent = anchor.Id
     *
     *              Skipped entirely for: NORMAL settlement, non-Connected PMS source,
     *              redemption stays, and any blank key component.
     *              Must be called after setPropertyFields so stay.Property_Code__c is already set.
     *
     * @param stay Stay record to populate
     * @param validationResult Validation result containing staySourceCategory and memberRecord
     * @param firstRequest First transaction journal request (settlement, confirmation, visitType)
     */
    private static void setExtendedStayGroupingFields(
        Loyalty_Stay__c stay,
        MemberStayValidator.ValidationResult validationResult,
        TransactionJournalRequest firstRequest
    ) {
        String settlement = firstRequest?.settlement;
        if (!(StayAndEarnApexConstants.SETTLEMENT_INTERIM.equals(settlement)
           || StayAndEarnApexConstants.SETTLEMENT_FINAL.equals(settlement))) {
            return;
        }

        String confirmationNumber = firstRequest?.reservationConfirmationNumber;
        if (String.isBlank(confirmationNumber)) {
            return;
        }

        String groupKey = confirmationNumber +
                          StayAndEarnApexConstants.EXTENDED_STAY_GROUP_KEY_SEPARATOR +
                          stay.Property_Code__c +
                          StayAndEarnApexConstants.EXTENDED_STAY_GROUP_KEY_SEPARATOR +
                          validationResult.memberRecord?.MembershipNumber;

        stay.Extended_Stay_Group_Key__c = groupKey;

        List<Loyalty_Stay__c> priorStays = MemberStayDataService.findByGroupKey(groupKey);
        if (!priorStays.isEmpty()) {
            stay.Stay_Scenario__c = priorStays[0].Stay_Scenario__c;
            stay.Parent_Extended_Stay__c = priorStays[0].Id;
        }
    }

    /******************************
     * TransactionJournal Creation
     ******************************/

    /**
     * @description Creates TransactionJournal records linked to Stay
     * @param request CreateTransactionJournalsRequest DTO containing all parameters
     * @return List<TransactionJournal> - Inserted records
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static List<TransactionJournal> createTransactionJournals(CreateTransactionJournalsRequest request) {
        if (request == null || request.mapper == null || request.requests == null || request.stayId == null) {
            throw new MemberStayException(
                StayAndEarnApexConstants.ERR_MSG_FAILED_CREATE_TJ_RECORDS + 'Invalid request parameters',
                StayAndEarnApexConstants.ERR_CODE_STAY_TRANSACTION_ERROR
            );
        }
        MemberStayMapper mapper = request.mapper;
        List<TransactionJournalRequest> requests = request.requests;
        List<TransactionJournal> journals = mapper.mapToTransactionJournals(requests, request.stayId, request.tjStatus);
        try {
            // Use 'as user' to respect field-level security and enforce CRUD permissions
            insert as user journals;
            return journals;
        } catch (DmlException e) {
            ExceptionLogger.logException(
                e,
                StayAndEarnApexConstants.PROCESS_NAME_MEMBER_STAY_SERVICE + '.' + StayAndEarnApexConstants.METHOD_NAME_CREATE_TRANSACTION_JOURNALS,
                null,
                ApexConstants.ERROR,
                ApexConstants.ERROR,
                JSON.serialize(journals)
            );
            throw new MemberStayException(
                StayAndEarnApexConstants.ERR_MSG_FAILED_CREATE_TJ_RECORDS + e.getMessage(),
                StayAndEarnApexConstants.ERR_CODE_STAY_TRANSACTION_ERROR
            );
        }
    }


    /******************************
     * Program Process Execution
     ******************************/

    /**
     * @description Runs Program Process for created TransactionJournal records
     *              Only called when all validations pass and status is In Progress
     *              Throws exception on failure to trigger rollback
     * @param journals - Created TransactionJournal records
     * @throws MemberStayException if program process fails
     */
    public static void runProgramProcess(List<TransactionJournal> journals) {
        if (journals == null || journals.isEmpty()) {
            return;
        }

        List<Map<String, String>> inputs = new List<Map<String, String>>();
        for (TransactionJournal tj : journals) {
            inputs.add(new Map<String, String>{StayAndEarnApexConstants.INVOCABLE_ACTION_INPUT_TJ_ID => tj.Id});
        }

        try {
            LoyaltyIntegrationUtils.invokeInvocableActionWithValidation(
                StayAndEarnApexConstants.INVOCABLE_ACTION_RUN_PROGRAM,
                inputs
            );
        } catch (LoyaltyIntegrationUtils.InvocableActionException e) {
            ExceptionLogger.logException(
                new MemberStayException(e.getMessage(), e.errorCode),
                StayAndEarnApexConstants.PROCESS_NAME_MEMBER_STAY_SERVICE + '.' + StayAndEarnApexConstants.METHOD_NAME_RUN_PROGRAM_PROCESS,
                null,
                ApexConstants.ERROR,
                ApexConstants.ERROR,
                e.getMessage()
            );
            throw new MemberStayException(e.getMessage(), e.errorCode);
        }
    }

    /******************************
     * Event Publishing
     ******************************/

    /**
     * @description Publishes Stay Processor Platform Event (overload for backward compatibility)
     * @deprecated Use publishStayProcessorEvent(Loyalty_Stay__c stay, String membershipNumber) instead.
     *             This method is kept for backward compatibility only. The journals parameter is not used.
     * @param stay - Created Stay record
     * @param journals - Created TransactionJournal records (not used, kept for backward compatibility)
     */
    public static void publishStayProcessorEvent(Loyalty_Stay__c stay, List<TransactionJournal> journals) {
        publishStayProcessorEvent(stay, (String)null);
    }

    /**
     * @description Publishes Stay Processor Platform Event with optional membership number
     * @param stay - Created Stay record
     * @param membershipNumber - Optional membership number (if provided, avoids relationship query)
     */
    public static void publishStayProcessorEvent(Loyalty_Stay__c stay, String membershipNumber) {
        if (stay == null || stay.Id == null) {
            return;
        }

        List<Stay_Processor_Event__e> events = createStayProcessorEvents(stay, membershipNumber);
        List<Database.SaveResult> results = EventBus.publish(events);
        ExceptionLogger.logSaveResultsException(
            results,
            StayAndEarnApexConstants.PROCESS_NAME_MEMBER_STAY_SERVICE + '.' + StayAndEarnApexConstants.METHOD_NAME_PUBLISH_STAY_PROCESSOR_EVENT,
            null);
    }

    /**********************************************************************************
     * @description Private helper to construct Stay Processor events
     * @param stay Loyalty_Stay__c record
     * @param membershipNumber Optional membership number (if provided, avoids relationship query)
     * @return List<Stay_Processor_Event__e>
     *********************************************************************************/
    private static List<Stay_Processor_Event__e> createStayProcessorEvents(Loyalty_Stay__c stay, String membershipNumber) {
        String membershipNum = String.isNotBlank(membershipNumber) 
            ? membershipNumber 
            : stay?.Membership_Number__r?.MembershipNumber;

        return new List<Stay_Processor_Event__e>{
            new Stay_Processor_Event__e(
                Membership_Number__c = membershipNum,
                Stay_Id__c = stay.Id
            )
        };
    }


    /******************************
     * Custom Exception Classes
     ******************************/

    /**
     * @description Custom exception for Member Stay API errors
     */
    public class MemberStayException extends Exception {
        /**
         * @description Error code associated with the exception
         */
        public String errorCode { get; private set; }

        /**
         * @description Constructor for MemberStayException
         * @param message Error message
         * @param code Error code
         */
        public MemberStayException(String message, String code) {
            this(message);
            this.errorCode = code;
        }
    }

    /**
     * @description Custom exception for 404 Not Found errors
     */
    public class MemberStayNotFoundException extends Exception {
        /**
         * @description Error code associated with the exception
         */
        public String errorCode { get; private set; }

        /**
         * @description Constructor for MemberStayNotFoundException
         * @param message Error message
         * @param code Error code
         */
        public MemberStayNotFoundException(String message, String code) {
            this(message);
            this.errorCode = code;
        }
    }

    /**
     * @description Throws MemberStayCecException with error code and message from StayValidationCodeDispositionMapping.
     *              Centralized for CEC DELETE and PUT validations.
     * @param validationCode DeveloperName from StayValidationCodeDispositionMapping__mdt
     * @param statusCode HTTP status code (404, 406, 409, 422, etc.)
     */
    public static void throwCecException(String validationCode, Integer statusCode) {
        StayValidationCodeDispositionMapping__mdt mapping = StayValidationCodeDispositionMapping__mdt.getInstance(validationCode);
        String errorCode = mapping != null ? mapping.Error_Code__c : validationCode;
        String message = mapping != null ? mapping.Disposition_Reason__c : StayAndEarnApexConstants.VALIDATION_FAILED_MESSAGE;
        throw new MemberStayCecException(message, statusCode, errorCode);
    }

    /**
     * @description Custom exception for CEC GET/DELETE Stay API. Carries HTTP status and error from metadata.
     */
    public class MemberStayCecException extends Exception {
        public Integer statusCode { get; private set; }
        public String errorCode { get; private set; }

        public MemberStayCecException(String message, Integer statusCode, String errorCode) {
            this(message);
            this.statusCode = statusCode;
            this.errorCode = errorCode;
        }
    }

    /**
     * @description Throws MemberStayCecBulkException with collected validation errors (LYLT-12591 AC3).
     *              Status code = highest precedence: 404 > 406 > 409 > 400 > 422.
     */
    public static void throwCecBulkException(List<MemberStayCecValidator.CecDispositionResult> results) {
        Boolean has404 = false;
        Boolean has406 = false;
        Boolean has409 = false;
        Boolean has400 = false;
        for (MemberStayCecValidator.CecDispositionResult r : results) {
            if (r.statusCode == 404) {
                has404 = true;
            } else if (r.statusCode == 406) {
                has406 = true;
            } else if (r.statusCode == 409) {
                has409 = true;
            } else if (r.statusCode == 400) {
                has400 = true;
            }
        }
        Integer statusCode = 422;
        if (has404) {
            statusCode = 404;
        } else if (has406) {
            statusCode = 406;
        } else if (has409) {
            statusCode = 409;
        } else if (has400) {
            statusCode = 400;
        }
        throw new MemberStayCecValidator.MemberStayCecBulkException(results, statusCode);
    }

    /**
     * @description DTO for createTransactionJournals method parameters
     */
    public class CreateTransactionJournalsRequest {
        /**
         * @description Mapper instance for converting requests to TransactionJournal records
         */
        public MemberStayMapper mapper;
        /**
         * @description List of TransactionJournalRequest objects to process
         */
        public List<TransactionJournalRequest> requests;
        /**
         * @description ID of the Loyalty_Stay__c record to link TransactionJournals to
         */
        public Id stayId;
        /**
         * @description Status to set on created TransactionJournal records
         */
        public String tjStatus;

        /**
         * @description Constructor for CreateTransactionJournalsRequest
         * @param mapper Mapper instance
         * @param requests List of transaction journal requests
         * @param stayId Stay ID
         * @param tjStatus Transaction journal status
         */
        public CreateTransactionJournalsRequest(MemberStayMapper mapper, List<TransactionJournalRequest> requests,
                                                Id stayId, String tjStatus) {
            this.mapper = mapper;
            this.requests = requests;
            this.stayId = stayId;
            this.tjStatus = tjStatus;
        }
    }
}