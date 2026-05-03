public with sharing class MarketEventIntelligenceAction {

    public class Input {
        @InvocableVariable(required=true)
        public Id marketEventId;
    }

    public class Output {
        @InvocableVariable public String industry;

        @InvocableVariable public Integer highCount;
        @InvocableVariable public Integer mediumCount;
        @InvocableVariable public Integer lowCount;

        @InvocableVariable public String positiveNewsTitle;
        @InvocableVariable public String positiveNewsSummary;

        @InvocableVariable public String promptPayload;
    }

    @InvocableMethod(label='Market Event Intelligence Processor')
    public static List<Output> process(List<Input> inputs) {

        List<Output> results = new List<Output>();

        // -------------------------------
        // 1. Load all customer portfolios ONCE (best practice)
        // -------------------------------
        List<Customer_Portfolio_Summary__c> customers = [
            SELECT Consumer_Discretionary_Percentage__c,
                   Financials_Percentage__c,
                   FMCG_Percentage__c,
                   Healthcare_Percentage__c,
                   Industrials_Percentage__c,
                   Materials_Percentage__c,
                   Technology_Percentage__c,
                   Telecom_Percentage__c,
                   Utilities_Percentage__c,
                   Energy_Percentage__c
            FROM Customer_Portfolio_Summary__c
        ];

        for (Input req : inputs) {

            Output out = new Output();

            // -------------------------------
            // 2. Fetch Market Event
            // -------------------------------
            Market_Event__c me = [
                SELECT Name,
                       Industry__c,
                       Sentiment__c,
                       Impact_Level__c,
                       News_Summary__c,
                       Reason__c
                FROM Market_Event__c
                WHERE Id = :req.marketEventId
                LIMIT 1
            ];

            String industry = normalizeIndustry(me.Industry__c);
            out.industry = industry;

            // -------------------------------
            // 3. Impact Calculation
            // -------------------------------
            Integer high = 0;
            Integer medium = 0;
            Integer low = 0;

            for (Customer_Portfolio_Summary__c c : customers) {

                Decimal ratio = getIndustryRatio(c, industry);

                if (ratio > 30) {
                    high++;
                } 
                else if (ratio >= 20) {
                    medium++;
                } 
                else {
                    low++;
                }
            }

            out.highCount = high;
            out.mediumCount = medium;
            out.lowCount = low;

            // -------------------------------
            // 4. Latest Positive News
            // -------------------------------
            List<Market_Event__c> posList = [
                SELECT Name, News_Summary__c
                FROM Market_Event__c
                WHERE Sentiment__c = 'Positive'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (!posList.isEmpty()) {
                out.positiveNewsTitle = posList[0].Name;
                out.positiveNewsSummary = posList[0].News_Summary__c;
            }

            // -------------------------------
            // 5. Build PROMPT PAYLOAD (FREE TEXT)
            // -------------------------------
            out.promptPayload =
                'MARKET EVENT TITLE: ' + me.Name + '\n' +
                'MARKET EVENT SUMMARY: ' + me.News_Summary__c + '\n' +
                'REASON: ' + me.Reason__c + '\n' +
                'IMPACT LEVEL: ' + me.Impact_Level__c + '\n' +
                'INDUSTRY: ' + industry + '\n' +
                'HIGH IMPACT CUSTOMERS: ' + high + '\n' +
                'MEDIUM IMPACT CUSTOMERS: ' + medium + '\n' +
                'LOW IMPACT CUSTOMERS: ' + low + '\n' +
                'POSITIVE NEWS TITLE: ' + out.positiveNewsTitle + '\n' +
                'POSITIVE NEWS SUMMARY: ' + out.positiveNewsSummary;

            results.add(out);
        }

        return results;
    }

    // -------------------------------
    // INDUSTRY NORMALIZATION
    // -------------------------------
    private static String normalizeIndustry(String industry) {

        if (industry == 'Conglomerate') return 'Telecom';
        if (industry == 'Digital') return 'Technology';
        if (industry == null) return 'Unknown';

        return industry;
    }

    // -------------------------------
    // INDUSTRY % MAPPING
    // -------------------------------
    private static Decimal getIndustryRatio(Customer_Portfolio_Summary__c c, String industry) {

        if (industry == 'FMCG') return c.FMCG_Percentage__c;
        if (industry == 'Financials') return c.Financials_Percentage__c;
        if (industry == 'Healthcare') return c.Healthcare_Percentage__c;
        if (industry == 'Consumer Discretionary') return c.Consumer_Discretionary_Percentage__c;
        if (industry == 'Industrials') return c.Industrials_Percentage__c;
        if (industry == 'Materials') return c.Materials_Percentage__c;
        if (industry == 'Technology') return c.Technology_Percentage__c;
        if (industry == 'Telecom') return c.Telecom_Percentage__c;
        if (industry == 'Utilities') return c.Utilities_Percentage__c;
        if (industry == 'Energy') return c.Energy_Percentage__c;

        return 0;
    }
}