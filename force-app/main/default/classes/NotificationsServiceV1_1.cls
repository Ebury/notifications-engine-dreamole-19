public with sharing class NotificationsServiceV1_1 {

    /**
     * Streamlines creating and sending Salesforce standard Messaging.SingleEmailMessage.
     * This version of the class also includes tracking for the use cases Salesforce doesn't support out of the box
     *
     * How to use it example:

        new NotificationsServiceV1_1.SingleEmail()
           .to(toRecipients)
           .ccTo(ccRecipients)
           .withBody(body)
           .withSubject(subject)
           .send();
    */

    public enum TrackingMethod {
        SF_STANDARD,
        LOG_RECORD,
        DEBUG_LOG,
        NONE
    }

    // Classes that are aimed to notify someone (emails, chatter posts, ...).
    public interface INotifiable {
        // The object that transports the information (SingleEmailMessage, FeedItem, ...).
        Object getNotifiableObject();
    }

    public class SingleEmail implements INotifiable {

        private Messaging.SingleEmailMessage salesforceEmailMessage;

        public SingleEmail() {
            this.salesforceEmailMessage = new Messaging.SingleEmailMessage();
        }

        public SingleEmail to(List<String> toAddresses) {
            salesforceEmailMessage.setToAddresses(toAddresses);

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

        // You can opt to ask the message to send itself. It will ask the EmailHandler to use the EmailTrackingFactory by default.
        public List<Messaging.SendEmailResult> send() {
            return newEmailHandler(this)
                    .send();
        }

        public Object getNotifiableObject() {
            return this.salesforceEmailMessage;
        }
    }

    // Handy methods to ignore the details of the tracking factory injection.
    public static EmailHandler newEmailHandler(SingleEmail singleEmail) {
        return newEmailHandler(singleEmail, new EmailTrackingFactory());
    }

    public static EmailHandler newEmailHandler(SingleEmail singleEmail, ITrackingFactory trackingFactory) {
        return new EmailHandler(singleEmail, trackingFactory);
    }

    // Email handler ignores how to track messages. It delegates that work to a tracking system.
    // To do that, inject an ITrackingFactory that knows which kind of tracking make based on messages.
    // It defaults to EmailTrackingFactory.
    public class EmailHandler {
        private SingleEmail singleEmail;
        private Messaging.SingleEmailMessage salesforceEmail;
        private ITrackingFactory trackingFactory;
        private List<Messaging.SendEmailResult> emailResults;

        public EmailHandler(SingleEmail singleEmail, ITrackingFactory trackingFactory) {
            this.trackingFactory = trackingFactory == null ? new EmailTrackingFactory() : trackingFactory;
            this.singleEmail = singleEmail;
        }

        public List<Messaging.SendEmailResult> send() {
            dispatch();
            track();
            return this.emailResults;
        }

        private void dispatch() {
            this.salesforceEmail = (Messaging.SingleEmailMessage)this.singleEmail.getNotifiableObject();

            List<Messaging.SingleEmailMessage> salesforceEmails =
                    new List<Messaging.SingleEmailMessage> {
                            this.salesforceEmail
                    };

            this.emailResults = Messaging.sendEmail(salesforceEmails);
        }

        private void track() {
            if (emailResults[0].isSuccess()) {
                TrackingSystem trackingSystem = getTrackingSystemInstance();
                trackingSystem.track();
            }
        }

        private TrackingSystem getTrackingSystemInstance() {
            return trackingFactory.createTrackingSystem(this.salesforceEmail);
        }
    }

    // This method is used to determine if an email has to track the activity by SF Standard or we have to do it by our own
    private static Boolean isTheTargetObjectAUser(Messaging.SingleEmailMessage salesforceEmail) {
        Id targetObjectId = salesforceEmail.getTargetObjectId();
        return isIdOfUserType(targetObjectId);
    }

    // This method is used to determine if an email has to track the activity by SF Standard or we have to do it by our own
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

    /**
     * Tracking system classes
     */

    /**
     * Tracking factories determine which instance of tracking system to instantiate. In general, for other
     * notifications like a chatter post, you should just use the generic TrackingFactory. EmailTracking factory is
     * particular as it needs to cast the tracked entity to Messaging.SingleEmailMessage
     */
    public interface ITrackingFactory {
        TrackingSystem createTrackingSystem(Object trackableObject);
    }

    public class EmailTrackingFactory implements ITrackingFactory {

        public TrackingSystem createTrackingSystem(Object trackableObject) {

            Messaging.SingleEmailMessage salesforceEmail =
                    (Messaging.SingleEmailMessage) trackableObject;

            TrackingMethod trackingType = getTrackingMethod(salesforceEmail);

            if (trackingType == TrackingMethod.LOG_RECORD) {
                return (TrackingSystem) new EmailLogRecordTracking(trackableObject);
            } else {
                return (TrackingSystem) new EmailSaveAsActivityTracking(trackableObject);
            }
        }

        private TrackingMethod getTrackingMethod(Messaging.SingleEmailMessage salesforceEmail) {

            if (isTheTargetObjectAUser(salesforceEmail) || isAddressPointingToUsers(salesforceEmail)) {
                return TrackingMethod.LOG_RECORD;
            }

            return TrackingMethod.SF_STANDARD;
        }
    }

    public abstract class TrackingSystem {

        public virtual Object track() {
            return null;
        }

        public virtual Object createTrackingObject() {
            return null;
        }
    }

    /**
     * Specific Email tracking systems
     */
    public abstract class EmailTracking extends TrackingSystem {

        protected Messaging.SingleEmailMessage salesforceEmailMessage;

        public EmailTracking(Object trackableObject) {
            salesforceEmailMessage = (Messaging.SingleEmailMessage) trackableObject;
        }
    }

    public class EmailLogRecordTracking extends EmailTracking {

        public EmailLogRecordTracking(Object trackableObject) {
            super(trackableObject);
        }

        public override Object track() {
            EmailMessage emailMessageRecord = (EmailMessage) createTrackingObject();
            insert emailMessageRecord;

            return emailMessageRecord;
        }

        public override Object createTrackingObject() {

            EmailMessage emailMessageRecord = new EmailMessage();

            /**
             * As per Salesforce recommendations:
             * "If the recipient is a contact, lead, or user, add their ID to the ToIds field instead of adding
             * their email address to the ToAddress field. Then the email message is automatically associated with
             * the contact, lead, or user."
             * We will only manually track the emails sent to users.
             */
            emailMessageRecord.ToIds = new List<String>{salesforceEmailMessage.getTargetObjectId()};
            emailMessageRecord.FromName = UserInfo.getName();
            emailMessageRecord.FromAddress = UserInfo.getUserEmail();
            emailMessageRecord.ToAddress = String.join(salesforceEmailMessage.getToAddresses(), ', ');
            emailMessageRecord.CcAddress = salesforceEmailMessage.getCcAddresses() != null ? String.join(salesforceEmailMessage.getCcAddresses(), ',') : null;
            emailMessageRecord.BccAddress = salesforceEmailMessage.getBccAddresses() != null ? String.join(salesforceEmailMessage.getBccAddresses(), ',') : null;

            emailMessageRecord.Subject = salesforceEmailMessage.getSubject();
            emailMessageRecord.TextBody = salesforceEmailMessage.getPlainTextBody();
            emailMessageRecord.HtmlBody = salesforceEmailMessage.getHtmlBody();

            emailMessageRecord.Incoming = false;
            emailMessageRecord.MessageDate = system.now();
            emailMessageRecord.Status = '3'; // This means 'Sent' to Salesforce

            return emailMessageRecord;
        }
    }

    public class EmailSaveAsActivityTracking extends EmailTracking {

        public EmailSaveAsActivityTracking(Object trackableObject) {
            super(trackableObject);
        }

        public override Object track() {
            // Salesforce cares about this for us. So... Nothing to see here. Move along!
            return null;
        }
    }
}