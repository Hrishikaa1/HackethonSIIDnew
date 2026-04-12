import { LightningElement, wire, api } from 'lwc';
import getAppointmentsOverview from '@salesforce/apex/AppointmentController.getAppointmentsOverview';

export default class AppointmentOverview extends LightningElement {

    @api recordId;

    upcoming = [];
    completed = [];

    @wire(getAppointmentsOverview, { contactId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            this.upcoming = data.upcoming.map(row => ({
                ...row,
                doctorName: row.Doctor__r?.Name || 'NA',
                appointmentUrl: '/' + row.Id
            }));

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