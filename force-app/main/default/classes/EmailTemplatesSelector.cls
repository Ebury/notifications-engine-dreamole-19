public with sharing class EmailTemplatesSelector implements IEmailTemplatesSelector {

    // Replace this type by your "mocked" one for testing.
    @TestVisible private static IEmailTemplatesSelector selectorInstance;
    private static List<EmailTemplate> emailTemplatesCache;

    private EmailTemplatesSelector() {}

    public interface IEmailTemplatesSelector {
        List<EmailTemplate> getAll();
        EmailTemplate getByDeveloperNameFromCache(String developerName);
    }

    public static IEmailTemplatesSelector getInstance() {
        if (selectorInstance == null) {
            selectorInstance = new EmailTemplatesSelector();
        }
        return selectorInstance;
    }

    public List<EmailTemplate> getAll() {
        return [SELECT Id, DeveloperName FROM EmailTemplate];

    }

    public EmailTemplate getByDeveloperNameFromCache(String developerName) {

        if (emailTemplatesCache == null) {
            emailTemplatesCache = getAll();
        }

        for (EmailTemplate emailTemplate : emailTemplatesCache) {
            if (emailTemplate.DeveloperName == developerName) {
                return emailTemplate;
            }
        }

        return null;
    }


}