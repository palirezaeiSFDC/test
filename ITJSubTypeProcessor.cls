/*******************************************************************************************
 * @Name         ITJSubTypeProcessor.cls
 * @Author       Salesforce
 * @Date         04/30/2026
 * @Group        SF-Implementation
 * @Description  Interface that every JournalSubType processor must implement.
 *               Adding support for a new subtype (e.g. eBonus) requires only:
 *                 1. A new class that implements this interface
 *                 2. A new entry in TJProcessorFactory
 *               No changes needed in TJBatchApiController.
 *******************************************************************************************/
/* MODIFICATION LOG
 * Version          Developer          Date               Description
 *-------------------------------------------------------------------------------------------
 *  1.0             Pegah.Alirezaei    04/30/2026         Initial Creation - LYLT-363
 *******************************************************************************************/
public interface ITJSubTypeProcessor {

    /**
     * @description  Executes all subtype-specific business logic for a single TJ.
     *               Called after the TJ record has been created in Pending status.
     *               The implementation is responsible for:
     *                 - Running subtype-specific cap and eligibility rules
     *                 - Triggering the correct Loyalty Process
     *                 - Posting earnings to the member ledger
     *                 - Updating TransactionJournal.Status to Processed or Error
     *
     * @param  tjId   Salesforce Id of the TransactionJournal record (Pending)
     * @param  input  The original TJInput from the request
     * @return        TJBatchResponse.TJResult with final Status and ErrorDescription
     */
    TJBatchResponse.TJResult process(Id tjId, TJBatchRequest.TJInput input);
}
