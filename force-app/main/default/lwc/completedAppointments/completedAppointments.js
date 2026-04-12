import { LightningElement, wire, api } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import getCompletedAppointments from '@salesforce/apex/AppointmentController.getCompletedAppointments';

export default class CompletedAppointments extends LightningElement {
    @api recordId;

    completed = [];
    isDoctor = false;

    @wire(getCompletedAppointments, { contactId: '$recordId' })
    wiredAppointments({ error, data }) {
        if (data) {
            this.completed = data.completed.map(row => ({
                ...row,
                doctorName: row.Doctor__r?.Name || 'NA',
                appointmentUrl: '/' + row.Id
            }));
        } else if (error) {
            console.error(error);
        }
    }
}