/*******************************************************************************************
 * @Name         TJProcessorFactory.cls
 * @Author       Salesforce
 * @Date         04/30/2026
 * @Group        SF-Implementation
 * @Description  Factory that returns the correct ITJSubTypeProcessor implementation
 *               based on JournalSubType.
 *               To add a new subtype: add a case entry and a new processor class.
 *******************************************************************************************/
/* MODIFICATION LOG
 * Version          Developer          Date               Description
 *-------------------------------------------------------------------------------------------
 *  1.0             Pegah.Alirezaei    04/30/2026         Initial Creation - LYLT-363
 *******************************************************************************************/
public with sharing class TJProcessorFactory {

    private static final String SUBTYPE_EVENTS  = 'Events';
    private static final String SUBTYPE_EBONUS  = 'eBonus';   // future

    /**
     * @description  Returns the processor for the given JournalSubType.
     * @param  journalSubType  Value from TJInput.JournalSubType
     * @return ITJSubTypeProcessor or null when subtype is not supported
     */
    public static ITJSubTypeProcessor getProcessor(String journalSubType) {
        if (String.isBlank(journalSubType)) {
            return null;
        }
        switch on journalSubType {
            when 'Events' {
                return new EventsTJProcessor();
            }
            when 'eBonus' {
                // return new EBonusTJProcessor();   // wire in when implemented
                return null;
            }
            when else {
                return null;
            }
        }
    }
}
