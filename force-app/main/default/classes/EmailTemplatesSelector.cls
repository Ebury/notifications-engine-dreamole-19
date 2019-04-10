/**
 *  Selector pattern to handle database requests for the EmailTemplate SObject.
 *  https://trailhead.salesforce.com/en/content/learn/modules/apex_patterns_dsl/apex_patterns_dsl_learn_selector_l_principles
 *
 *  It is based on the mapper pattern described in the EAA Patterns
 *  https://www.martinfowler.com/eaaCatalog/dataMapper.html
 */
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