public with sharing class AgentSendWhatsApp {

    @InvocableMethod(label='Send WhatsApp Message')
    public static List<ResponseWrapper> send(List<RequestWrapper> requests){

        List<ResponseWrapper> responses = new List<ResponseWrapper>();

        for(RequestWrapper req : requests){

            ResponseWrapper res = new ResponseWrapper();

            try {
                if(String.isBlank(req.phone)){
                    res.status = 'Failed: Phone is missing';
                }
                else if(String.isBlank(req.message)){
                    res.status = 'Failed: Message is empty';
                }
                else{
    				String formattedPhone = req.phone.startsWith('+') 
        			? req.phone 
        			: '+91' + req.phone;
    				String msg = req.message;

    			if(msg.length() > 1500){
       			 msg = msg.substring(0, 1500);
    			}

    		TwilioWhatsAppService.sendSingle(
        	formattedPhone,
        	msg
    	);

    res.status = 'Message Sent';
}
            } catch(Exception e){
                res.status = 'Error: ' + e.getMessage();
            }

            responses.add(res);
        }

        return responses;
    }

    public class RequestWrapper {
        @InvocableVariable(required=true)
        public String message;

        @InvocableVariable(required=true)
        public String phone;
    }

    public class ResponseWrapper {
        @InvocableVariable
        public String status;
    }
}