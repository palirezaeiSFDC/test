/*******************************************************************************************
 * @Name         TJBatchResponse.cls
 * @Author       Salesforce
 * @Date         04/30/2026
 * @Group        SF-Implementation
 * @Description  Response wrapper for the generic Transaction Journal batch API.
 *               Returns one TJResult per submitted TJ in the same order as the request.
 *******************************************************************************************/
/* MODIFICATION LOG
 * Version          Developer          Date               Description
 *-------------------------------------------------------------------------------------------
 *  1.0             Pegah.Alirezaei    04/30/2026         Initial Creation - LYLT-363
 *******************************************************************************************/
public class TJBatchResponse {

    /** One result per submitted TJ, in request order */
    public List<TJResult> transactionJournals;

    public TJBatchResponse(List<TJResult> results) {
        this.transactionJournals = results;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Serialization
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * @description  Serializes the response to a JSON string with deterministic
     *               field ordering (Id → Name → Status → ErrorDescription).
     *               Apex `JSON.serialize(Map)` does not guarantee key order, and
     *               returning a `public` wrapper directly from a `global` REST
     *               method is not portable across managed packages — so we mirror
     *               the Stay API pattern (`MemberStayApi` / `TransactionJournalResponse.toJson`)
     *               and have the controller write the body manually.
     * @return       JSON body suitable for `RestResponse.responseBody`
     */
    public String toJson() {
        List<String> entries = new List<String>();
        if (this.transactionJournals != null) {
            for (TJResult r : this.transactionJournals) {
                entries.add(
                    '{'
                    + '"Id":'               + JSON.serialize(r.Id)               + ','
                    + '"Name":'             + JSON.serialize(r.Name)             + ','
                    + '"Status":'           + JSON.serialize(r.Status)           + ','
                    + '"ErrorDescription":' + JSON.serialize(r.ErrorDescription)
                    + '}'
                );
            }
        }
        return '{"transactionJournals":[' + String.join(entries, ',') + ']}';
    }

    public class TJResult {

        /** Salesforce record Id of the created TransactionJournal. Null when status = Error. */
        public String  Id;

        /** TransactionJournal.Name (auto-number). Null when status = Error. */
        public String  Name;

        /**
         * Final processing status:
         *   Processed – TJ created and earnings awarded.
         *   Error     – TJ not created; see ErrorDescription for details.
         */
        public String  Status;

        /**
         * Human-readable reason for failure.
         * Null when Status = Processed.
         * Examples:
         *   "MemberId is required."
         *   "ActivityDate is required."
         *   "CurrencyIsoCode is required."
         *   "Unsupported JournalSubType: XYZ"
         *   "Earned Points plus Purchased Points cannot exceed 200,000 points,
         *    please adjust Purchased Point Value. Overage: 5000"
         *   "Reward is over max allowed, so max will be awarded." (warning – Status still Processed)
         */
        public String  ErrorDescription;

        /** Convenience constructor for a successfully created TJ */
        public TJResult(String sfId, String name) {
            this.Id               = sfId;
            this.Name             = name;
            this.Status           = TJBatchApiController.STATUS_PROCESSED;
            this.ErrorDescription = null;
        }

        /** Convenience constructor for a rejected TJ (no record created) */
        public TJResult(String errorDescription) {
            this.Id               = null;
            this.Name             = null;
            this.Status           = TJBatchApiController.STATUS_ERROR;
            this.ErrorDescription = errorDescription;
        }

        /** Convenience constructor for a processed TJ with a cap warning */
        public TJResult(String sfId, String name, String warningMessage) {
            this.Id               = sfId;
            this.Name             = name;
            this.Status           = TJBatchApiController.STATUS_PROCESSED;
            this.ErrorDescription = warningMessage;
        }
    }
}
