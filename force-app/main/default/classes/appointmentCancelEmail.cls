public class appointmentCancelEmail {
    public static void sendCancellationEmail(List<Id> appointmentIds) {
        
        List<Appointment__c> appointments = [
            SELECT Id, Name,
                   Patient__r.Email, Patient__r.Name,
                   Doctor__r.Name,
                   Appointment_Date__c
            FROM Appointment__c
            WHERE Id IN :appointmentIds
        ];
			
        OrgWideEmailAddress owea = [
            SELECT Id, Address, DisplayName
            FROM OrgWideEmailAddress
            WHERE DisplayName = 'Apollo Care'
            LIMIT 1
        ];
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Appointment__c appt : appointments) {
            
            if (appt.Patient__r == null || String.isBlank(appt.Patient__r.Email)) continue;
            String body = 'Dear ' + appt.Patient__r.Name + ',\n\n'
                + 'We regret to inform you that your appointment has been cancelled. Here are the details of the cancelled appointment:\n\n'
                + 'Appointment Number : ' + appt.Name + '\n'
                + 'Doctor             : ' + (appt.Doctor__r != null ? appt.Doctor__r.Name : 'N/A') + '\n'
                + 'Appointment Date   : ' + (appt.Appointment_Date__c != null ? appt.Appointment_Date__c.format() : 'N/A') + '\n\n'
                + 'If you have any questions or wish to reschedule, please contact us.\n\n'
                + 'Thank you.';
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ appt.Patient__r.Email });
            mail.setSubject('Appointment Cancellation - ' + appt.Name);
            mail.setPlainTextBody(body);
            mail.setOrgWideEmailAddressId(owea.Id);
            emails.add(mail);
        }
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }
}