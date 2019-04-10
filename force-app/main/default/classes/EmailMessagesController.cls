public with sharing class EmailMessagesController {

    @AuraEnabled(Cacheable=true)
    public static List<EmailMessage> getEmailsSent() {
        return [SELECT Id, BccAddress, CcAddress, EmailTemplateId, FromAddress, FromName, HasAttachment, HtmlBody, MessageDate, RelatedToId, Status, Subject, TextBody, ToAddress FROM EmailMessage ORDER BY MessageDate DESC LIMIT 100];
    }

    @AuraEnabled(Cacheable=true)
    public static EmailMessage getEmailById(Id emailId) {
        return [SELECT Id, BccAddress, CcAddress, EmailTemplateId, FromAddress, FromName, HasAttachment, HtmlBody, MessageDate, RelatedToId, Status, Subject, TextBody, ToAddress FROM EmailMessage WHERE Id = :emailId];
    }

}