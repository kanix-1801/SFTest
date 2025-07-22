/**
 * @class GongMediaViewerController
 * @description Controller class for rendering Gong media (video/audio) on a Visualforce page.
 *              Attempts to generate a presigned S3 URL for a media file (video preferred, falls back to audio)
 *              based on the Gong Call ID retrieved from the provided record ID.
 */
public with sharing class GongMediaViewerControllerNew {

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
    public GongMediaViewerControllerNew() {
        String recordId = ApexPages.currentPage().getParameters().get('id');
        system.debug('recordId :' + recordId);
        if (String.isBlank(recordId)) {
            system.debug('recordId :' + recordId);
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
             system.debug('fileKey :' + fileKey);
            videoUrl = getPresignedUrl(fileKey);
            system.debug('videoUrl :' + videoUrl);
            if (videoUrl == null) {
                fileKey = 'audio/' + callId + '.mp3';
                videoUrl = getPresignedUrl(fileKey);
                system.debug('videoUrl :' + videoUrl);

                if (videoUrl != null) {
                    system.debug('videoUrl :' + videoUrl);
                  // ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Fallback to audio file.'));
                } else {
                    addError('Neither video nor audio file could be retrieved.');
                }
            }

        } catch (Exception e) {
            addError('Error: ' + e.getMessage());
        }
    }

    /**
     * @method getPresignedUrl
     * @description Makes a POST callout to the configured endpoint to fetch a presigned S3 URL for a given file key.
     *              Retries on transient errors (408, 429, 5xx) up to 3 attempts.
     * @param fileKey The path of the file in S3 (e.g., "video/{callId}.mp4").
     * @return A presigned URL string if successful, or null if the file is not found (404).
     * @throws CalloutException If all retry attempts fail or a non-retryable error is encountered.
     */
    public Static String getPresignedUrl(String fileKey) {
        final Integer MAX_ATTEMPTS = 3;
        final Integer RETRY_DELAY_MS = 1000;
        HttpResponse res;
        String errorMessage = '';
        // GongExternalurls__c endpoints = GongExternalurls__c.getInstance();
        String endPoint = OrgSettingHelpers.getString(GONG_MEDIA_EXTARNAL_URL, '/prod/generate-mediafile-presigned-url');

        for (Integer attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
            try {
                HttpRequest req = new HttpRequest();
                system.debug('endPoint :' + endPoint);
               // req.setEndpoint('callout:Gong_presigned_url' + endPoint);
               req.setEndpoint('callout:Gong_Media_Url' + endPoint);
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setBody(JSON.serialize(new Map<String, String>{ 'file_key' => fileKey }));
                req.setTimeout(10000);

                res = new Http().send(req);

                // Handle 200 Success
                if (res.getStatusCode() == 200) {
                    Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                        system.debug((String) response.get('url'));
                    if (response.containsKey('url')) {
                        return (String) response.get('url');
                    }
                } 
                // Explicitly handle 404 (Not Found)
                else if (res.getStatusCode() == 404) {
                    return null; 
                }
                // Retry on transient errors
                else if (res.getStatusCode() == 408 || res.getStatusCode() == 429 || res.getStatusCode() >= 500) {
                    errorMessage = 'HTTP ' + res.getStatusCode() + ' - ' + res.getStatus();
                }
                else {
                    throw new CalloutException('HTTP ' + res.getStatusCode() + ' - ' + res.getStatus());
                }

            } catch (Exception e) {
                errorMessage = 'Exception: ' + e.getMessage();
                // Retry only on timeout/network issues
                if (!e.getMessage().contains('TIMED_OUT')) {
                    throw e;
                }
            }
            if (attempt < MAX_ATTEMPTS) {
                Long start = DateTime.now().getTime();
                while (DateTime.now().getTime() - start < RETRY_DELAY_MS) {}
            }
        }
        throw new CalloutException(errorMessage);
    }

    /**
     * @method addError
     * @description Utility method to add an error message to the Visualforce page's message area.
     * @param msg The message string to display.
     */
    private void addError(String msg) {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, msg));
    }
}