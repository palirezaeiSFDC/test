/*******************************************************************************************
 * @Name         MemberStayExceptionHandler.cls
 * @Author       Salesforce
 * @Group        SF-Implementation
 * @Description  Handles exceptions for Member Stay API (GET/POST/PUT/PATCH).
 *               Applies mapped errors to RestResponse and logs server errors.
 *               Works with MemberStayExceptionMapper for exception-to-response mapping.
 *               Handles MemberStayCecBulkException (including when wrapped in cause chain).
 *******************************************************************************************/
/* MODIFICATION LOG
 * Version          Developer          Date               Description
 *-------------------------------------------------------------------------------------------
 *  1.0             Sai Vinay Thumu    13/02/2026        Initial Creation - extracted from MemberStayApi
 *  2.0             Sai Vinay Thumu    13/02/2026        Add handleStayNotFound404, handleStayIdRequired400 for GET/PATCH reuse
 *******************************************************************************************/
public with sharing class MemberStayExceptionHandler {

    /**
     * @description Handles 404 when no stays found for multi-stay GET (AC8).
     *              Returns [{ "errorCode": "", "message": "No Stays found." }]
     */
    public static void handleNoStaysFound404(RestResponse res) {
        LoyaltyIntegrationUtils.setStayErrorArrayResponse(res, 404, new List<Map<String, String>>{
            new Map<String, String>{
                ApexConstants.ERROR_CODE    => '',
                ApexConstants.ERROR_MESSAGE => StayAndEarnApexConstants.MSG_NO_STAYS_FOUND
            }
        });
    }

    /**
     * @description Handles 404 for GET single stay when the stay does not exist (AC8).
     *              Returns [{ "errorCode": "", "message": "Stay not found." }]
     */
    public static void handleSingleStayNotFound404(RestResponse res) {
        LoyaltyIntegrationUtils.setStayErrorArrayResponse(res, 404, new List<Map<String, String>>{
            new Map<String, String>{
                ApexConstants.ERROR_CODE    => '',
                ApexConstants.ERROR_MESSAGE => StayAndEarnApexConstants.MSG_STAY_NOT_FOUND
            }
        });
    }

    /**
     * @description Handles 400 Bad Request - missing required stay ID (e.g. PATCH without stayId) (AC1).
     *              Returns [{ "errorCode": "...", "message": "..." }]
     * @param res RestResponse to write error to
     */
    public static void handleStayIdRequired400(RestResponse res) {
        LoyaltyIntegrationUtils.setStayErrorArrayResponse(res, 400, new List<Map<String, String>>{
            new Map<String, String>{
                ApexConstants.ERROR_CODE    => String.valueOf(ApexConstants.ErrorCode.INVALID_API_INPUT),
                ApexConstants.ERROR_MESSAGE => StayAndEarnApexConstants.ERR_MSG_STAY_ID_REQUIRED_CEC
            }
        });
    }

    /**
     * @description Handles exception: applies error to RestResponse and logs 500+ errors.
     *              MemberStayCecBulkException (including when wrapped in cause chain) gets disposition format.
     *              Other exceptions use MemberStayExceptionMapper.
     * @param ex Exception from request processing
     * @param req RestRequest for context (URI)
     * @param res RestResponse to write error to
     * @param method HTTP method for logging context
     */
    public static void handleException(Exception ex, RestRequest req, RestResponse res, String method) {
        MemberStayCecValidator.MemberStayCecBulkException bulkEx = findCecBulkExceptionInChain(ex);
        if (bulkEx != null) {
            applyCecBulkExceptionResponse(res, bulkEx);
        } else {
            applyMappedExceptionResponse(res, ex);
        }
        logExceptionIfServerError(ex, req, method);
    }

    private static MemberStayCecValidator.MemberStayCecBulkException findCecBulkExceptionInChain(Exception ex) {
        Exception current = ex;
        while (current != null) {
            if (current instanceof MemberStayCecValidator.MemberStayCecBulkException) {
                return (MemberStayCecValidator.MemberStayCecBulkException) current;
            }
            current = current.getCause();
        }
        return null;
    }

    /**********************************************************************************
     * @description   Applies CEC bulk exception response.
     *                 Uses disposition format (errorCode, message) for all status codes including 404.
     *                 PUT/PATCH stay-not-found returns STAY_NOT_FOUND (5004) per spec.
     * @param         res - RestResponse object
     * @param         bulkEx - MemberStayCecValidator.MemberStayCecBulkException object
     * @return        void
     **************************************************************************************/
    private static void applyCecBulkExceptionResponse(RestResponse res, MemberStayCecValidator.MemberStayCecBulkException bulkEx) {
        List<Map<String, String>> errors = buildDispositionMapsFromCecResults(bulkEx.dispositionResults);
        if (errors.isEmpty()) {
            errors.add(new Map<String, String>{
                ApexConstants.ERROR_CODE    => StayAndEarnApexConstants.VALIDATION_ERROR_CODE,
                ApexConstants.ERROR_MESSAGE => StayAndEarnApexConstants.VALIDATION_FAILED_MESSAGE
            });
        }
        LoyaltyIntegrationUtils.setStayErrorArrayResponse(res, bulkEx.statusCode, errors);
    }

    /**********************************************************************************
     * @description   Builds disposition maps from CEC results.
     * @param         results - List of MemberStayCecValidator.CecDispositionResult objects
     * @return        List<Map<String, String>> - List of disposition maps
     **************************************************************************************/
    private static List<Map<String, String>> buildDispositionMapsFromCecResults(List<MemberStayCecValidator.CecDispositionResult> results) {
        List<Map<String, String>> maps = new List<Map<String, String>>();
        if (results != null) {
            for (MemberStayCecValidator.CecDispositionResult r : results) {
                String errCode = (r != null && String.isNotBlank(r.errorCode)) ? r.errorCode : StayAndEarnApexConstants.VALIDATION_ERROR_CODE;
                String errMsg = (r != null && String.isNotBlank(r.message)) ? r.message : StayAndEarnApexConstants.VALIDATION_FAILED_MESSAGE;
                maps.add(new Map<String, String>{ ApexConstants.ERROR_CODE => errCode, ApexConstants.ERROR_MESSAGE => errMsg });
            }
        }
        return maps;
    }

    /**********************************************************************************
     * @description   Applies mapped exception response.
     * @param         res - RestResponse object
     * @param         ex - Exception object
     * @return        void
     **************************************************************************************/
    private static void applyMappedExceptionResponse(RestResponse res, Exception ex) {
        MemberStayExceptionMapper.ErrorResponse errorResponse = MemberStayExceptionMapper.mapException(ex);

        // 503 — service unavailable (handled separately for logging)
        if (errorResponse.statusCode == 503) {
            LoyaltyIntegrationUtils.handleServiceUnavailable503(
                res,
                errorResponse.message != null ? errorResponse.message : 'Service temporarily unavailable. Please retry later.',
                ApexConstants.ErrorCode.SERVICE_UNAVAILABLE,
                StayAndEarnApexConstants.PROCESS_NAME_MEMBER_STAY_API_HANDLE
            );
            return;
        }
        // 500 — internal server errors
        if (errorResponse.statusCode >= 500) {
            String errCode = errorResponse.errorCode != null ? errorResponse.errorCode : StayAndEarnApexConstants.VALIDATION_ERROR_CODE;
            String errMsg  = errorResponse.message  != null ? errorResponse.message  : StayAndEarnApexConstants.VALIDATION_FAILED_MESSAGE;
            LoyaltyIntegrationUtils.setStayErrorArrayResponse(res, errorResponse.statusCode, new List<Map<String, String>>{
                new Map<String, String>{ ApexConstants.ERROR_CODE => errCode, ApexConstants.ERROR_MESSAGE => errMsg }
            });
            return;
        }

        // Business validation errors — array format (AC1/AC2/AC8)
        if (errorResponse.dispositionResults != null && !errorResponse.dispositionResults.isEmpty()) {
            LoyaltyIntegrationUtils.setStayErrorArrayResponse(res, errorResponse.statusCode, errorResponse.dispositionResults);
        } else {
            String errCode = errorResponse.errorCode != null ? errorResponse.errorCode : StayAndEarnApexConstants.VALIDATION_ERROR_CODE;
            String errMsg  = errorResponse.message  != null ? errorResponse.message  : StayAndEarnApexConstants.VALIDATION_FAILED_MESSAGE;
            LoyaltyIntegrationUtils.setStayErrorArrayResponse(res, errorResponse.statusCode, new List<Map<String, String>>{
                new Map<String, String>{ ApexConstants.ERROR_CODE => errCode, ApexConstants.ERROR_MESSAGE => errMsg }
            });
        }
    }

    /**********************************************************************************
     * @description   Logs exception if server error.
     * @param         ex - Exception object
     * @param         req - RestRequest object
     * @param         method - String method
     * @return        void
     **************************************************************************************/
    private static void logExceptionIfServerError(Exception ex, RestRequest req, String method) {
        MemberStayExceptionMapper.ErrorResponse errorResponse = MemberStayExceptionMapper.mapException(ex);
        if (errorResponse.statusCode >= 500) {
            String requestUri = (req != null && req.requestURI != null) ? req.requestURI : StayAndEarnApexConstants.UNKNOWN_URI;
            ExceptionLogger.logException(
                ex,
                StayAndEarnApexConstants.PROCESS_NAME_MEMBER_STAY_API_HANDLE,
                null,
                errorResponse.errorCode,
                ApexConstants.ERROR,
                JSON.serialize(new Map<String, Object>{
                    StayAndEarnApexConstants.LOG_CONTEXT_KEY_METHOD => method,
                    StayAndEarnApexConstants.LOG_CONTEXT_KEY_URI => requestUri
                })
            );
        }
    }
}