public with sharing class Arora{
    public String fileKey {get; set;}
    public transient String videoUrl {get; set;} // transient

    public Arora(){
        String recordId = ApexPage.currentPage().getParameters().get('id');

        System.debug('Hello from the Arora');
        if(String.isBlank(recordId)){ // String.isBank()
            addError('No record Id found. '); // addError
        }

        try{
            List <Gong__Gong_Call__c> gongCalls = [
                SELECT Id, Gong__Call_ID__c
                FROM Gong__Gong_Call__c
                WHERE Id = :recordId
                LIMIT 1
            ]; // get the gong call id by the gong call record id.

            System.debug('gongCalls: ' + gongCalls.size() + ' : ' + gongCalls);
            if(gongCalls.isEmpty()){
                addError('No record found.'); // addError
                return;
            }

            if(gongCalls[0].Gong__Call_ID__c != null){
                addError('Call ID is missing in the record');
                return;
            }
        }

    }
}