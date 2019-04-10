import {LightningElement, wire, track} from 'lwc';
import apexGetEmailsSent from '@salesforce/apex/EmailMessagesController.getEmailsSent';
import { CurrentPageReference } from 'lightning/navigation';
import { fireEvent } from 'c/pubsub';

export default class EmailMessages extends LightningElement {

  @track emailsSent = [];
  @track emailListLoading = false;
  @track emailsSentColumns = [
    {label: 'From', fieldName: 'FromName', type: 'text'},
    {label: 'Subject', fieldName: 'Subject', type: 'text'},
    {label: 'To Address', fieldName: 'ToAddress', type: 'text'},
    {label: 'Date', fieldName: 'MessageDate', type: 'date'}
  ];

  @wire(CurrentPageReference) pageRef;

  connectedCallback() {
    this.emailListLoading = true;

    apexGetEmailsSent({})
    .then(result => {
      if (result !== undefined) {
        this.emailsSent = result;
      }
    })
    .finally(() => {
      this.emailListLoading = false;
    });
  }

  handleEmailSelected(event) {
    const selectedEmail = event.detail.selectedRows[0];
    fireEvent(this.pageRef, 'emailselected', selectedEmail.Id);
  }

}