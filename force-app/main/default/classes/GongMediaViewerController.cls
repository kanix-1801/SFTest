public with sharing class GongMediaViewerController {
    public static String GONG_MEDIA_EXTERNAL_URL = 'Gong_MediaExternalUrl';
    
    public String fileKey { get; private set; }
    public transient String videoUrl { get; private set; }
    public Boolean hasError { get; private set; }
    public String errorMessage { get; private set; }

    public GongMediaViewerController() {
        String recordId = ApexPages.currentPage().getParameters().get('id');
        if (String.isBlank(recordId)) {
            addError('No record ID provided');
            return;
        }
        
        try {
            Gong__Gong_Call__c gongCall = [
                SELECT Gong__Call_ID__c 
                FROM Gong__Gong_Call__c 
                WHERE Id = :recordId
                LIMIT 1
            ];

            if (gongCall == null || String.isBlank(gongCall.Gong__Call_ID__c)) {
                addError('Gong Call record not found or missing Call ID');
                return;
            }

            String callId = gongCall.Gong__Call_ID__c;
            
            fileKey = 'video/' + callId + '.mp4';
            TransactionResponse videoResponse = getPresignedUrl(fileKey);
            
            if (videoResponse.success) {
                Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(videoResponse.responseBody);
                videoUrl = (String)responseMap.get('presignedUrl');
            }
            
            if (String.isBlank(videoUrl)) {
                fileKey = 'audio/' + callId + '.mp3';
                TransactionResponse audioResponse = getPresignedUrl(fileKey);
                
                if (audioResponse.success) {
                    Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(audioResponse.responseBody);
                    videoUrl = (String)responseMap.get('presignedUrl');
                }
            }
            if (String.isBlank(videoUrl)) {
                addError('Neither video nor audio file could be retrieved for this call');
            }
        } catch (QueryException qe) {
            addError('Database query error: ' + qe.getMessage());
        } catch (Exception e) {
            addError('Unexpected error: ' + e.getMessage() + ' [' + e.getTypeName() + ']');
        }
    }

    private void addError(String message) {
        hasError = true;
        errorMessage = message;
        System.debug(LoggingLevel.ERROR, 'GongMedia Error: ' + message);
    }

    private TransactionResponse getPresignedUrl(String fileKey) {
        final Integer MAX_ATTEMPTS = 3;
        String endPoint = OrgSettingHelpers.getString(GONG_MEDIA_EXTERNAL_URL, '/prod/generate-mediafile-presigned-url');
        String namedCredential = 'Gong_Media_Url';
        Http http = new Http();
        TransactionResponse response = new TransactionResponse();
        Integer attempt = 0;
        Boolean shouldRetry = true;

        do {
            attempt++;
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:' + namedCredential + endpoint);
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setBody(JSON.serialize(new Map<String, String>{ 'file_key' => fileKey }));
                req.setTimeout(12000);
                
                HttpResponse res = http.send(req);
                
                // Populate response object
                response.statusCode = res.getStatusCode();
                response.responseBody = res.getBody();
                
                if (res.getStatusCode() == 200) {
                    response.success = true;
                    response.message = 'Success';
                    shouldRetry = false;
                } 
                else if (res.getStatusCode() == 404) {
                    response.success = false;
                    response.message = 'File not found';
                    shouldRetry = false;
                }
                else {
                    response.success = false;
                    response.message = 'HTTP error: ' + res.getStatusCode();
                    shouldRetry = (attempt < MAX_ATTEMPTS);
                }
            } 
            catch (Exception e) {
                response.success = false;
                response.message = 'Exception: ' + e.getMessage();
                response.statusCode = 500;
                shouldRetry = (attempt < MAX_ATTEMPTS);
            }
            
            if (shouldRetry) {
                Integer delay = 300 * (Integer)Math.pow(2, attempt-1);
                Long start = System.now().getTime();
                while (System.now().getTime() < start + delay) { /* Busy wait */ }
            }
        } while (shouldRetry);
        return response;
    }

    public class TransactionResponse {
        public Boolean success;
        public Integer statusCode;
        public String message;
        public String responseBody;
    }
}