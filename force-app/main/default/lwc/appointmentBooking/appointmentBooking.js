import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getDoctors from '@salesforce/apex/AppointmentBookingController.getDoctors';
import getDoctorDepartments from '@salesforce/apex/AppointmentBookingController.getDoctorDepartments';
import searchPatients from '@salesforce/apex/AppointmentBookingController.searchPatients';
import getBookedSlots from '@salesforce/apex/AppointmentBookingController.getBookedSlots';
import createNewPatientAndAppointment from '@salesforce/apex/AppointmentBookingController.createNewPatientAndAppointment';
import createAppointmentForExistingPatient from '@salesforce/apex/AppointmentBookingController.createAppointmentForExistingPatient';

export default class AppointmentBooking extends NavigationMixin(LightningElement) {

    @track currentStep = 1;
    patientType = '';
    patientSearchTerm = '';
    selectedPatientId;
    selectedPatientName;
    isLoading = false;

    @track patientResults = [];
    @track departmentOptions = [];
    @track doctorOptions = [];
    @track slotOptions = [];

    @track newPatient = {
        firstName: '',
        lastName: '',
        phone: '',
        email: ''
    };

    @track appointment = {
        department: '',
        doctorId: '',
        appointmentDate: '',
        slotTime: '',
        visitReason: ''
    };

    connectedCallback() {
        this.loadDepartments();
    }

    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }

    get isExistingPatient() { return this.patientType === 'existing'; }
    get isNewPatient() { return this.patientType === 'new'; }

    get currentStepName() { return this.currentStep.toString(); }

    get hasPatientResults() { return this.patientResults.length > 0; }

    get isDoctorDisabled() { return !this.appointment.department; }

    get isSlotDisabled() {
        return !this.appointment.doctorId || !this.appointment.appointmentDate || this.slotOptions.length === 0;
    }

    get showNoSlotsMessage() {
        return this.appointment.doctorId && this.appointment.appointmentDate && this.slotOptions.length === 0;
    }

    get isSaveDisabled() {
        if (!this.appointment.department ||
            !this.appointment.doctorId ||
            !this.appointment.appointmentDate ||
            !this.appointment.slotTime) return true;

        if (this.isNewPatient && (
            !this.newPatient.firstName ||
            !this.newPatient.lastName ||
            !this.newPatient.phone ||
            !this.newPatient.email
        )) return true;

        if (this.isExistingPatient && !this.selectedPatientId) return true;

        return false;
    }

    // ---------------- VALIDATION ----------------

    validateInputs() {
        let isValid = true;

        const inputs = this.template.querySelectorAll(
            'lightning-input, lightning-combobox, lightning-textarea'
        );

        inputs.forEach(input => {
            if (!input.checkValidity()) {
                input.reportValidity();
                isValid = false;
            }
        });

        return isValid;
    }

    validateStep2() {
        let isValid = true;

        const inputs = this.template.querySelectorAll('lightning-input');

        inputs.forEach(input => {
            if (!input.checkValidity()) {
                input.reportValidity();
                isValid = false;
            }
        });

        return isValid;
    }

    // ---------------- NAVIGATION ----------------

    handlePatientTypeSelect(event) {
        this.patientType = event.currentTarget.dataset.type;
        this.currentStep = 2;
    }

    handleBackToStep1() {
        this.currentStep = 1;
    }

    handleBackToStep2() {
        this.currentStep = 2;
    }

    handleNextToAppointment() {

        if (this.isNewPatient) {
            if (!this.validateStep2()) return;
        }

        if (this.isExistingPatient && !this.selectedPatientId) {
            this.showError('Patient Not Selected', new Error('Please select a patient'));
            return;
        }

        this.currentStep = 3;
    }

    // ---------------- DATA ----------------

    async loadDepartments() {
        this.isLoading = true;
        try {
            const data = await getDoctorDepartments();
            this.departmentOptions = data.map(d => ({ label: d, value: d }));
        } catch (e) {
            this.showError('Error', e);
        } finally {
            this.isLoading = false;
        }
    }

    async loadDoctors() {
        if (!this.appointment.department) return;

        this.isLoading = true;
        try {
            const result = await getDoctors({ department: this.appointment.department });
            this.doctorOptions = result.map(d => ({
                label: 'Dr. ' + d.doctorName,
                value: d.doctorId
            }));
        } finally {
            this.isLoading = false;
        }
    }

    async loadSlotsIfReady() {
        if (!this.appointment.doctorId || !this.appointment.appointmentDate) return;

        this.isLoading = true;
        try {
            const booked = await getBookedSlots({
                doctorId: this.appointment.doctorId,
                appointmentDate: this.appointment.appointmentDate
            });

            const allSlots = [
                { label: '11:00 AM - 12:00 PM', value: '11am to 12pm' },
                { label: '12:00 PM - 1:00 PM', value: '12pm to 1pm' },
                { label: '2:00 PM - 3:00 PM', value: '2pm to 3pm' },
                { label: '3:00 PM - 4:00 PM', value: '3pm to 4pm' },
                { label: '4:00 PM - 5:00 PM', value: '4pm to 5pm' }
            ];

            this.slotOptions = allSlots.filter(s => !booked.includes(s.value));
        } finally {
            this.isLoading = false;
        }
    }

    // ---------------- EVENTS ----------------

    handlePatientSearchChange(event) {
        this.patientSearchTerm = event.target.value;
        if (this.patientSearchTerm.length < 2) return;

        searchPatients({ searchTerm: this.patientSearchTerm })
            .then(res => this.patientResults = res)
            .catch(e => this.showError('Error', e));
    }

    handlePatientSelect(event) {
        this.selectedPatientId = event.currentTarget.dataset.id;
        const p = this.patientResults.find(x => x.Id === this.selectedPatientId);
        this.selectedPatientName = p?.Name;
        this.patientResults = [];
    }

    handleNewPatientChange(event) {
        const field = event.target.dataset.field;
        this.newPatient[field] = event.target.value;
    }

    handleDepartmentChange(event) {
        this.appointment.department = event.detail.value;
        this.appointment.doctorId = '';
        this.loadDoctors();
    }

    handleDoctorChange(event) {
        this.appointment.doctorId = event.detail.value;
        this.loadSlotsIfReady();
    }

    handleDateChange(event) {
        this.appointment.appointmentDate = event.target.value;
        this.loadSlotsIfReady();
    }

    handleSlotChange(event) {
        this.appointment.slotTime = event.detail.value;
    }

    handleVisitReasonChange(event) {
        this.appointment.visitReason = event.target.value;
    }

    // ---------------- SAVE ----------------

    async handleSave() {

        if (!this.validateInputs()) return;

        this.isLoading = true;

        try {
            let id;

            if (this.isNewPatient) {
                id = await createNewPatientAndAppointment({
                    firstName: this.newPatient.firstName,
                    lastName: this.newPatient.lastName,
                    phone: this.newPatient.phone,
                    email: this.newPatient.email,
                    doctorId: this.appointment.doctorId,
                    appointmentDate: this.appointment.appointmentDate,
                    slotTime: this.appointment.slotTime,
                    visitReason: this.appointment.visitReason
                });
            } else {
                id = await createAppointmentForExistingPatient({
                    patientId: this.selectedPatientId,
                    doctorId: this.appointment.doctorId,
                    appointmentDate: this.appointment.appointmentDate,
                    slotTime: this.appointment.slotTime,
                    visitReason: this.appointment.visitReason
                });
            }

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Appointment booked successfully!',
                variant: 'success'
            }));

            setTimeout(() => {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: id,
                        objectApiName: 'Appointment__c',
                        actionName: 'view'
                    }
                });
            }, 1000);

        } catch (e) {
            this.showError('Error', e);
        } finally {
            this.isLoading = false;
        }
    }

    // ---------------- ERROR ----------------

    showError(title, error) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message: error?.body?.message || error.message,
            variant: 'error'
        }));
    }
}