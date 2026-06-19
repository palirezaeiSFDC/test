/*******************************************************************************************
 * @Name         StayAndEarnApexConstants.cls
 * @Author       Salesforce
 * @Date         16/01/2026
 * @Group        SF-Implementation
 * @Description  Constants dedicated to Stay & Earn (S&E) flows.
 *               Use ApexConstants only for generic/shared values (true/false, etc.).
 *               All S&E services, post processors, and events should reference this class.
 *******************************************************************************************/
public class StayAndEarnApexConstants {

   /******************************
    * Common
    ******************************/
    public static final String ERROR = 'ERROR';

   /******************************
    * Member Stay API Error Codes (String values for response)
    ******************************/
    public static final String ERR_CODE_JSON_PARSER_ERROR = 'JSON_PARSER_ERROR';
    public static final String ERR_CODE_INVALID_API_INPUT = 'INVALID_API_INPUT';
    public static final String ERR_CODE_INTERNAL_SERVER_ERROR = 'INTERNAL_SERVER_ERROR';
    public static final String ERR_CODE_STAY_TRANSACTION_ERROR = 'STAY_TRANSACTION_ERROR';
    public static final String ERR_CODE_PROGRAM_PROCESS_ERROR = 'PROGRAM_PROCESS_ERROR';

    /******************************
    * Member Stay API Error Messages
    ******************************/
    public static final String ERR_MSG_EMPTY_OR_MALFORMED_JSON = 'The request body cannot be empty or the JSON is malformed.';
    public static final String ERR_MSG_INVALID_LOYALTY_PROGRAM = 'Specify a valid loyalty program name and try again';
    public static final String ERR_MSG_JSON_PARSER_ERROR = 'Invalid JSON format: ';
    public static final String ERR_MSG_REQUEST_BODY_EMPTY = 'Request body cannot be empty. At least one transaction is required.';
    public static final String ERR_MSG_PROGRAM_PROCESS_FAILED = 'Program process failed: ';
    public static final String ERR_MSG_INVALID_INPUT_VALIDATION_RESULTS = 'Invalid input: validationResults must be non-empty and firstRequest must not be null';
    public static final String ERR_MSG_FAILED_CREATE_STAY_RECORD = 'Failed to create Stay record: ';
    public static final String ERR_MSG_FAILED_CREATE_TJ_RECORDS = 'Failed to create TransactionJournal records: ';
    public static final String ERR_MSG_FAILED_PUBLISH_STAY_EVENT = 'Failed to publish Stay Processor Event for Stay: ';
    public static final String ERR_MSG_TRANSACTION_MISSING_FIELDS_PREFIX = 'Transaction[';
    public static final String ERR_MSG_TRANSACTION_MISSING_FIELDS_SUFFIX = ']: Missing required fields - ';

    /******************************
    * Member Stay API Process Names
    ******************************/
    public static final String PROCESS_NAME_MEMBER_STAY_API = 'MemberStayApi';
    public static final String PROCESS_NAME_MEMBER_STAY_SERVICE = 'MemberStayService';
    public static final String METHOD_NAME_CREATE_STAY_RECORD = 'createStayRecord';
    public static final String METHOD_NAME_CREATE_TRANSACTION_JOURNALS = 'createTransactionJournals';
    public static final String METHOD_NAME_RUN_PROGRAM_PROCESS = 'runProgramProcess';
    public static final String METHOD_NAME_PUBLISH_STAY_PROCESSOR_EVENT = 'publishStayProcessorEvent';
    public static final String METHOD_NAME_CALCULATE_AND_STAMP_TOTAL_ELIGIBLE_REVENUE = 'calculateAndStampTotalEligibleRevenue';
    public static final String ERR_MSG_FAILED_UPDATE_TOTAL_ELIGIBLE_REVENUE = 'Failed to update Total_Eligible_Revenue__c';

    /******************************
    * Member Stay API Invocable Actions
    ******************************/
    public static final String INVOCABLE_ACTION_RUN_PROGRAM = 'runProgramProcessForTransactionJournal';
    public static final String INVOCABLE_ACTION_INPUT_TJ_ID = 'transactionJournalId';
    public static final String INVOCABLE_ACTION_CANCEL_ACCRUAL = 'cancelAccrual';

    /******************************
    * Invocable Action Parameter Names
    ******************************/
    public static final String INVOCABLE_PARAM_TRANSACTION_JOURNAL_ID = 'transactionJournalId';
    /** cancelAccrual action expects journalId (not transactionJournalId) */
    public static final String INVOCABLE_PARAM_CANCEL_ACCRUAL_JOURNAL_ID = 'journalId';
    public static final String INVOCABLE_PARAM_CANCELLATION_REASON = 'cancellationReason';
    public static final String INVOCABLE_PARAM_CANCELLATION_TJ_ID = 'cancellationTransactionJournalId';

    /******************************
    * Transaction Journal Status Values
    ******************************/
    public static final String TJ_STATUS_PENDING = 'Pending';
    public static final String TJ_STATUS_PROCESSED = 'Processed';
    public static final String TJ_STATUS_ERROR = 'Error';
    public static final String TJ_STATUS_APPROVED = 'Approved';
    public static final String TJ_STATUS_CANCELLED = 'Cancelled';

    /******************************
    * Transaction Journal Reason Values
    ******************************/
    public static final String JOURNAL_REASON_STAY_ADJUSTED = 'Stay Adjusted';

    /******************************
    * Transaction Journal Type Names
    ******************************/
    public static final String JOURNAL_TYPE_ACCRUAL_REVERSAL = 'Accrual Reversal';

    /******************************
     * Stay Status Values
     ******************************/
    public static final String STAY_STATUS_IN_PROGRESS = 'In Progress';
    public static final String STAY_STATUS_CANCELLED = 'Cancelled';
    public static final String STAY_STATUS_SUSPENDED = 'Suspended';
    public static final String STAY_STATUS_EXCEPTION = 'Exception Handling';

    /******************************
    * Member Status Values
    ******************************/
    public static final String MEMBER_STATUS_DECEASED = '24';
    public static final String MEMBER_STATUS_STOPPED_BY_MARRIOTT = '25';
    public static final String MEMBER_STATUS_STOPPED_BY_CUSTOMER = '26';

    /******************************
    * Stay Source Category Values
    ******************************/
    public static final String STAY_SOURCE_CONNECTED_PMS = 'Connected PMS';
    public static final String STAY_SOURCE_STAY_FILE = 'Stay File';
    public static final String STAY_SOURCE_NON_CONNECTED_GXP = 'Non Connected GXP';
    public static final String STAY_SOURCE_CATEGORY_EMPOWER_CEC = 'Empower CEC';

    /******************************
    * Stay Action Type (HTTP method → stay record)
    ******************************/
    public static final String STAY_ACTION_ADD = 'Add';
    public static final String STAY_ACTION_MODIFY = 'Modify';
    public static final String STAY_ACTION_DELETE = 'Delete';

    /******************************
    * HTTP Method Names (for routing and operation type)
    ******************************/
    public static final String HTTP_METHOD_GET = 'GET';
    public static final String HTTP_METHOD_POST = 'POST';
    public static final String HTTP_METHOD_PUT = 'PUT';
    public static final String HTTP_METHOD_DELETE = 'DELETE';
    public static final String HTTP_METHOD_PATCH = 'PATCH';

    /******************************
    * Validation Error Fallbacks
    ******************************/
    public static final String VALIDATION_ERROR_CODE = 'VALIDATION_ERROR';
    public static final String VALIDATION_FAILED_MESSAGE = 'Validation failed';

    /******************************
    * CEC Disposition Error Codes (API response codes)
    ******************************/
    public static final String CEC_ERROR_S114 = 'S114';
    public static final String CEC_ERROR_S115 = 'S115';
    public static final String CEC_ERROR_5004 = '5004';
    public static final String CEC_ERROR_1003 = '1003';
    public static final String CEC_ERROR_1119 = '1119';

    /******************************
    * CEC Disposition Messages (fallback when metadata unavailable)
    ******************************/
    public static final String CEC_MSG_CANNOT_DELETE_ALREADY = 'Stay has already been deleted – cannot delete';
    public static final String CEC_MSG_CANNOT_MODIFY_ALREADY_DELETED = 'Stay cannot be modified since it has already been deleted';
    public static final String CEC_MSG_STAY_NOT_FOUND = 'Stay details not found';
    public static final String CEC_MSG_STAY_TOO_OLD_18M = 'Stay is older than 18 months – cannot modify';
    public static final String CEC_MSG_STAY_TOO_OLD_18M_DELETE = 'Stay is older than 18 months – cannot delete';

    /******************************
    * HTTP Status Codes (string form for responses)
    ******************************/
    public static final String HTTP_STATUS_200 = '200';
    public static final String HTTP_STATUS_201 = '201';

    /******************************
    * HTTP Status Codes (integer for RestResponse.statusCode)
    ******************************/
    public static final Integer HTTP_STATUS_CODE_200 = 200;
    public static final Integer HTTP_STATUS_CODE_201 = 201;

    /******************************
    * Stay Delete Response Keys and Messages
    ******************************/
    public static final String RESPONSE_KEY_STATUS_CODE = 'statusCode';
    public static final String RESPONSE_KEY_MESSAGE = 'message';
    public static final String RESPONSE_KEY_STAY_ID = 'stayId';
    public static final String RESPONSE_KEY_STAY_NAME = 'stayName';
    public static final String MSG_STAY_DELETED_SUCCESS = 'Stay deleted successfully';

    /******************************
    * Stay Adjustment Response Messages
    ******************************/
    public static final String MSG_ADJUSTMENT_SUCCESS = 'Adjustment request processed successfully. Old Stay is Cancelled and a new Stay record is created.';
    public static final String MSG_ADJUSTMENT_NO_CHANGE = 'Adjustment request is ignored as the total eligible revenue or spend is unchanged for the stay.';

    /******************************
    * CEC Modify Stay Validation
    ******************************/
    public static final String ERR_MSG_STAY_ID_REQUIRED_CEC = 'stayId is required for CEC Modify Stay requests';

    /******************************
    * URI and Log Constants
    ******************************/
    public static final String URI_PATTERN_EARN_SF_STAY = '/earn/sf-stay/';
    public static final String UNKNOWN_URI = 'Unknown';
    public static final String LOG_LEVEL_WARNING = 'WARNING';
    public static final String PROCESS_NAME_MEMBER_STAY_API_HANDLE = 'MemberStayApi.handleRequest';
    public static final String PROCESS_NAME_MEMBER_STAY_API_EXTRACT = 'MemberStayApi.extractStayIdFromUri';
    public static final String LOG_CONTEXT_KEY_METHOD = 'method';
    public static final String LOG_CONTEXT_KEY_URI = 'uri';
    public static final String LOG_MSG_URL_DECODE_STAY_ID_PREFIX = 'Original stayId: ';
    public static final String LOG_MSG_URL_DECODE_STAY_ID_SUFFIX = '; URI: ';
    public static final String PROCESS_NAME_STAY_ADJUSTMENT_SERVICE_PROCESS = 'StayAdjustmentService.processStayAdjustment';
    public static final String PROCESS_NAME_STAY_ADJUSTMENT_SERVICE_FIND = 'StayAdjustmentService.findOriginalStayWithContext';
    public static final String PROCESS_NAME_STAY_ADJUSTMENT_ORCHESTRATOR_CHECK = 'StayAdjustmentOrchestrator.checkRevenueAndUpdateStays';
    public static final String PROCESS_NAME_STAY_ADJUSTMENT_ORCHESTRATOR_CREATE = 'StayAdjustmentOrchestrator.createAdjustmentStayRecord';
    public static final String PROCESS_NAME_STAY_ADJUSTMENT_ORCHESTRATOR_FAILED = 'StayAdjustmentOrchestrator.processFailedAdjustment';

    /******************************
    * Stay Adjustment Error Messages
    ******************************/
    public static final String ERR_MSG_FAILED_UPDATE_OLD_NEW_STAY = 'Failed to update old and new stay records';
    public static final String ERR_MSG_FAILED_UPDATE_STAY_RECORDS_PREFIX = 'Failed to update stay records: ';
    public static final String ERR_MSG_INVALID_STAY_ID_FORMAT = 'Invalid stayId format: ';

    /******************************
    * CEC Stay Source Values (Empower CEC Modify Stay)
    ******************************/
    public static final String CEC_MODIFY_STAY = 'CEC_MODIFY_STAY';
    public static final String CEC_MISSING_STAY = 'CEC_MISSING_STAY';

    /******************************
    * Stay Age Constants (in days)
    ******************************/
    public static final Integer STAY_AGE_24_MONTHS_DAYS = 730;
    public static final Integer STAY_AGE_18_MONTHS_DAYS = 548;

    /******************************
    * Stay Post Processing
    ******************************/
    public static final String PROCESS_NAME_STAY_POST_PROCESSING = 'StayPostProcessing';
    public static final String CURRENCY_ELITE_QUALIFYING_NIGHTS = 'Elite Qualifying Nights';
    public static final String CURRENCY_POINTS = 'Points';
    public static final String CURRENCY_SPEND = 'Spend';
    public static final String STAY_STATUS_POSTED = 'Posted - Eligible';
    public static final String STAY_STATUS_POSTED_INELIGIBLE = 'Posted - Ineligible';
    public static final String EARN = 'Earn';
    public static final String STAY_POST_PROCESSING = 'StayPostProcessing';


    /******************************
    * Stay Scenario Values
    ******************************/
    public static final String STAY_SCENARIO_HOST_MULTIPLE = 'Host Multiple';
    public static final String STAY_SCENARIO_BACK_TO_BACK = 'Back To Back';
    public static final Integer HOST_MULTIPLE_MAX_ROOM_COUNT = 2;

    /******************************
    * Extended Stay Constants (LYLT-2868)
    ******************************/
    /** Extended Stay = reservation in-house for 5 or more nights. B2B and Host Multiple can occur in Extended Stay. */
    public static final Integer EXTENDED_STAY_MIN_NIGHTS = 5;

    /******************************
    * Settlement Indicator Values (Extended Stay - ACRS Connected PMS)
    * Only present in payload for Extended Stays. Mapped to TJ.Settlement__c for loyalty process.
    ******************************/
    public static final String SETTLEMENT_NORMAL = 'NORMAL';
    public static final String SETTLEMENT_INTERIM = 'INTERIM';
    public static final String SETTLEMENT_FINAL = 'FINAL';

    /******************************
    * Extended Stay Grouping (LYLT-13089)
    * Group Key format: {ConfirmationNumber}_{PropertyCode}_{MembershipNumber}
    ******************************/
    public static final String EXTENDED_STAY_GROUP_KEY_SEPARATOR = '_';
    
    /******************************
    * Member Stay Validation Codes (DeveloperName for StayValidationCodeDispositionMapping__mdt)
    ******************************/
    // Member-level
    public static final String VALIDATION_ACCT_NOT_FOUND = 'ACCT_NOT_FOUND';
    public static final String VALIDATION_ACCT_DECEASED = 'ACCT_DECEASED';
    public static final String VALIDATION_ACCT_STOP_CUST = 'ACCT_STOP_CUST';
    public static final String VALIDATION_ACCT_STOP_MARR = 'ACCT_STOP_MARR';
    // Stay Date & Age
    public static final String VALIDATION_INVALID_DATE_RANGE = 'INVALID_DATE_RANGE';
    public static final String VALIDATION_FUTURE_STAY_STAY_FILE_CHECK_OUT = 'FUTURE_STAY_STAY_FILE_CHECK_OUT';
    public static final String VALIDATION_FUTURE_STAY_CONNECTED_PMS_CHECK_OUT = 'FUTURE_STAY_CONNECTED_PMS_CHECK_OUT';
    public static final String VALIDATION_FUTURE_STAY_STAY_FILE_CHECK_IN = 'FUTURE_STAY_STAY_FILE_CHECK_IN';
    public static final String VALIDATION_FUTURE_STAY_CONNECTED_PMS_CHECK_IN = 'FUTURE_STAY_CONNECTED_PMS_CHECK_IN';
    public static final String VALIDATION_STAY_TOO_OLD_24M = 'STAY_TOO_OLD_24M';
    public static final String VALIDATION_STAY_TOO_OLD_18M = 'STAY_TOO_OLD_18M';
    public static final String VALIDATION_STAY_TOO_OLD_18M_MODIFY = 'STAY_TOO_OLD_18M_MODIFY';
    public static final String VALIDATION_STAY_TOO_OLD_18M_DELETE = 'STAY_TOO_OLD_18M_DELETE';
    // Property-level
    public static final String VALIDATION_PROP_CODE_EMPTY = 'PROP_CODE_EMPTY';
    public static final String VALIDATION_PROP_NOT_FOUND = 'PROP_NOT_FOUND';
    public static final String VALIDATION_PROP_NOT_OPEN = 'PROP_NOT_OPEN';
    public static final String VALIDATION_PROP_NON_PARTICIPATING = 'PROP_NON_PARTICIPATING';
    public static final String VALIDATION_BRAND_NON_PARTICIPATING = 'BRAND_NON_PARTICIPATING';
    public static final String VALIDATION_INCIDENTAL_NO_EARN = 'INCIDENTAL_NO_EARN';
    // Duplicate/Overlap
    public static final String VALIDATION_DUPLICATE_STAY = 'DUPLICATE_STAY';
    public static final String VALIDATION_OVERLAPPING_STAY = 'OVERLAPPING_STAY';
    public static final String VALIDATION_MULTI_ROOM_EXCEEDED = 'MULTI_ROOM_EXCEEDED';
    public static final String VALIDATION_PPM_NOT_FOUND = 'PPM_NOT_FOUND';
    public static final String REVENUE_TOO_LARGE = 'REVENUE_TOO_LARGE';
    /** CEC validation codes (GET/DELETE by stayId) */
    public static final String VALIDATION_STAY_NOT_FOUND = 'STAY_NOT_FOUND';
    public static final String VALIDATION_CANNOT_DELETE_STAY = 'CANNOT_DELETE_STAY';
    public static final String VALIDATION_STAY_NOT_EDITABLE = 'STAY_NOT_EDITABLE';
    /** S117: Posted Ineligible stay no longer in that status (concurrent modification) - maps to PREVIOUSLY_RESURRECTED_STAY */
    public static final String VALIDATION_PREVIOUSLY_RESURRECTED_STAY = 'PREVIOUSLY_RESURRECTED_STAY';
    /** @deprecated Use VALIDATION_PREVIOUSLY_RESURRECTED_STAY */
    public static final String VALIDATION_STAY_ALREADY_MODIFIED = 'PREVIOUSLY_RESURRECTED_STAY';
    /** S118: Suspended/Exception stay no longer in that status (concurrent modification) - maps to PREVIOUSLY_CORRECTED_STAY */
    public static final String VALIDATION_PREVIOUSLY_CORRECTED_STAY = 'PREVIOUSLY_CORRECTED_STAY';
    /** @deprecated Use VALIDATION_PREVIOUSLY_CORRECTED_STAY */
    public static final String VALIDATION_STAY_ALREADY_RESTRICTED = 'PREVIOUSLY_CORRECTED_STAY';
    /******************************
    * Member Stay API JSON Field Names (from API spec)
    ******************************/
    // Request wrapper key
    public static final String JSON_KEY_TRANSACTION_JOURNALS = 'transactionJournals';

    // Journal Type Fields
    public static final String JSON_KEY_JOURNAL_TYPE_NAME = 'JournalTypeName';
    public static final String JSON_KEY_JOURNAL_TYPE_ID = 'JournalTypeId';
    public static final String JSON_KEY_JOURNAL_SUBTYPE_NAME = 'JournalSubTypeName';
    public static final String JSON_KEY_JOURNAL_SUBTYPE_ID = 'JournalSubTypeId';

    // Member Identification
    public static final String JSON_KEY_MEMBERSHIP_NUMBER = 'MembershipNumber';
    public static final String JSON_KEY_MEMBER_ID = 'MemberId';

    // Product Identification
    public static final String JSON_KEY_PRODUCT_CODE = 'ProductCode';
    public static final String JSON_KEY_PRODUCT_ID = 'ProductId';

    // Property/Establishment
    public static final String JSON_KEY_ESTABLISHMENT = 'Establishment';

    // Transaction Details
    public static final String JSON_KEY_TRANSACTION_TYPE = 'Transaction_Type__c';
    public static final String JSON_KEY_CHANNEL = 'Channel';
    public static final String JSON_KEY_ORIGIN = 'Origin';
    public static final String JSON_KEY_STATUS = 'Status';
    public static final String JSON_KEY_EXTERNAL_TRANSACTION_NUMBER = 'ExternalTransactionNumber';
    public static final String JSON_KEY_CURRENCY_ISO_CODE = 'CurrencyIsoCode';

    // Date/Time Fields
    public static final String JSON_KEY_BOOKING_DATE = 'BookingDate';
    public static final String JSON_KEY_ACTIVITY_DATE = 'ActivityDate';
    public static final String JSON_KEY_START_DATE = 'StartDate';
    public static final String JSON_KEY_END_DATE = 'EndDate';
    

    public static final String JSON_KEY_PMS_SETUP_DATE = 'PMS_Setup_Date__c';
    
    // Amount Fields
    public static final String JSON_KEY_TRANSACTION_AMOUNT = 'TransactionAmount';
    public static final String JSON_KEY_FX_RATE = 'FX_Rate__c';
    public static final String JSON_KEY_USD_VALUE_CONVERTED = 'USD_Value_Converted__c';
    public static final String JSON_KEY_QUANTITY = 'Quantity';

    // Boolean Flags
    public static final String JSON_KEY_REDEMPTION_RATE_FLAG = 'Redemption_Rate_Flag__c';
    public static final String JSON_KEY_EARN_ELIGIBILITY = 'Earn_Eligibility__c';
    public static final String JSON_KEY_IS_NUA = 'Is_NUA__c';
    public static final String JSON_KEY_IS_PARENT_TRANSACTION = 'IsParentTransaction';

    // Reservation/Folio Details
    public static final String JSON_KEY_RESERVATION_CONFIRMATION_NUMBER = 'Reservation_Confirmation_Number__c';
    public static final String JSON_KEY_FOLIO_NUMBER = 'Folio_Number__c';
    public static final String JSON_KEY_BENEFITS = 'Benefits__c';
    public static final String JSON_KEY_RATE_CODE_PLAN = 'Rate_Plan_Code__c';
    public static final String JSON_KEY_GROUP_INDUSTRY = 'Group_Industry__c';
    public static final String JSON_KEY_SETTLEMENT = 'Settlement__c';

    //Required Fields (display names for validation error messages - matches API spec)
    public static final String JSON_REQUIRED_FIELDS = Label.MemberStayAPI_Required_Fields;
    public static final String REQ_FIELD_DISPLAY_MEMBERSHIP_NUMBER = 'MembershipNumber';
    public static final String REQ_FIELD_DISPLAY_ACTIVITY_DATE = 'ActivityDate';
    public static final String REQ_FIELD_DISPLAY_STATUS = 'Status';
    public static final String REQ_FIELD_DISPLAY_CURRENCY_ISO_CODE = 'CurrencyIsoCode';
    public static final String REQ_FIELD_DISPLAY_JOURNAL_TYPE_NAME = 'JournalTypeName';
    public static final String REQ_FIELD_DISPLAY_JOURNAL_SUBTYPE_NAME = 'JournalSubTypeName';
    public static final String REQ_FIELD_DISPLAY_ESTABLISHMENT = 'Establishment';
    public static final String REQ_FIELD_DISPLAY_PRODUCT_CODE = 'ProductCode';
    public static final String REQ_FIELD_DISPLAY_RATE_CODE_PLAN = 'Rate_Plan_Code__c';

    /******************************
    * Required Field Check Types (for getRequiredFieldRules validation)
    ******************************/
    public static final String CHECK_TYPE_STRING = 'STRING';
    public static final String CHECK_TYPE_DATETIME = 'DATETIME';
    public static final String CHECK_TYPE_STRING_UNLESS_PARENT = 'STRING_UNLESS_PARENT';

    /******************************
    * Required Field Rule Map Keys (for getRequiredFieldRules)
    ******************************/
    public static final String RULE_KEY_DISPLAY_NAME = 'displayName';
    public static final String RULE_KEY_FIELD_KEY = 'fieldKey';
    public static final String RULE_KEY_CHECK_TYPE = 'checkType';

    /******************************
    * Stay Adjustment API Response Field Names
    ******************************/
    public static final String RESPONSE_KEY_PROCESSING_STATUS = 'processingStatus';
    public static final String RESPONSE_KEY_CODE = 'Code';
    public static final String RESPONSE_KEY_DESCRIPTION = 'Description';
    public static final String RESPONSE_KEY_OLD_STAY = 'oldStay';
    public static final String RESPONSE_KEY_NEW_STAY = 'newStay';
    public static final String RESPONSE_KEY_STAY = 'Stay';
    public static final String RESPONSE_KEY_STAY_STATUS = 'Stay_Status__c';
    public static final String RESPONSE_KEY_TRANSACTION_JOURNALS = 'TransactionJournals';

    /******************************
    * PointsInput API Field Names
    ******************************/
    public static final String POINTS_INPUT_LOYALTY_PROGRAM_MEMBER_ID = 'loyaltyProgramMemberId';
    public static final String POINTS_INPUT_POINTS = 'points';
    public static final String POINTS_INPUT_PROGRAM_NAME = 'programName';
    public static final String POINTS_INPUT_PROGRAM_CURRENCY_NAME = 'programCurrencyName';
    public static final String POINTS_INPUT_JOURNAL_ID = 'journalId';

    /******************************
    * RecordType Names
    ******************************/
    public static final String RECORD_TYPE_PROPERTY = 'Property';

    /******************************
     * Error Messages
     ******************************/
    public static final String ERR_MSG_UNKNOWN_ERROR = 'Unknown error';
    public static final String ERR_MSG_ORIGINAL_STAY_NOT_FOUND = 'Original stay record not found for adjustment';
    public static final String ERR_MSG_REQUESTS_LIST_EMPTY = 'TransactionJournal requests list cannot be empty';
    public static final String ERR_MSG_NO_PROCESSED_TJS_FOR_CANCELLATION = 'No processed TransactionJournals found for cancellation';
    public static final String ERR_MSG_FAILED_CANCEL_ACCRUAL_ALL = 'Failed to cancel accrual for all TransactionJournals';
    public static final String ERR_MSG_FAILED_CANCEL_ACCRUAL_PREFIX = 'Failed to cancel accrual: ';
    public static final String ERR_MSG_INVALID_ADJUSTMENT_REQUEST = 'Invalid adjustment request - requests list cannot be empty';
    public static final String ERR_MSG_INVALID_CREATE_STAY_REQUEST = 'Invalid create stay request - required parameters cannot be null';
    public static final String ERR_MSG_FAILED_CREATE_STAY_NO_RECORDS = 'Failed to create stay record - no records returned';
    public static final String ERR_MSG_TJS_MUST_HAVE_STAY = 'TransactionJournals must have Loyalty_Stay__c populated for cancellation';
    public static final String ERR_MSG_TJS_MUST_HAVE_MEMBER = 'TransactionJournals must have MemberId populated for cancellation';

    /****************************
     * Unique Stay
     ***************************/
    public static final String JSON_KEY_VISIT_TYPE = 'Visit_Type__c';
    public static final String JSON_KEY_PROGRAM_OF_RECORD = 'Program_Of_Record__c';
    public static final String JSON_KEY_REASON_CODE = 'Reason_Code__c';
    public static final String JSON_KEY_STAY_COMMENT = 'Stay_Comment__c';
    public static final String JSON_KEY_COMMENT = 'Comment__c';
    public static final String JSON_KEY_ASSOCIATE_ID = 'Associate_Id__c';
    public static final String JSON_KEY_REDEMPTION_TRANSACTION_ID = 'Redemption_Transaction_Id__c';
    public static final String JSON_KEY_PAYMENT_TYPE_IDENTIFIER = 'Payment_Type_Identifier__c';

    /******************************
     * EQN Type Values 
     ******************************/
    public static final String EQN_TYPE_PAID = 'Paid';
    public static final String EQN_TYPE_REDEMPTION = 'Redemption';
    public static final String EQN_TYPE_POR = 'POR';

    /******************************
     * Visit Type Values 
     ******************************/
    public static final String VISIT_TYPE_PAID_STAY = 'PAID_STAY';
    public static final String VISIT_TYPE_PAID_DAY_USE_STAY = 'PAID_DAY_USE_STAY';
    public static final String VISIT_TYPE_PAID_GROUP_STAY = 'PAID_GROUP_STAY';
    public static final String VISIT_TYPE_REDEMPTION_STAY = 'REDEMPTION_STAY';
    public static final String VISIT_TYPE_REDEMPTION_DAY_USE_STAY = 'REDEMPTION_DAY_USE_STAY';

    /******************************
     * Program of Record Values
     ******************************/
    public static final String PROGRAM_OF_RECORD_DL = 'DELONIX';

    /******************************
     * Get Member Stay API Constants
     ******************************/
    public static final String PROCESS_NAME_GET_MEMBER_STAY_API = 'GetMemberStayAPI';
    public static final String PARAM_MEMBER_ID  = 'memberId';
    public static final String PARAM_START_DATE = 'startDate';
    public static final String PARAM_END_DATE   = 'endDate';
    public static final String URI_SEGMENT_STAYS = 'stays';

    // Error messages used by Get Member Stay API request validation
    public static final String ERR_MSG_MISSING_MEMBER_ID = 'Member ID is required and cannot be blank.';
    public static final String ERR_MSG_MEMBER_STAY_NOT_FOUND = 'No stay records found for the given member ID.';
    public static final String ERR_MSG_INVALID_START_DATE_FORMAT = 'Invalid startDate format. Expected yyyy-MM-dd.';
    public static final String ERR_MSG_INVALID_END_DATE_FORMAT = 'Invalid endDate format. Expected yyyy-MM-dd.';
    public static final String ERR_MSG_INVALID_DATE_RANGE = 'startDate cannot be greater than endDate.';
    public static final String ERR_MSG_START_END_DATE_REQUIRED = 'startDate and endDate are required.';
    public static final String ERR_MSG_SERVICE_UNAVAILABLE = 'Service temporarily unavailable. Please retry later.';
    public static final String MSG_NO_STAYS_FOUND = 'No Stays found.';
    public static final String MSG_STAY_NOT_FOUND = 'Stay not found.';

    // Object/relationship keys for field-mapping maps
    public static final String OBJECT_LOYALTY_STAY = 'Loyalty_Stay__c';
    public static final String REL_OBJECT_TRANSACTION_JOURNAL = 'Transaction_Journal__r';

    // Property info map keys (findPropertyInfoByCodes result)
    public static final String PROP_INFO_PROPERTY_NAME = 'propertyName';
    public static final String PROP_INFO_BRAND_CODE = 'brandCode';

    // GET Stay API response wrapper list keys
    public static final String GET_STAY_POSTED_STAYS = 'postedStays';
    public static final String GET_STAY_PURGED_STAYS = 'purgedStays';
    public static final String GET_STAY_EC_STAYS = 'ecStays';

    // GET Stay API response field keys (single-stay flat object / StayDetail map)
    public static final String GET_STAY_KEY_ARRIVAL_DATE = 'arrivalDate';
    public static final String GET_STAY_KEY_DEPARTURE_DATE = 'departureDate';
    public static final String GET_STAY_KEY_BRAND_CODE = 'brandCode';
    public static final String GET_STAY_KEY_PROPERTY_CODE = 'propertyCode';
    public static final String GET_STAY_KEY_TOTAL_REVENUE = 'totalRevenue';
    public static final String GET_STAY_KEY_TOTAL_REVENUE_IN_LOCAL = 'totalRevenueInLocal';
    public static final String GET_STAY_KEY_EARNING_PREFERENCE = 'earningPreference';
    public static final String GET_STAY_KEY_AIRLINE_PARTNER_ID = 'airlinePartnerId';
    public static final String GET_STAY_KEY_FREQUENT_FLIER_NUMBER = 'frequentFlierNumber';
    public static final String GET_STAY_KEY_STAY_STATUS = 'stayStatus';
    public static final String GET_STAY_KEY_PERSONAL_NIGHTS = 'personalNights';
    public static final String GET_STAY_KEY_PAID_NIGHTS = 'paidNights';
    public static final String GET_STAY_KEY_VISIT_TYPE = 'visitType';
    public static final String GET_STAY_KEY_FOLIO_STAY_ID = 'folioStayId';
    public static final String GET_STAY_KEY_FOLIO_NUMBER = 'folioNumber';
    public static final String GET_STAY_KEY_STAY_ID = 'stayId';
    public static final String GET_STAY_KEY_PAYMENT_TYPE_IDENTIFIER = 'paymentTypeIdentifier';
    public static final String GET_STAY_KEY_STAY_POSTED_DATE = 'stayPostedDate';
    public static final String GET_STAY_KEY_GOLD_ARRIVAL_FLAG = 'goldArrivalFlag';
    public static final String GET_STAY_KEY_PLAT_ARRIVAL_FLAG = 'platarrivalFlag';
    public static final String GET_STAY_KEY_INCIDENTAL_STAY_FLAG = 'incidentalStayFlag';
    public static final String GET_STAY_KEY_REDEMPTION_TRANS_ID = 'redemptionTransId';
    public static final String GET_STAY_KEY_EARN_TRANSACTION_IDENTIFIER = 'earnTransactionIdentifier';
    public static final String GET_STAY_KEY_TOTAL_EARNING = 'totalEarning';
    public static final String GET_STAY_KEY_PROPERTY_NAME = 'propertyName';
    public static final String GET_STAY_KEY_RESERVATION_TYPE = 'reservationType';
    public static final String GET_STAY_KEY_CURRENCY_CODE = 'currencyCode';
    public static final String GET_STAY_KEY_RESERVATION_CONFIRMATION_NUMBER = 'reservationConfirmationNumber';
    public static final String GET_STAY_KEY_RESERVATION_CREATED_DATE = 'reservationCreatedDate';
    public static final String GET_STAY_KEY_PROGRAM_OF_RECORD = 'programOfRecord';
    public static final String GET_STAY_KEY_GROUP_INDUSTRY_TYPE = 'groupIndustryType';
    public static final String GET_STAY_KEY_MARKET_CODE_RATE_PLAN = 'marketCodeRatePlan';
    public static final String GET_STAY_KEY_HOST_MULTIPLE_INDICATOR = 'hostMultInd';
    public static final String GET_STAY_KEY_REDEMPTION_NIGHTS      = 'redemptionNights';
    public static final String GET_STAY_KEY_STAY_EARNING_DETAILS   = 'stayEarningDetails';

    // stayEarningDetails object keys and description labels
    public static final String EARNING_DETAIL_KEY_EARNINGS         = 'earnings';
    public static final String EARNING_DETAIL_KEY_DESCRIPTION      = 'earningsDescription';
    public static final String EARNING_DESC_ARRIVAL_BONUS          = Label.GetMemberStaysApiEarningDescArrivalBonus;
    public static final String EARNING_DESC_REWARDS_BREAKFAST      = Label.GetMemberStaysApiEarningDescRewardsBreakfast;

    // TransactionJournal field names for GET Stay API
    public static final String TJ_FIELD_PROGRAM_OF_RECORD = 'Program_Of_Record__c';
    public static final String TJ_FIELD_GROUP_INDUSTRY = 'Group_Industry__c';
    public static final String TJ_FIELD_IS_PARENT_TRANSACTION = 'IsParentTransaction';
    public static final String TJ_FIELD_RATE_PLAN_CODE = 'Rate_Plan_Code__c';
    public static final String TJ_FIELD_PARTNER_ACCOUNT_NUMBER = 'Partner_Account_Number__c';

    // Fields required in the SOQL query for computed response fields but not directly mapped to API attributes
    public static final List<String> STAY_ADDITIONAL_QUERY_FIELDS = new List<String>{
        'Total_Base_Points__c', 'Total_Elite_Bonus_Points__c', 'Total_Extra_Points__c',
        'Total_Elite_Qualifying_Nights__c', 'Reservation_Confirmation_Number__c',
        'Membership_Number__r.Program.Name','Stay_Scenario__c',
        'Loyalty_Tier__r.Level_Id__c',
        'Total_Eligible_Revenue_Local__c', 'Total_Eligible_Revenue__c'
    };

    public static final List<String> TJ_ADDITIONAL_QUERY_FIELDS = new List<String>{
        'Partner.Partner_Id__c', 'Partner_Account_Number__c', 'IsParentTransaction',
        'Program_Of_Record__c',  'Benefits__c', 'Visit_Type__c', 'Extra_Points__c'
    };


    //LYLT - 1544
    /******************************
     * Visit Type Constants for GetStayApi
     ******************************/

    public static final List<String> STAY_AND_EARN_VISIT_TYPE_NAMES = new List<String>{
        VISIT_TYPE_PAID_DAY_USE_STAY,
        VISIT_TYPE_REDEMPTION_DAY_USE_STAY
    };

    /******************************
     * Benefit Name Constants for GetStayApi
     ******************************/
    public static final String WELCOME_GIFT_BENEFIT_NAME= 'Welcome Gift';
    public static final String GUARANTEED_LOUNGE_ALTERNATIVE_ACCESS_BENEFIT_NAME   = 'Guaranteed Lounge Access Alternative';
    public static final List<String> STAY_AND_EARN_BENEFIT_NAMES = new List<String>{
        WELCOME_GIFT_BENEFIT_NAME,
        GUARANTEED_LOUNGE_ALTERNATIVE_ACCESS_BENEFIT_NAME
    };
       
}