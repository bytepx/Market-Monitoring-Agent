public with sharing class MarketEventPromptUpdater {

    public class Input {
        @InvocableVariable(required=true)
        public Id marketEventId;

        @InvocableVariable(required=true)
        public String promptResponse;
    }

    @InvocableMethod(label='Update Market Event From Prompt JSON')
    public static void updateFromPrompt(List<Input> inputs) {

        List<Market_Event__c> updates = new List<Market_Event__c>();

        for (Input inRec : inputs) {

            if (String.isBlank(inRec.promptResponse)) continue;

            Map<String, Object> parsed =
                (Map<String, Object>) JSON.deserializeUntyped(inRec.promptResponse);

            Market_Event__c me = new Market_Event__c();
            me.Id = inRec.marketEventId;

            me.News_Title__c = (String) parsed.get('newsTitle');
            me.News_Summary__c = (String) parsed.get('newsSummary');
            me.News_Suggestion__c = (String) parsed.get('newsSuggestion');

            updates.add(me);
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }
}