public with sharing class rescheduleAppointmentController {

    /**
     * Returns List<Integer> of start hours (24h) already booked for the
     * given doctor on the given date. LWC filters master slots client-side.
     */
    @AuraEnabled(cacheable=true)
    public static List<Integer> getAvailableSlots(
            Id   doctorId,
            Date appointmentDate,
            Id   currentRecordId) {

        if (doctorId == null || appointmentDate == null) {
            throw new AuraHandledException('Doctor and Appointment Date are required.');
        }

        List<Integer> bookedHours = new List<Integer>();

        for (Appointment__c appt : [
            SELECT Start_Time__c
            FROM   Appointment__c
            WHERE  Doctor__c           = :doctorId
            AND    Appointment_Date__c = :appointmentDate
            AND    Status__c          != 'Cancelled'
            AND    Id                 != :currentRecordId
        ]) {
            if (appt.Start_Time__c != null) {
                bookedHours.add(appt.Start_Time__c.hour());
            }
        }

        return bookedHours;
    }

    /**
     * Creates a new rescheduled Appointment__c.
     * Marks original Reschedule_Reminder_Sent__c = true.
     * Sends email to patient with new appointment details.
     * Stores original appointment name in Rescheduled_From__c.
     */
    @AuraEnabled
    public static Id createRescheduledAppointment(
            Id     originalRecordId,
            String newDate,
            String startTime,
            String endTime,
            String appointmentType,
            String visitReason,
            String originalAppointmentName) {

        if (originalRecordId == null || String.isBlank(newDate) ||
            String.isBlank(startTime) || String.isBlank(endTime)) {
            throw new AuraHandledException('Missing required fields for rescheduling.');
        }

        // Fetch original — patient email needed for notification
        Appointment__c original = [
            SELECT  Patient__c,
                    Doctor__c,
                    Patient__r.Name,
                    Patient__r.Email,
                    Doctor__r.Name
            FROM    Appointment__c
            WHERE   Id = :originalRecordId
            LIMIT   1
        ];

        Date     apptDate = Date.valueOf(newDate);
        Datetime startDT  = Datetime.valueOf(startTime.replace('T', ' ').replace('.000Z', ''));
        Datetime endDT    = Datetime.valueOf(endTime.replace('T', ' ').replace('.000Z', ''));

        // 1 — Create new appointment
        Appointment__c newAppt = new Appointment__c(
            Patient__c                  = original.Patient__c,
            Doctor__c                   = original.Doctor__c,
            Appointment_Date__c         = apptDate,
            Start_Time__c               = startDT,
            End_Time__c                 = endDT,
            Status__c                   = 'Scheduled',
            Type__c                     = appointmentType,
            Visit_Reason__c             = visitReason,
            Reschedule_Reminder_Sent__c = false,
            Rescheduled_From__c         = originalAppointmentName   // parent name stored here
        );

        try {
            insert newAppt;
        } catch (DmlException ex) {
            throw new AuraHandledException('Failed to create appointment: ' + ex.getMessage());
        }

        // 2 — Mark original: Reschedule_Reminder_Sent__c = true
        try {
            update new Appointment__c(
                Id                          = originalRecordId,
                Reschedule_Reminder_Sent__c = true
            );
        } catch (DmlException ex) {
            throw new AuraHandledException(
                'Appointment created but failed to update original record: ' + ex.getMessage()
            );
        }

        // 3 — Send email to patient (non-blocking)
        if (String.isNotBlank(original.Patient__r.Email)) {
            sendRescheduleEmail(original, newAppt, startDT, endDT, originalAppointmentName);
        }

        return newAppt.Id;
    }

    // ─── Private: email helper ────────────────────────────────────────────────
    private static void sendRescheduleEmail(
            Appointment__c original,
            Appointment__c newAppt,
            Datetime       startDT,
            Datetime       endDT,
            String         originalAppointmentName) {

        String patientName   = original.Patient__r.Name;
        String doctorName    = original.Doctor__r.Name;
        String formattedDate = newAppt.Appointment_Date__c.format();
        String startDisplay  = startDT.format('hh:mm a');
        String endDisplay    = endDT.format('hh:mm a');
        String visitReason   = String.isNotBlank(newAppt.Visit_Reason__c)
                                    ? newAppt.Visit_Reason__c : '—';

        String subject  = 'Your Appointment Has Been Rescheduled';

        String htmlBody =
            '<p>Dear ' + patientName + ',</p>' +
            '<p>Your appointment <strong>' + originalAppointmentName + '</strong> has been rescheduled. ' +
            'Here are your new appointment details:</p>' +
            '<table style="border-collapse:collapse;width:100%;max-width:520px;">' +
                row('#f3f3f3', 'Rescheduled From',  originalAppointmentName) +
                row('#ffffff', 'Doctor',             doctorName) +
                row('#f3f3f3', 'Date',               formattedDate) +
                row('#ffffff', 'Time',               startDisplay + ' – ' + endDisplay) +
                row('#f3f3f3', 'Type',               newAppt.Type__c) +
                row('#ffffff', 'Visit Reason',       visitReason) +
            '</table>' +
            '<p>If you have any questions, please contact us.</p>' +
            '<p>Regards,<br/>Apollo Care</p>';

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTargetObjectId(original.Patient__c);  // Contact Id
        mail.setSubject(subject);
        mail.setHtmlBody(htmlBody);
        mail.setSaveAsActivity(false);

        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception ex) {
            // Log only — don't fail the transaction
            System.debug('Email send failed: ' + ex.getMessage());
        }
    }

    // ─── Private: table row builder ───────────────────────────────────────────
    private static String row(String bg, String label, String val) {
        return '<tr style="background:' + bg + ';">' +
                   '<td style="padding:8px;border:1px solid #ddd;width:40%;"><strong>' + label + '</strong></td>' +
                   '<td style="padding:8px;border:1px solid #ddd;">' + val + '</td>' +
               '</tr>';
    }
}