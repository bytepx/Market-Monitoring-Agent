public class TwilioWhatsAppService {

    public static void sendSingle(String phone, String message){

        String accountSid = 'ACeea35a03ac5b87e3919cc184127e3247';
        String authToken = 'a58ee6cbf3dbac120e25427ff0f70dae';

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

        System.debug(res.getBody());
    }
}