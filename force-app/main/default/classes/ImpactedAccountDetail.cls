public class ImpactedAccountDetail {
    // Required for Flow visibility
    @AuraEnabled @InvocableVariable(label='Email Address') 
    public String email;

    @AuraEnabled @InvocableVariable(label='Account Name') 
    public String accountName;
    @AuraEnabled @InvocableVariable(label='AccountId') 
    public String accountId;
    @AuraEnabled @InvocableVariable(label='Stocks') 
    public String stocks;

    @AuraEnabled @InvocableVariable(label='Impact Amount') 
    public Decimal impactAmount;

    // Required: A constructor with no arguments
    public ImpactedAccountDetail() {}
}