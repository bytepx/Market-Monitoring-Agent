public class TwilioWhatsAppService {

    public static void sendSingle(String phone, String message){

        Whatsapp_Creds__c creds = Whatsapp_Creds__c.getInstance();

        if(creds == null || String.isBlank(creds.Account_Sid__c) || String.isBlank(creds.Account_Token__c)){
            return;
        }

        String accountSid = creds.Account_Sid__c;
        String authToken = creds.Account_Token__c;

        HttpRequest req = new HttpRequest();

        req.setEndpoint(
            'https://api.twilio.com/2010-04-01/Accounts/' + accountSid + '/Messages.json'
        );

        req.setMethod('POST');

        String auth = accountSid + ':' + authToken;
        String encodedAuth = EncodingUtil.base64Encode(Blob.valueOf(auth));

        req.setHeader('Authorization', 'Basic ' + encodedAuth);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        String body = 'To=' + EncodingUtil.urlEncode('whatsapp:' + phone, 'UTF-8') +
                      '&From=' + EncodingUtil.urlEncode('whatsapp:+14155238886', 'UTF-8') +
                      '&Body=' + EncodingUtil.urlEncode(message, 'UTF-8');

        req.setBody(body);

        Http http = new Http();
        HttpResponse res = http.send(req);
    }
}