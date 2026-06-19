/*******************************************************************************************
 * @Name         TransactionJournalResponse.cls
 * @Author       Salesforce
 * @Date         05/01/2026
 * @Group        SF-Implementation
 * @Description  Wrapper class for Post Member Stay API response payload.
 *               Contains Stay record details and created TransactionJournal record IDs.
 *******************************************************************************************/
 /* MODIFICATION LOG
 * Version          Developer          Date               Description
 *-------------------------------------------------------------------------------------------
 *  1.0             Praveen      05/01/2026        Initial Creation for LYLT-7402
 *******************************************************************************************/
public class TransactionJournalResponse {

    /******************************
     * Response Properties
     ******************************/
    public StayResult stay;
    public List<TransactionJournalResult> transactionJournals;

    /******************************
     * Constructor
     ******************************/
    public TransactionJournalResponse() {
        this.transactionJournals = new List<TransactionJournalResult>();
    }

    /******************************
     * Inner Class for Stay Result
     * Note: Apex doesn't allow __c in variable names, so we use camelCase internally
     * and serialize to Map with __c field names for JSON response
     ******************************/
    public class StayResult {
        public String id;
        public String name;
        public String stayStatus;
        public String dispositionErrorCode;
        public String stayDispositionReason;

        public StayResult(Loyalty_Stay__c stayRecord) {
            this.id = stayRecord.Id;
            this.name = stayRecord.Name;
            this.stayStatus = stayRecord.Stay_Status__c;
            this.dispositionErrorCode = stayRecord.Disposition_Error_Code__c;
            this.stayDispositionReason = stayRecord.Stay_Disposition_Reason__c;
        }

        /**
         * @description Converts StayResult to Map with __c field names for JSON serialization
         * @return Map<String, Object> - Map with correct field names for API response
         */
        public Map<String, Object> toMap() {
            Map<String, Object> mapResult = new Map<String, Object>();
            mapResult.put('Id', this.id);
            mapResult.put('Name', this.name);
            mapResult.put('Stay_Status__c', this.stayStatus);
            mapResult.put('Disposition_Error_Code__c', this.dispositionErrorCode);
            mapResult.put('Stay_Disposition_Reason__c', this.stayDispositionReason);
            return mapResult;
        }
    }

    /******************************
     * Inner Class for Transaction Journal Result
     ******************************/
    public class TransactionJournalResult {
        public String id;

        public TransactionJournalResult(String recordId) {
            this.id = recordId;
        }
    }

    /******************************
     * Helper Methods
     ******************************/

    /**
     * @description Adds a transaction journal result to the response
     * @param recordId - The Salesforce record ID of the created TransactionJournal
     */
    public void addTransactionJournal(String recordId) {
        this.transactionJournals.add(new TransactionJournalResult(recordId));
    }

    /**
     * @description Creates a response from Stay and TransactionJournal records
     *              Never returns null - always returns a valid response object
     * @param stayRecord - The created Loyalty_Stay__c record
     * @param journals - List of inserted TransactionJournal records
     * @param errorCode - Error code from validation result (can be null)
     * @return TransactionJournalResponse - Never null
     */
    public static TransactionJournalResponse fromRecords(Loyalty_Stay__c stayRecord, List<TransactionJournal> journals) {
        TransactionJournalResponse response = new TransactionJournalResponse();
        // Set stay details
        if (stayRecord != null && stayRecord.Id != null) {
            response.stay = new StayResult(stayRecord);
        }

        // Set transaction journal IDs
        if (journals != null && !journals.isEmpty()) {
            for (TransactionJournal tj : journals) {
                if (tj != null && tj.Id != null) {
                    response.addTransactionJournal(tj.Id);
                }
            }
        }

        return response;
    }

    /**
     * @description Converts TransactionJournalResponse to Map with __c field names for JSON serialization
     *              This allows us to have __c in JSON field names even though Apex doesn't allow __c in variable names
     * @return Map<String, Object> - Map representation ready for JSON serialization
     */
    public Map<String, Object> toMap() {
        Map<String, Object> mapResponse = new Map<String, Object>();

        if (this.stay != null) {
            mapResponse.put('stay', this.stay.toMap());
        }

        List<Map<String, Object>> tjList = new List<Map<String, Object>>();
        if (this.transactionJournals != null && !this.transactionJournals.isEmpty()) {
            for (TransactionJournalResult tj : this.transactionJournals) {
                Map<String, Object> tjMap = new Map<String, Object>();
                tjMap.put('Id', tj.id);
                tjList.add(tjMap);
            }
        }
        mapResponse.put('transactionJournals', tjList);

        return mapResponse;
    }

    /**
     * @description Manually builds a JSON string for the POST success response to guarantee
     *              field ordering: transactionJournals first, then stay with
     *              Id → Name → Stay_Status__c → Disposition_Error_Code__c → Stay_Disposition_Reason__c.
     *              JSON.serialize(Map) does not preserve insertion order in Apex.
     * @return String - JSON response body
     */
    public String toJson() {
        // Build transactionJournals array
        List<String> tjEntries = new List<String>();
        if (this.transactionJournals != null) {
            for (TransactionJournalResult tj : this.transactionJournals) {
                tjEntries.add('{"Id":' + JSON.serialize(tj.id) + '}');
            }
        }
        String tjJson = '[' + String.join(tjEntries, ',') + ']';

        // Build stay object with guaranteed field order
        String stayJson = 'null';
        if (this.stay != null) {
            stayJson = '{'
                + '"Id":' + JSON.serialize(this.stay.id) + ','
                + '"Name":' + JSON.serialize(this.stay.name) + ','
                + '"Stay_Status__c":' + JSON.serialize(this.stay.stayStatus) + ','
                + '"Disposition_Error_Code__c":' + JSON.serialize(this.stay.dispositionErrorCode) + ','
                + '"Stay_Disposition_Reason__c":' + JSON.serialize(this.stay.stayDispositionReason)
                + '}';
        }

        return '{"transactionJournals":' + tjJson + ',"stay":' + stayJson + '}';
    }
}