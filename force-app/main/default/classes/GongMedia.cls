/**
 * @class GongMediaViewerController
 * @description Controller class for rendering Gong media (video/audio) on a Visualforce page.
 *              Attempts to generate a presigned S3 URL for a media file (video preferred, falls back to audio)
 *              based on the Gong Call ID retrieved from the provided record ID.
 */

public with sharing class GongMedia {
    public static string GONG_MEDIA_EXTARNAL_URL = 'Gong_MediaExternalUrl';
    /**
     * @property fileKey
     * @description The constructed S3 key for the Gong media file (e.g., "video/{callId}.mp4" or "audio/{callId}.mp3").
     */
    public String fileKey { get; private set; }

    /**
     * @property videoUrl
     * @description The presigned URL returned from AWS S3 for the video/audio file. Marked transient to avoid view state issues.
     */
    public transient String videoUrl { get; private set; }

    /**
     * @constructor GongMediaViewerController
     * @description Initializes the controller by retrieving the Gong Call record using the passed record ID.
     *              Attempts to fetch the presigned URL for the video file first; if not found, falls back to audio.
     */
    public GongMedia() {
       String recordId = ApexPages.currentPage().getParameters().get('id');
        if (String.isBlank(recordId)) {
            addError('No record ID provided');
            return;
        }
        try {
            system.debug('ID :' + recordId);
            List<Gong__Gong_Call__c> gongCalls = [
                SELECT Gong__Call_ID__c 
                FROM Gong__Gong_Call__c 
                WHERE Id = :recordId
                LIMIT 1
            ];

            if (gongCalls.isEmpty()) {
                addError('Record not found');
                return;
            }

            String callId = gongCalls[0].Gong__Call_ID__c;
            fileKey = 'video/' + callId + '.mp4';
            // videoUrl = getPresignedUrl(fileKey);
            TransactionResponse res = getPresignedUrl(fileKey);
            videoUrl = res.url;
            if (videoUrl == null) {
                fileKey = 'audio/' + callId + '.mp3';
                videoUrl = getPresignedUrl(fileKey);
                if (videoUrl == null) {
                  addError('Neither video nor audio file could be retrieved.');
                }
            }
        } catch (Exception e) {
            addError('Error: ' + e.getMessage());
        }
    }


    public static TransactionResponse getPresignedUrl(String fileKey) {
        // List<TransactionResponse> responses = new List<TransactionResponse>();
        TransactionResponse response  = new TransactionResponse();
        final Integer MAX_ATTEMPTS = 3;
        final Integer RETRY_DELAY_MS = 1000;
        HttpResponse res;
        String errorMessage = '';
        String endPoint = OrgSettingHelpers.getString(GONG_MEDIA_EXTARNAL_URL, '/prod/generate-mediafile-presigned-url');
      Integer calloutAttempts = 0;
      try {
        do {
            req.setEndpoint('callout:Gong_Media_Url' + endPoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(new Map<String, String>{ 'file_key' => fileKey }));
            req.setTimeout(10000);

            res = new Http().send(req);
            Integer calloutAttempted = Limits.getCallouts();
            System.debug('====calloutAttempted===' + calloutAttempted);
        if (calloutAttempted >= 100)
            break;
          res = http.send(req);
          response.statusCode = res.getStatusCode();
          response.responseBody = res.getBody();
          System.debug('====response===' + res);
        } while (res.getStatusCode() != 200 && calloutAttempts++ < 10);

        if (res.getStatusCode() == 200) {
          response.success = true;
          response.message = 'Transaction processed successfully.';
        } else {
          response.success = false;
          response.message = 'Failed with HTTP status ' + res.getStatusCode();
        }
      } catch (Exception e) {
        response.success = false;
        response.message = 'Exception: ' + e.getMessage();
        response.statusCode = 500;
        response.responseBody = null;
      }
      return responses;
    }  


    // Output class for response
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