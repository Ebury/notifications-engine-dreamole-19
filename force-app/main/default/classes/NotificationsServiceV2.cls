public with sharing class NotificationsServiceV2 {

    /**
     * Streamlines creating and sending Salesforce standard Messaging.SingleEmailMessage.
     * This extends the V1_1 allowing bulk send emails.
     *
     * How to send a single email example:

        new NotificationsServiceV2.SingleEmail()
           .to(toRecipients)
           .ccTo(ccRecipients)
           .withBody(body)
           .withSubject(subject)
           .send();

     * How to bulk send emails:

        List<NotificationsServiceV2.SingleEmail> emails = new List<NotificationsServiceV2.SingleEmail>();

        NotificationsServiceV2.SingleEmail email =
            new NotificationsServiceV2.SingleEmail()
            .to(toRecipients)
            .ccTo(ccRecipients)
            .withBody(body)
            .withSubject(subject);
            // Note that we don't send the email by now.

        emails.add(email);

        // ... create as many emails as you need

        // Then send them all together
        NotificationsServiceV2.newEmailHandler()
            .addAll(emails)
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
        public Boolean isTargetedToUsers {get; private set;}

        public SingleEmail() {
            this.salesforceEmailMessage = new Messaging.SingleEmailMessage();
        }

        public SingleEmail to(List<String> toAddresses) {
            salesforceEmailMessage.setToAddresses(toAddresses);

            if (isAddressPointingToUsers(salesforceEmailMessage)) {
                salesforceEmailMessage.setSaveAsActivity(false);
                isTargetedToUsers = true;
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
                isTargetedToUsers = true;
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
            return newEmailHandler()
                    .add(this)
                    .send();
        }

        public Object getNotifiableObject() {
            return this.salesforceEmailMessage;
        }
    }

    // Handy methods to ignore the details of the tracking factory injection.
    public static EmailHandler newEmailHandler() {
        return new EmailHandler(new EmailTrackingFactory());
    }

    public static EmailHandler newEmailHandler(List<SingleEmail> singleEmails) {
        return new EmailHandler(new EmailTrackingFactory(), singleEmails);
    }

    // The email handler connects the dispatcher and tracker in one place. So:
    // It delegates the sending emails work to Salesforce.
    // It delegates the tracking work to a tracking system.
    // For the last one, inject an ITrackingFactory that knows which kind of tracking to instantiate based on the actual messages.
    // It defaults to EmailTrackingFactory.
    public class EmailHandler {
        private List<SingleEmail> singleEmails;
        private List<Messaging.SingleEmailMessage> salesforceEmails;
        private ITrackingFactory trackingFactory;
        private List<Messaging.SendEmailResult> emailResults;

        // Email handler ignores how to track messages. It is given by a factory.
        public EmailHandler(ITrackingFactory trackingFactory) {
            this.singleEmails = new List<SingleEmail>();
            this.trackingFactory = trackingFactory == null ? new EmailTrackingFactory() : trackingFactory;
        }

        public EmailHandler(ITrackingFactory trackingFactory, List<SingleEmail> singleEmails) {
            this(trackingFactory);
            this.addAll(singleEmails);
        }

        public EmailHandler add(SingleEmail singleEmail) {
            if (singleEmail != null) {
                this.singleEmails.add(singleEmail);
            }
            return this;
        }

        public EmailHandler addAll(List<SingleEmail> singleEmails) {
            if (singleEmails != null) {
                this.singleEmails.addAll(singleEmails);
            }
            return this;
        }

        public List<Messaging.SendEmailResult> send() {
            fetchSalesforceEmails();
            dispatchMessages();
            trackSuccessfulMessages();
            return this.emailResults;
        }

        private void fetchSalesforceEmails() {
            this.salesforceEmails = new List<Messaging.SingleEmailMessage>();

            for (SingleEmail singleEmail : this.singleEmails) {
                salesforceEmails.add((Messaging.SingleEmailMessage)singleEmail.getNotifiableObject());
            }
        }

        private void dispatchMessages() {
            this.emailResults = Messaging.sendEmail(salesforceEmails);
        }

        private void trackSuccessfulMessages() {
            List<TrackingSystem> trackingSystems = getTrackingSystemInstances();
            trackAll(trackingSystems);
        }

        private List<TrackingSystem> getTrackingSystemInstances() {
            List<TrackingSystem> trackingSystems = new List<TrackingSystem>();

            for (Integer i = 0; i < salesforceEmails.size(); i++) {
                if (emailResults[i].isSuccess()) {
                    trackingSystems.add(
                            createTrackingSystem(singleEmails[i])
                    );
                }
            }

            return trackingSystems;
        }

        private void trackAll(List<TrackingSystem> trackingSystems) {
            List<EmailMessage> emailMessages = new List<EmailMessage>();

            for (TrackingSystem trackingSystem : trackingSystems) {
                Object trackingObject = trackingSystem.createTrackingObject();

                // As EmailHandler class, I only care about inserting the EmailMessage objects.
                if (trackingObject != null && trackingObject instanceof EmailMessage) {
                    emailMessages.add((EmailMessage)trackingObject);
                }
            }

            insert emailMessages;
        }

        private TrackingSystem createTrackingSystem(SingleEmail singleEmail) {
            TrackingMethod trackingMethod = getTrackingMethod(singleEmail);
            return trackingFactory.createTrackingSystem(trackingMethod, singleEmail.getNotifiableObject());
        }

        private TrackingMethod getTrackingMethod(SingleEmail singleEmail) {

            if (singleEmail.isTargetedToUsers) {
                return TrackingMethod.LOG_RECORD;
            }

            return TrackingMethod.SF_STANDARD;
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
        TrackingSystem createTrackingSystem(NotificationsServiceV2.TrackingMethod trackingMethod, Object trackableObject);
    }

    public class EmailTrackingFactory implements ITrackingFactory {

        // We might extract the trackingMethod from the email itself instead of passing it through parameter.
        // I don't have strong arguments against passing it as we only have a factory right now. But we can change it
        // if we see the need.
        public TrackingSystem createTrackingSystem(NotificationsServiceV2.TrackingMethod trackingMethod, Object trackableObject) {

            if (trackingMethod == NotificationsServiceV2.TrackingMethod.LOG_RECORD) {
                return (TrackingSystem) new EmailLogRecordTracking(trackableObject);
            } else {
                return (TrackingSystem) new EmailSaveAsActivityTracking(trackableObject);
            }
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
            this.salesforceEmailMessage.setSaveAsActivity(true);
        }

        public override Object track() {
            // Salesforce cares about this for us. So nothing to do here
            return null;
        }
    }
}