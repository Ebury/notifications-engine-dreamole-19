public with sharing class NotificationsServiceV1 {

    /**
     * Streamlines creating and sending Salesforce standard Messaging.SingleEmailMessage
     *
     * How to use it example:

        new NotificationsServiceV1.SingleEmail()
           .to(toRecipients)
           .ccTo(ccRecipients)
           .withBody(body)
           .withSubject(subject)
           .send();
     */
    public class SingleEmail {
        private Messaging.SingleEmailMessage salesforceEmailMessage;

        public SingleEmail() {
            this.salesforceEmailMessage = new Messaging.SingleEmailMessage();
        }

        public SingleEmail to(List<String> toAddresses) {
            salesforceEmailMessage.setToAddresses(toAddresses);

            // Emails can be sent to users when the targetObjectId or the ToAddresses field are Ids pointing
            // to User records. However, Salesforce throws an error if the emails are to be sent to users and saveAsActivity = true
            if (isAddressPointingToUsers(salesforceEmailMessage)) {
                salesforceEmailMessage.setSaveAsActivity(false);
            }
            return this;
        }

        public SingleEmail to(String toAddress) {
            return this.to(new List<String> {toAddress});
        }

        public SingleEmail ccTo(List<String> ccAddresses) {
            salesforceEmailMessage.setCcAddresses(ccAddresses);
            return this;
        }

        public SingleEmail ccTo(String ccAddress) {
            this.ccTo(new List<String> {ccAddress});
            return this;
        }

        public SingleEmail withBody(String body) {
            salesforceEmailMessage.setPlainTextBody(body);
            return this;
        }

        public SingleEmail withRichTextBody(String htmlBody) {
            salesforceEmailMessage.setHtmlBody(htmlBody);
            return this;
        }

        public SingleEmail withSubject(String subject) {
            salesforceEmailMessage.setSubject(subject);
            return this;
        }

        // Optional, but recommended. Good practice to consider when sending to users:
        // "Emails sent using setTargetObjectId() set against the user object do not count against the SingleEmailMessage limit."
        public SingleEmail relatedToObjectId(Id targetObjectId) {

            salesforceEmailMessage.setTargetObjectId(targetObjectId);

            // Emails can be sent to users when the targetObjectId or the ToAddresses field are Ids pointing
            // to User records. However, Salesforce throws an error if the emails are to be sent to users and saveAsActivity = true
            if (isTheTargetObjectAUser(salesforceEmailMessage)) {
                salesforceEmailMessage.setSaveAsActivity(false);
            }
            return this;
        }

        // Optional - Default empty. It builds the appropriate List<Messaging.EmailFileAttachment> if any.
        public SingleEmail withAttachments(List<Attachment> attachments) {

            if (attachments != null && !attachments.isEmpty()) {

                List<Messaging.EmailFileAttachment> emailFileAttachments = new List<Messaging.EmailFileAttachment>();
                for (Attachment attachment : attachments) {
                    Messaging.EmailFileAttachment emailFileAttachment = new Messaging.EmailFileAttachment();
                    emailFileAttachment.setFileName(attachment.Name);
                    emailFileAttachment.setBody(attachment.Body);
                    emailFileAttachments.add(emailFileAttachment);
                }
                salesforceEmailMessage.setFileAttachments(emailFileAttachments);
            }
            return this;
        }

        // It can be a template Id or its API name
        public SingleEmail usingTemplate(String templateIdOrName) {

            if (String.isBlank(templateIdOrName)) {
                return this;
            }

            Id templateId;
            if (templateIdOrName instanceof Id) {
                templateId = templateIdOrName;
            } else {
                // Not catching exceptions for simplicity
                templateId = EmailTemplatesSelector.getInstance()
                        .getByDeveloperNameFromCache(templateIdOrName).Id;
            }

            salesforceEmailMessage.setTemplateId(templateId);

            return this;
        }

        // Optional but encouraged if relatedToObjectId is used. The usual WhatId field
        public SingleEmail usingObjectIdForTemplateMerge(Id whatId) {
            salesforceEmailMessage.setWhatId(whatId);
            return this;
        }

        public List<Messaging.SendEmailResult> send() {

            List<Messaging.SendEmailResult> emailResults =
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[]{
                            this.salesforceEmailMessage
                    });

            return emailResults;
        }
    }

    private static Boolean isTheTargetObjectAUser(Messaging.SingleEmailMessage salesforceEmail) {
        Id targetObjectId = salesforceEmail.getTargetObjectId();
        return isIdOfUserType(targetObjectId);
    }

    private static Boolean isAddressPointingToUsers(Messaging.SingleEmailMessage salesforceEmail) {

        List<String> toAddresses = salesforceEmail.getToAddresses();
        if (toAddresses != null && !toAddresses.isEmpty()) {
            // Not considering mixed types of destination users
            String address = toAddresses[0];
            if (address instanceof Id) {
                return isIdOfUserType(address);
            }
        }

        return false;
    }

    private static Boolean isIdOfUserType(Id targetObjectId) {
        return (targetObjectId != null && targetObjectId.getSobjectType() == User.SObjectType);
    }
}