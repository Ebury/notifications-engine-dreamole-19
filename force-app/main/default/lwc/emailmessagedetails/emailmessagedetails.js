import {LightningElement, wire, track} from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getEmailById from '@salesforce/apex/EmailMessagesController.getEmailById';
import { registerListener, unregisterAllListeners } from 'c/pubsub';

export default class Emailmessagedetails extends LightningElement {
  @track messageId;
  @track ccAddress;
  @track toAddress;
  @track fromAddress;
  @track messagebody;
  @track messageRichBody;
  @track messageDate;
  @track messageSubject;

  @wire(CurrentPageReference) pageRef;

  connectedCallback() {
    registerListener('emailselected', this.handleEmailSelected, this);
  }

  @wire(getEmailById, { emailId: '$messageId'})
  wiredRecord({ error, data }) {
    if (data) {
      this.ccAddress = data.CcAddress;
      this.toAddress = data.ToAddress;
      this.fromAddress = data.FromAddress;
      this.messagebody = data.TextBody;
      this.messageRichBody = data.HtmlBody;
      this.messageDate = data.MessageDate;
      this.messageSubject = data.Subject;
    }
  }

  handleEmailSelected(messageId) {
    this.messageId = messageId;
  }
}