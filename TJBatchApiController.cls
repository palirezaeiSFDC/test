/*******************************************************************************************
 * @Name         TJBatchApiController.cls
 * @Author       Salesforce
 * @Date         04/30/2026
 * @Group        SF-Implementation
 * @Description  Generic custom Apex REST endpoint for batch Transaction Journal processing.
 *               Endpoint: POST /services/apexrest/loyalty/{programName}/lyt/sf-transaction-journals
 *
 *               Responsibilities:
 *                 1. Deserialize and validate the incoming TJ batch request
 *                 2. For each TJ: validate required fields, create TJ in Pending, dispatch
 *                    to the correct subtype processor via TJProcessorFactory
 *                 3. Each TJ is isolated in its own savepoint — partial success is supported
 *                 4. Return one TJResult per input TJ in the same order
 *
 *               Extensibility:
 *                 - To support a new JournalSubType, add a processor class that implements
 *                   ITJSubTypeProcessor and register it in TJProcessorFactory.
 *                 - No changes required in this controller.
 *******************************************************************************************/
/* MODIFICATION LOG
 * Version          Developer          Date               Description
 *-------------------------------------------------------------------------------------------
 *  1.0             Pegah.Alirezaei    04/30/2026         Initial Creation - LYLT-363
 *******************************************************************************************/
@RestResource(urlMapping='/loyalty/*/lyt/sf-transaction-journals')
global with sharing class TJBatchApiController {

    public static final String STATUS_PROCESSED = StayAndEarnApexConstants.TJ_STATUS_PROCESSED;
    public static final String STATUS_ERROR     = StayAndEarnApexConstants.TJ_STATUS_ERROR;

    private static final Integer HTTP_STATUS_BAD_REQUEST = 400;

    // ──────────────────────────────────────────────────────────────────────────
    // Entry point
    //
    // Returns void (mirrors MemberStayApi) and writes the JSON body manually via
    // TJBatchResponse.toJson(). This avoids exposing public wrapper classes
    // (TJBatchRequest / TJBatchResponse / their inner classes) on a global REST
    // signature — which Salesforce flags during managed-package + security review
    // and which can break field ordering in the response body.
    // ──────────────────────────────────────────────────────────────────────────

    @HttpPost
    global static void doPost() {
        RestRequest  req  = RestContext.request;
        RestResponse res  = RestContext.response;
        if (res == null) {
            res = new RestResponse();
            RestContext.response = res;
        }
        res.addHeader(ApexConstants.CONTENT_TYPE, ApexConstants.APPLICATION_JSON);

        TJBatchRequest batchRequest;
        try {
            batchRequest = (TJBatchRequest) JSON.deserialize(
                req.requestBody.toString(), TJBatchRequest.class
            );
        } catch (Exception e) {
            writeResponse(res, HTTP_STATUS_BAD_REQUEST,
                errorResponse('Invalid request body: ' + e.getMessage()));
            return;
        }

        if (batchRequest.transactionJournals == null || batchRequest.transactionJournals.isEmpty()) {
            writeResponse(res, HTTP_STATUS_BAD_REQUEST,
                errorResponse('transactionJournals array is required and must not be empty.'));
            return;
        }

        List<TJBatchResponse.TJResult> results = new List<TJBatchResponse.TJResult>();
        for (TJBatchRequest.TJInput tjInput : batchRequest.transactionJournals) {
            results.add(processSingleTJ(tjInput));
        }

        writeResponse(res, StayAndEarnApexConstants.HTTP_STATUS_CODE_200,
            new TJBatchResponse(results));
    }

    /**
     * @description  Serializes the response wrapper and writes it to the RestResponse
     *               body with the given status code.
     */
    private static void writeResponse(RestResponse res, Integer statusCode, TJBatchResponse body) {
        res.statusCode   = statusCode;
        res.responseBody = Blob.valueOf(body.toJson());
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Per-TJ processing  (isolated savepoint → partial success supported)
    // ──────────────────────────────────────────────────────────────────────────

    @TestVisible
    private static TJBatchResponse.TJResult processSingleTJ(TJBatchRequest.TJInput input) {

        // ── Step 1: Required field validation ─────────────────────────────────
        String validationError = validateRequiredFields(input);
        if (String.isNotBlank(validationError)) {
            return new TJBatchResponse.TJResult(validationError);
        }

        // ── Step 2: Resolve processor for this subtype ────────────────────────
        ITJSubTypeProcessor processor = TJProcessorFactory.getProcessor(input.JournalSubType);
        if (processor == null) {
            return new TJBatchResponse.TJResult(
                'Unsupported JournalSubType: ' + input.JournalSubType
            );
        }

        // ── Step 3: Savepoint – isolates this TJ so failures don't affect others
        Savepoint sp = Database.setSavepoint();

        try {
            // ── Step 4: Create TJ record in Pending status ───────────────────
            TransactionJournal tj = buildTJRecord(input);
            insert tj; // NOPMD – single record insert, intentional

            // ── Step 5: Delegate to subtype processor ────────────────────────
            //    Processor handles: cap rules, Loyalty Process trigger,
            //    ledger posting, TJ status update (Processed / Error)
            TJBatchResponse.TJResult result = processor.process(tj.Id, input);

            // ── Step 6: If processor signals a hard error, roll back TJ ──────
            if (result.Status == STATUS_ERROR) {
                Database.rollback(sp);
                result.Id   = null;
                result.Name = null;
            }

            return result;

        } catch (Exception e) {
            Database.rollback(sp);
            return new TJBatchResponse.TJResult(
                'Unexpected error: ' + e.getMessage()
            );
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Required field validation
    // ──────────────────────────────────────────────────────────────────────────

    @TestVisible
    private static String validateRequiredFields(TJBatchRequest.TJInput input) {
        List<String> errors = new List<String>();

        if (String.isBlank(input.MemberId)) {
            errors.add('MemberId is required.');
        }
        if (input.ActivityDate == null) {
            errors.add('ActivityDate is required.');
        }
        if (String.isBlank(input.CurrencyIsoCode)) {
            errors.add('CurrencyIsoCode is required.');
        }
        if (String.isBlank(input.JournalSubType)) {
            errors.add('JournalSubType is required.');
        }

        return errors.isEmpty() ? null : String.join(errors, ' | ');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TJ record builder – maps generic fields shared across all subtypes
    // Subtype-specific fields (FlightNumber, Additional_Details__c etc.)
    // are mapped inside each processor before the Loyalty Process is triggered
    // ──────────────────────────────────────────────────────────────────────────

    @TestVisible
    private static TransactionJournal buildTJRecord(TJBatchRequest.TJInput input) {
        TransactionJournal tj = new TransactionJournal();

        tj.MemberId                  = input.MemberId;
        tj.ActivityDate              = input.ActivityDate;
        tj.CurrencyIsoCode           = input.CurrencyIsoCode;
        tj.ExternalTransactionNumber = input.ExternalTransactionId;
        tj.Establishment__c          = input.Establishment;
        tj.StartDate                 = input.StartDate;
        tj.EndDate                   = input.EndDate;
        tj.BookingDate               = input.BookingDate;
        tj.TransactionAmount         = input.TransactionAmount;
        tj.Quantity                  = input.Quantity;
        tj.Quantity_Unit__c          = input.Quantity_Unit__c;
        tj.PaymentMethod             = input.PaymentMethod;
        tj.PartnerName               = input.PartnerName;
        tj.Partner_Account_Number__c = input.Partner_Account_Number__c;
        tj.Associate_Id__c           = input.Associate_Id__c;
        tj.Notes__c                  = input.Notes__c;
        tj.Status                    = 'Pending';

        return tj;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Utility – wraps a single top-level error into the standard response shape
    // ──────────────────────────────────────────────────────────────────────────

    private static TJBatchResponse errorResponse(String message) {
        return new TJBatchResponse(
            new List<TJBatchResponse.TJResult>{
                new TJBatchResponse.TJResult(message)
            }
        );
    }
}
