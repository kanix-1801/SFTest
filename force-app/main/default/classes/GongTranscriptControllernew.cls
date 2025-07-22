/**
 * @class GongTranscriptController
 * @description Calls AWS Lambda via API Gateway to fetch transcript lines for a given Gong Call ID.
 */
public with sharing class GongTranscriptController {
    public static string GONG_TRANSCRIPT_EXTARNAL_URL = 'Gong_TranscriptExternalurl';
    public String callId { get; set; }
    public List<TranscriptLine> transcript { get; set; }
    public String errorMessage { get; set; }
    public Boolean hasError { get; set; }

    public GongTranscriptController() {
        this.transcript = new List<TranscriptLine>();
        this.hasError = false;

        String recordId = ApexPages.currentPage().getParameters().get('id');
        if (String.isNotBlank(recordId)) {
            fetchCallTranscript(recordId);
        } else {
            setError('No record ID provided');
        }
    }

    private void fetchCallTranscript(String recordId) {
        try {
            List<Gong__Gong_Call__c> callList = [
                SELECT Gong__Call_ID__c 
                FROM Gong__Gong_Call__c 
                WHERE Id = :recordId 
                LIMIT 1
            ];

            if (callList.isEmpty() || String.isBlank(callList[0].Gong__Call_ID__c)) {
                setError('Call ID not found');
                return;
            }

            Gong__Gong_Call__c call = callList[0];
            this.callId = call.Gong__Call_ID__c;

            String responseBody = performTranscriptCallout(this.callId);
            this.transcript = (List<TranscriptLine>) JSON.deserialize(responseBody, List<TranscriptLine>.class);

        } catch (Exception e) {
            setError('Exception: ' + e.getMessage());
        }
    }

    /**
     * @method performTranscriptCallout
     * @description Sends POST request to API Gateway and returns the response body
     */
    private String performTranscriptCallout(String callId) {
        final Integer MAX_ATTEMPTS = 3;
        final Integer RETRY_DELAY_MS = 1000;
        Exception lastException = null;
        
        //GongExternalurls__c endpoints = GongExternalurls__c.getInstance();
        String endPoint = OrgSettingHelpers.getString(GONG_TRANSCRIPT_EXTARNAL_URL, '/default/gong-fetch-transcript-by-callid');
        
        for (Integer attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:Gong_Transcript' + endPoint);
                // req.setEndpoint('callout:Gong_Transcript_API' + endPoint);
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setBody(JSON.serialize(new Map<String, String>{ 'callId' => callId }));
                req.setTimeout(10000);

                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    system.debug(JSON.serialize(res.getBody()));
                    return res.getBody();
                } else if (attempt < MAX_ATTEMPTS) {
                    
                    Long startTime = DateTime.now().getTime();
                    while (DateTime.now().getTime() < startTime + RETRY_DELAY_MS) {
                        
                    }
                } else {
                    throw new CalloutException('HTTP ' + res.getStatusCode() + ': ' + res.getBody());
                }
            } catch (Exception e) {
                lastException = e;
                if (attempt < MAX_ATTEMPTS) {
                    // Only delay if we're going to retry
                    Long startTime = DateTime.now().getTime();
                    while (DateTime.now().getTime() < startTime + RETRY_DELAY_MS) {
                        // Busy wait for the delay period
                    }
                }
            }
        }
        
        if (lastException != null) {
            throw lastException;
        } else {
            throw new CalloutException('Failed after ' + MAX_ATTEMPTS + ' attempts');
        }
    }

    private void setError(String msg) {
        this.errorMessage = msg;
        this.hasError = true;
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, msg));
    }

    public class TranscriptLine {
        public String timestamp { get; set; }
        public String speaker { get; set; }
        public String text { get; set; }
    }
    
    public class TransactionResponse {
    @InvocableVariable
    public Boolean success;

    @InvocableVariable
    public Integer statusCode;

    @InvocableVariable
    public String message;

    @InvocableVariable
    public String responseBody;

    }
}