public without sharing class MarketImpactGrounder {
    
    /**
     * This method is called by Prompt Builder. 
     * It fetches market data and returns a JSON string for the LLM to process.
     */
    @InvocableMethod(label='Get Impacted Data for Prompt' category='Generative AI')
    public static List<Response> getImpactedData(List<Request> requests) {
        
        // 1. Get the latest Market Event
        Market_Event__c latestEvent = [SELECT Industry__c, Impact_Percentage__c, Sentiment__c 
                                       FROM Market_Event__c 
                                       ORDER BY CreatedDate DESC LIMIT 1];

        // 2. Map Market Industry to Demat Sectors
        Map<String, List<String>> industryMap = new Map<String, List<String>>{
            'IT' => new List<String>{'Technology'},
            'Pharma' => new List<String>{'Healthcare'},
            'Banking' => new List<String>{'Financials'},
            'FMCG' => new List<String>{'FMCG'},
            'Cement' => new List<String>{'Industrials', 'Materials'},
            'Conglomerate' => new List<String>{'Utilities'},
            'Energy' => new List<String>{'Energy'}
        };
        
        List<String> targetSectors = industryMap.get(latestEvent.Industry__c);
        if (targetSectors == null) targetSectors = new List<String>{latestEvent.Industry__c};

        // 3. Query Data Cloud (DLM) for PANs and Stock Info
        List<DematHolding__dlm> holdings = [SELECT PAN_Number__c, InstrumentName__c, CurrentPrice__c, Sector__c 
                                            FROM DematHolding__dlm  
                                            WHERE Sector__c IN :targetSectors 
                                            LIMIT 2000];

        if (holdings.isEmpty()) {
            Response emptyRes = new Response();
            emptyRes.prompt = '[]';
            return new List<Response>{ emptyRes };
        }

        // 4. Link to CRM Accounts via PAN
        Set<String> panSet = new Set<String>();
        for(DematHolding__dlm dh : holdings) { 
            if(String.isNotBlank(dh.PAN_Number__c)) panSet.add(dh.PAN_Number__c); 
        }
        
        Map<String, Account> panToAccountMap = new Map<String, Account>();
        for(Account a : [SELECT Name, PAN__c FROM Account WHERE PAN__c IN :panSet]) {
            panToAccountMap.put(a.PAN__c, a);
        }

        // 5. Aggregate Data into a List of Objects
        Map<String, ImpactData> resultMap = new Map<String, ImpactData>();
        for (DematHolding__dlm dh : holdings) {
            String panKey = dh.PAN_Number__c;
            if (String.isBlank(panKey)) continue;

            if (!resultMap.containsKey(panKey)) {
                ImpactData data = new ImpactData();
                data.accountName = panToAccountMap.containsKey(panKey) ? panToAccountMap.get(panKey).Name : 'New Client (PAN: ' + panKey + ')';
                data.industry = latestEvent.Industry__c;
                data.impactRate = latestEvent.Impact_Percentage__c;
                data.stocks = ''; 
                data.totalValue = 0;
                data.projectedImpact = 0;
                resultMap.put(panKey, data);
            }
            
            ImpactData current = resultMap.get(panKey);
            Decimal price = (dh.CurrentPrice__c != null) ? dh.CurrentPrice__c : 0;
            
            if (dh.InstrumentName__c != null && !current.stocks.contains(dh.InstrumentName__c)) {
                current.stocks += (current.stocks == '' ? '' : ', ') + dh.InstrumentName__c;
            }
            
            current.totalValue += price;
            current.projectedImpact += (price * (latestEvent.Impact_Percentage__c / 100));
        }

        // 6. Serialize to JSON and return in the 'prompt' field
        Response res = new Response();
        res.prompt = JSON.serialize(resultMap.values());
        
        return new List<Response>{ res };
    }

    public class Request {
        @InvocableVariable public String marketEventId;
    }

    public class Response {
        @InvocableVariable(label='Prompt Data' description='JSON string for Prompt Template')
        public String prompt;
    }

    // Structure for the JSON "Blob"
    public class ImpactData {
        public String accountName;
        public String stocks;
        public String industry;
        public Decimal impactRate;
        public Decimal totalValue;
        public Decimal projectedImpact;
    }
}