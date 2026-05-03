public with sharing class MarketEventNewsController {

    @AuraEnabled(cacheable=true)
    public static Market_Event__c getLatestNegativeEvent() {
        return [
            SELECT Id, Name, News_Title__c, News_Summary__c, News_Suggestion__c, Industry__c,High_Count__c, Medium_Count__c, Low_Count__c,Impact_Score__c,Impact_Percentage__c
            FROM Market_Event__c
            WHERE Sentiment__c = 'Negative'
            ORDER BY Event_Processed_Time__c DESC
            LIMIT 1
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Customer_Portfolio_Summary__c> getImpactedCustomers(String level, String industry) {

        String fieldName = getFieldByIndustry(industry);
        if(String.isBlank(fieldName) || String.isBlank(level)){
            return new List<Customer_Portfolio_Summary__c>();
        }

        String condition = '';

        if(level == 'High'){
            condition = fieldName + ' > 30';
        } 
        else if(level == 'Medium'){
            condition = fieldName + ' >= 20 AND ' + fieldName + ' <= 30';
        } 
        else if(level == 'Low'){
            condition = fieldName + ' < 20';
        }
        String query = 'SELECT Id, Customer_Name__c, Total_Portfolio__c, ' + fieldName +
                       ' FROM Customer_Portfolio_Summary__c ' +
                       'WHERE ' + fieldName + ' != NULL AND ' + condition +
                       ' ORDER BY ' + fieldName + ' DESC LIMIT 200';

        return Database.query(query);
    }
    private static String getFieldByIndustry(String industry) {

        if(industry == null) return null;

        industry = industry.toLowerCase().trim();
        if(industry.contains('it') || industry.contains('tech') || industry.contains('technology'))
            return 'Technology_Percentage__c';

        if(industry.contains('bank') || industry.contains('financial'))
            return 'Financials_Percentage__c';

        if(industry.contains('pharma') || industry.contains('health'))
            return 'Healthcare_Percentage__c';

        if(industry.contains('fmcg'))
            return 'FMCG_Percentage__c';

        if(industry.contains('energy'))
            return 'Energy_Percentage__c';

        if(industry.contains('telecom'))
            return 'Telecom_Percentage__c';

        if(industry.contains('industrial'))
            return 'Industrials_Percentage__c';

        if(industry.contains('material'))
            return 'Materials_Percentage__c';

        if(industry.contains('utility'))
            return 'Utilities_Percentage__c';

        return null;
    }

@AuraEnabled
public static void notifyCustomer(Id customerId) {
    System.debug('Notify customer: ' + customerId);
}
@AuraEnabled
public static Id findAccountByName(String customerName) {

    if(String.isBlank(customerName)) return null;

    List<Account> acc = [
        SELECT Id
        FROM Account
        WHERE Name LIKE :('%' + customerName + '%')
        LIMIT 1
    ];

    return acc.isEmpty() ? null : acc[0].Id;
}
@AuraEnabled
public static void runEmailFlow(String recordId) {

    if (String.isBlank(recordId)) {
        throw new AuraHandledException('RecordId is missing');
    }

    try {
        Map<String, Object> inputs = new Map<String, Object>{
            'recordId' => recordId
        };

        Flow.Interview.Market_Email_Notify flow =
            new Flow.Interview.Market_Email_Notify(inputs);

        flow.start();

    } catch (Exception e) {
        throw new AuraHandledException('Flow execution failed: ' + e.getMessage());
    }
}
@AuraEnabled
public static void runWhatsAppFlow(String recordId) {

    if (String.isBlank(recordId)) {
        throw new AuraHandledException('RecordId is missing');
    }

    try {
        Map<String, Object> inputs = new Map<String, Object>{
            'recordId' => recordId
        };

        Flow.Interview.Whatsapp_Message_Notify flow =
            new Flow.Interview.Whatsapp_Message_Notify(inputs);

        flow.start();

    } catch (Exception e) {
        throw new AuraHandledException('WhatsApp Flow failed: ' + e.getMessage());
    }
}
}