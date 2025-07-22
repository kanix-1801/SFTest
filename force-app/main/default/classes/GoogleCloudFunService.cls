public with sharing class GoogleCloudFunService {

    private static final String CERTIFICATE_NAME = 'GCPAccessCredentials'; 
    private static final String SERVICE_ACCOUNT_EMAIL = 'access-salesforce@client-aurora-gong.iam.gserviceaccount.com';
    private static final String GOOGLE_TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';
    private static final String GCF_FUNCTION_URL = 'https://us-central1-client-aurora-gong.cloudfunctions.net/get-signed-audio-url';
    private static String cachedIdToken = null;
    private static Long tokenExpiryTime = 0L;

private static String getGoogleIdToken(String funcName) {

        // 1. Construct JWT Header

        Map<String, String> jwtHeader = new Map<String, String>();

            jwtHeader.put('alg', 'RS256');

        jwtHeader.put('typ', 'JWT');
 
        Long now = System.currentTimeMillis() / 1000; 

        Long exp = now + 3600;
 
        Map<String, Object> jwtClaims = new Map<String, Object>();

        jwtClaims.put('iss', SERVICE_ACCOUNT_EMAIL);

        jwtClaims.put('sub', SERVICE_ACCOUNT_EMAIL); 

        jwtClaims.put('aud', GOOGLE_TOKEN_ENDPOINT); 

        jwtClaims.put('exp', exp); 

        jwtClaims.put('iat', now); 

        if(funcName == 'getCallTranscripts') jwtClaims.put('target_audience', GCP_Fetch_Transcript_URL);

        else if(funcName == 'getSignedAudioUrl') jwtClaims.put('target_audience', GCF_FUNCTION_URL );


        String headerBase64 = base64UrlEncodeBlob(Blob.valueOf(JSON.serialize(jwtHeader)));

        String claimsBase64 = base64UrlEncodeBlob(Blob.valueOf(JSON.serialize(jwtClaims)));

        String unsignedJwt = headerBase64 + '.' + claimsBase64;
 
        Blob signature = Crypto.signWithCertificate('RSA-SHA256', Blob.valueOf(unsignedJwt), CERTIFICATE_NAME);

        String signatureBase64 = base64UrlEncodeBlob(signature);
 
        String signedJwt = unsignedJwt + '.' + signatureBase64;

        System.debug('Generated Signed JWT: ' + signedJwt);
 
        HttpRequest tokenRequest = new HttpRequest();

        tokenRequest.setEndpoint(GOOGLE_TOKEN_ENDPOINT);

        tokenRequest.setMethod('POST');

        tokenRequest.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        tokenRequest.setBody('grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' + signedJwt);
 
        Http http = new Http();

        HttpResponse tokenResponse = http.send(tokenRequest);
 
        if (tokenResponse.getStatusCode() == 200) {

            Map<String, Object> tokenResponseBody = (Map<String, Object>) JSON.deserializeUntyped(tokenResponse.getBody());

            String idToken = (String) tokenResponseBody.get('id_token');

            if (idToken == null) {

                throw new CalloutException('ID Token not found in Google response. Response: ' + tokenResponse.getBody());

            }

            System.debug('Successfully obtained ID Token.');

            return idToken;

        } else {

            String errorMessage = 'Failed to exchange JWT for ID Token: ' + tokenResponse.getStatusCode() + ' - ' + tokenResponse.getStatus();

            System.debug(errorMessage + '\nResponse Body: ' + tokenResponse.getBody());

            throw new CalloutException(errorMessage + '\nDetails: ' + tokenResponse.getBody());

        }

    }
 

}