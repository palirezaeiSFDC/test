/*******************************************************************************************
* @Name         MemberStayApi.cls
* @Author       Salesforce
* @Group        SF-Implementation
* @Description  Apex REST service for member stay operations.
*               GET:  /loyalty/{program}/earn/sf-stay?membershipNumber=...&startDate=...&endDate=...
*               GET:  /loyalty/{program}/earn/sf-stay/{stayId}
*               POST: /loyalty/{program}/earn/sf-stay
*               PUT:  /loyalty/{program}/earn/sf-stay/{stayId}
*               PATCH:  /loyalty/{program}/earn/sf-stay/{stayId} (soft-delete per Swagger)
*******************************************************************************************/
/* MODIFICATION LOG
* Version          Developer          Date               Description
*-------------------------------------------------------------------------------------------
*  1.0             Praveen           05/01/2026        Initial Creation for LYLT-7402
*  2.0             Sai Vinay Thumu   11/02/2026        Added PUT method for stay adjustments (LYLT-367, LYLT-8556)
*  3.0             Sai Vinay Thumu   13/02/2026        Added PATCH for CEC soft-delete (Swagger spec, LYLT-8586)
*  4.0             Akanksha Gautam   15/03/2026        Added GET for CEC Stay API (LYLT-6928)
*  5.0             Sai Vinay Thumu   13/02/2026        Added GET single stay by stayId in URL (LYLT-6928)
*******************************************************************************************/
@RestResource(urlMapping='/loyalty/*/earn/*')
global with sharing class MemberStayApi {

    /**
     * @description Handles GET requests to retrieve member stay history.
     *              Multi: /loyalty/{program}/earn/sf-stay?membershipNumber=...&startDate=...&endDate=...
     *              Single: /loyalty/{program}/earn/sf-stay/{stayId}
     */
    @HttpGet
    global static void getMemberStay() {
        ensureRestResponse();
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        restResponse.addHeader(ApexConstants.CONTENT_TYPE, ApexConstants.APPLICATION_JSON);

        if (LoyaltyIntegrationUtils.validateLoyaltyProgramNameInURI(restRequest, restResponse, '') == null) {
            return;
        }
        GetMemberStaysAPIService.processGetRequest(restRequest, restResponse, extractStayIdFromUri(restRequest.requestURI));
    }

    /******************************
     * HTTP POST Handler
     ******************************/

    /**
     * @description Handles POST requests to create stay transactions
     *              URL Pattern: /loyalty/{loyaltyProgramName}/earn/sf-stay
     *              Always creates a new stay
     */
    @HttpPost
    global static void postMemberStay() {
        handleRequest(StayAndEarnApexConstants.HTTP_METHOD_POST);
    }

    /******************************
     * HTTP PUT Handler
     ******************************/

    /**
     * @description Handles PUT requests to process stay adjustments
     *              URL Pattern: /loyalty/{loyaltyProgramName}/earn/sf-stay/{stayId}
     *              stayId is optional - if not provided, will use fallback lookup
     */
    @HttpPut
    global static void putMemberStay() {
        handleRequest(StayAndEarnApexConstants.HTTP_METHOD_PUT);
    }

    /**
     * @description Handles PATCH requests to soft-delete a stay (CEC) per Swagger spec
     *              URL Pattern: /loyalty/{loyaltyProgramName}/earn/sf-stay/{stayId}
     */
    @HttpPatch
    global static void patchMemberStay() {
        handleRequest(StayAndEarnApexConstants.HTTP_METHOD_PATCH);
    }

    /**
     * @description Ensures RestContext.response is initialized. Call before any response operations.
     */
    private static void ensureRestResponse() {
        if (RestContext.response == null) {
            RestContext.response = new RestResponse();
        }
    }

    /**
     * @description Orchestrates POST/PUT/PATCH requests. Centralizes validation, parsing, routing, and error handling.
     * @param method HTTP method ('POST', 'PUT', or 'PATCH')
     */
    private static void handleRequest(String method) {
        RestRequest req = RestContext.request;
        ensureRestResponse();
        RestResponse res = RestContext.response;
        res.addHeader(ApexConstants.CONTENT_TYPE, ApexConstants.APPLICATION_JSON);

        try {
            if (!LoyaltyIntegrationUtils.validateEndpoint(method, req.requestURI, RestContext.response)) {
                return;
            }
            String loyaltyProgramName = validateAndExtractProgramName(RestContext.response);
            if (loyaltyProgramName == null) {
                return;
            }
            List<TransactionJournalRequest> requests = null;
            if (method == StayAndEarnApexConstants.HTTP_METHOD_POST || method == StayAndEarnApexConstants.HTTP_METHOD_PUT) {
                requests = MemberStayMapperHelper.parseRequestBody(req.requestBody?.toString(), RestContext.response);
                if (requests == null) {
                    return;
                }
            }
            if (!executeMethodHandler(method, loyaltyProgramName, requests, req)) {
                return;
            }
        } catch (Exception ex) {
            MemberStayExceptionHandler.handleException(ex, RestContext.request, RestContext.response, method);
        }
    }

    /**
     * @description Executes POST, PUT, or PATCH handler. Returns false if validation failed (caller should return).
     */
    @TestVisible
    private static Boolean executeMethodHandler(String method, String loyaltyProgramName, List<TransactionJournalRequest> requests, RestRequest req) {
        if (method == StayAndEarnApexConstants.HTTP_METHOD_POST) {
            TransactionJournalResponse response = MemberStayService.createStayTransactions(loyaltyProgramName, requests);
            RestContext.response.statusCode = StayAndEarnApexConstants.HTTP_STATUS_CODE_201;
            RestContext.response.responseBody = Blob.valueOf(response.toJson());
        } else if (method == StayAndEarnApexConstants.HTTP_METHOD_PUT) {
            String stayId = extractStayIdFromUri(req.requestURI);
            StayAdjustmentService.StayAdjustmentResponse response = StayAdjustmentService.processStayAdjustment(
                loyaltyProgramName, requests, stayId
            );
            RestContext.response.statusCode = Integer.valueOf(response.statusCode);
            RestContext.response.responseBody = Blob.valueOf(response.toJson());
        } else if (method == StayAndEarnApexConstants.HTTP_METHOD_PATCH) {
            String stayId = extractStayIdFromUri(req.requestURI);
            if (String.isBlank(stayId)) {
                MemberStayExceptionHandler.handleStayIdRequired400(RestContext.response);
                return false;
            }
            String reasonCode = null;
            String comment = null;
            if (req.requestBody != null && String.isNotBlank(req.requestBody.toString())) {
                Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
                reasonCode = (String) bodyMap.get(StayAndEarnApexConstants.JSON_KEY_REASON_CODE);
                comment = (String) bodyMap.get(StayAndEarnApexConstants.JSON_KEY_COMMENT);
            }
            Map<String, Object> response = StayDeleteService.deleteStay(stayId, reasonCode, comment);
            sendResponse(RestContext.response, StayAndEarnApexConstants.HTTP_STATUS_CODE_200, response);
        }
        return true;
    }

    /**
     * @description Sends HTTP response with status code and JSON body
     * @param res RestResponse object
     * @param status HTTP status code
     * @param body Response body object to serialize as JSON
     */
    @TestVisible
    private static void sendResponse(RestResponse res, Integer status, Object body) {
        res.statusCode = status;
        res.responseBody = Blob.valueOf(JSON.serialize(body));
    }

    /**
     * @description Validates and extracts loyalty program name from request URI
     *              Uses LoyaltyIntegrationUtils.extractProgramName() for extraction
     *              Centralized method to avoid code duplication between POST and PUT handlers
     * @param res RestResponse to set error if validation fails
     * @return String loyaltyProgramName or null if validation fails
     */
    private static String validateAndExtractProgramName(RestResponse res) {
        ensureRestResponse();
        String loyaltyProgramName = LoyaltyIntegrationUtils.extractProgramName(RestContext.request.requestURI);

        if (String.isBlank(loyaltyProgramName) || !ApexConstants.LOYALTY_PROGRAMS.contains(loyaltyProgramName)) {
            LoyaltyIntegrationUtils.setStayErrorArrayResponse(RestContext.response, 400, new List<Map<String, String>>{
                new Map<String, String>{
                    ApexConstants.ERROR_CODE    => String.valueOf(ApexConstants.ErrorCode.INVALID_API_INPUT),
                    ApexConstants.ERROR_MESSAGE => StayAndEarnApexConstants.ERR_MSG_INVALID_LOYALTY_PROGRAM
                }
            });
            return null;
        }
        return loyaltyProgramName;
    }

    /**
     * @description Extracts optional stayId from URI pattern /loyalty/{program}/earn/sf-stay/{stayId}
     *              Uses substringAfter for cleaner read and split once to handle both '?' and '/'
     * @param uri Request URI
     * @return String stayId or null if not present
     */
    @TestVisible
    private static String extractStayIdFromUri(String uri) {
        // Use indexOf for precise pattern matching instead of contains() to avoid false matches
        // Pattern must be '/earn/sf-stay/' followed by at least one character (the stayId)
        if (String.isBlank(uri)) {
            return null;
        }
        
        // Find the exact position of '/earn/sf-stay/' pattern
        Integer patternIndex = uri.indexOf(StayAndEarnApexConstants.URI_PATTERN_EARN_SF_STAY);
        if (patternIndex == -1) {
            return null;
        }
        
        // Verify that there's content after the pattern (the stayId)
        Integer stayIdStartIndex = patternIndex + StayAndEarnApexConstants.URI_PATTERN_EARN_SF_STAY.length();
        if (stayIdStartIndex >= uri.length()) {
            return null;
        }

        String afterSfStay = uri.substring(stayIdStartIndex);
        if (String.isBlank(afterSfStay)) {
            return null;
        }

        String stayId = afterSfStay.split('[/?]')[0];
        // Reject query-string-like content (multi-stay URL misparsed as path)
        if (String.isNotBlank(stayId) && (stayId.contains('=') || stayId.contains('&'))) {
            return null;
        }
        if (String.isNotBlank(stayId)) {
            String originalStayId = stayId;
            try {
                stayId = EncodingUtil.urlDecode(stayId, 'UTF-8');
            } catch (Exception e) {
                ExceptionLogger.logException(
                    e,
                    StayAndEarnApexConstants.PROCESS_NAME_MEMBER_STAY_API_EXTRACT,
                    null,
                    ApexConstants.ERROR,
                    StayAndEarnApexConstants.LOG_LEVEL_WARNING,
                    StayAndEarnApexConstants.LOG_MSG_URL_DECODE_STAY_ID_PREFIX + originalStayId + StayAndEarnApexConstants.LOG_MSG_URL_DECODE_STAY_ID_SUFFIX + uri
                );
            }
        }
        
        return String.isNotBlank(stayId) ? stayId : null;
    }

}