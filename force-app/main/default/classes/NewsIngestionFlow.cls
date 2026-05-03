public class NewsIngestionFlow {
    public static void run() {
        Http http = new Http();
        HttpRequest req = new HttpRequest();

        req.setEndpoint('https://stock.indianapi.in/news');
        req.setMethod('GET');
        req.setHeader('X-API-KEY', 'sk-live-DDUabdGc8y1OcPc3eqgwte4hFNiM81HbW0sSCQCq');

        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            List<Object> articles = (List<Object>) JSON.deserializeUntyped(res.getBody());
            sendToDataCloud(articles);
        } else {
            System.debug('Failed to fetch news: ' + res.getBody());
        }
    }

    // STEP 1: CORE TOKEN
    public static String getCoreToken() {
        Http http = new Http();
        HttpRequest req = new HttpRequest();

        req.setEndpoint('https://orgfarm-62f436a022.my.salesforce.com/services/oauth2/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        String body = 'grant_type=client_credentials' + '&client_id=3MVG9JJwBBbcN47I8pBvIGVgGDYhTYtBCq_xo49DiLymVNs4pCpYB1EpjTzc9fRdM8s_f.BC1QM_ZgMw2cM16' + '&client_secret=0B9EBEAF41F3990D9432E899A5DD0004F4E7A1D5825F022E5B9BE968E49F23C2';

        req.setBody(body);

        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) result.get('access_token');
        }

        throw new CalloutException('Core token failed: ' + res.getBody());
    }

    // STEP 2: A360 TOKEN
    public static String getA360Token(String coreToken) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();

        // This endpoint may vary per org
        req.setEndpoint('https://orgfarm-62f436a022.my.salesforce.com/services/a360/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        String body = 'grant_type=urn:salesforce:grant-type:external:cdp' + '&subject_token=' + coreToken + '&subject_token_type=urn:ietf:params:oauth:token-type:access_token';
        req.setBody(body);
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            return (String) result.get('access_token');
        }

        throw new CalloutException('A360 token failed: ' + res.getBody());
    }

    // STEP 3: SEND TO DATA CLOUD
    public static void sendToDataCloud(List<Object> articlesInput) {
        // ---- GET TOKENS ----
        String coreToken = getCoreToken();
        String dcToken = getA360Token(coreToken);

        Http http = new Http();
        HttpRequest req = new HttpRequest();

        req.setEndpoint('https://my3tc9jwhfqwmnzwgq3wgzbsg0.c360a.salesforce.com/api/v1/ingest/sources/Indian_Stock_Market_API/Article');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + dcToken);

        List<Object> cleanedArticles = new List<Object>();

        for (Object obj : articlesInput) {
            Map<String, Object> item = (Map<String, Object>) obj;
            Map<String, Object> payload = new Map<String, Object>();

            // ---------- ID ----------
            String url = (String) item.get('url');
            String id = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(url)));

            payload.put('id', id);

            // ---------- BASIC ----------
            payload.put('title', item.get('title'));
            payload.put('summary', item.get('summary'));
            payload.put('url', url);
            payload.put('image', item.get('image_url'));
            payload.put('source', item.get('source'));

            String pubDate = (String) item.get('pub_date');
            if (pubDate != null) {
                pubDate = pubDate.replace(' ', 'T');
                if (!pubDate.endsWith('Z')) {
                    pubDate += 'Z';
                }
            } else {
                pubDate = System.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            }
            payload.put('event_time', pubDate);

            List<Object> topics = (List<Object>) item.get('topics');

            if (topics != null && !topics.isEmpty()) {
                List<String> topicStrings = new List<String>();

                for (Object t : topics) {
                    if (t != null)
                        topicStrings.add((String) t);
                }

                payload.put('topics', String.join(topicStrings, ','));
            } else {
                payload.put('topics', 'NA');
            }

            cleanedArticles.add(payload);
        }

        // ---------- WRAPPER ----------
        Map<String, Object> wrapper = new Map<String, Object>();
        wrapper.put('data', cleanedArticles);
        String body = JSON.serialize(wrapper);
        req.setBody(body);
        HttpResponse response = http.send(req);
    }
}