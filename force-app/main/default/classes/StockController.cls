public with sharing class StockController {
    @AuraEnabled(cacheable=false)
    public static List<StockWrapper> getStockData(Id accountId) {
        // Step 1: Get PAN
        Account acc = [SELECT PAN__c FROM Account WHERE Id = :accountId LIMIT 1];

        if (String.isBlank(acc.PAN__c)) {
            throw new AuraHandledException('PAN not found on Account');
        }

        // Step 2: Get Holdings
        List<DematHolding__dlm> holdings = [SELECT Id, Ticker__c, BuyPrice__c FROM DematHolding__dlm WHERE PAN_Number__c = :acc.PAN__c];

        List<StockWrapper> results = new List<StockWrapper>();

        Http http = new Http();

        for (DematHolding__dlm h : holdings) {
            Decimal currentPrice;
            Boolean apiSuccess = false;

            try {
                HttpRequest req = new HttpRequest();
                String endpoint = 'https://stock.indianapi.in/stock?name=' + EncodingUtil.urlEncode(h.Ticker__c, 'UTF-8');

                req.setEndpoint(endpoint);
                req.setMethod('GET');
                req.setHeader('x-api-key', 'sk-live-DDUabdGc8y1OcPc3eqgwte4hFNiM81HbW0sSCQCq');
                req.setHeader('accept', 'application/json');
                req.setTimeout(5000);

                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                    // Handle API error
                    if (data.containsKey('error')) {
                        currentPrice = h.BuyPrice__c;
                    } else if (data.containsKey('currentPrice')) {
                        Map<String, Object> priceMap = (Map<String, Object>) data.get('currentPrice');

                        if (priceMap != null && priceMap.containsKey('NSE')) {
                            currentPrice = Decimal.valueOf((String) priceMap.get('NSE'));
                            apiSuccess = true;
                        }
                    }
                }
            } catch (Exception e) {
                System.debug('Exception for ticker ' + h.Ticker__c + ': ' + e.getMessage());
            }

            if (!apiSuccess || currentPrice == null) {
                currentPrice = h.BuyPrice__c;
            }

            results.add(new StockWrapper(h.Ticker__c, currentPrice, h.BuyPrice__c, (currentPrice - h.BuyPrice__c)));
        }

        return results;
    }

    public class StockWrapper {
        @AuraEnabled
        public String ticker;
        @AuraEnabled
        public Decimal currentPrice;
        @AuraEnabled
        public Decimal buyPrice;
        @AuraEnabled
        public Decimal gainLoss;

        public StockWrapper(String t, Decimal c, Decimal b, Decimal g) {
            ticker = t;
            currentPrice = c;
            buyPrice = b;
            gainLoss = g;
        }
    }
}