public class AppointmentEmailSender {
    @InvocableMethod(label='Send Appointment Confirmation Email' description='Sends confirmation email for the given Appointment Id')
    public static void sendAppointmentEmail(List<Id> appointmentIds) {
        
        List<Appointment__c> appointments = [
            SELECT Id, Name, 
            Patient__r.Email, Patient__r.Name,
            Doctor__r.Name, 
            Appointment_Date__c, Start_Time__c, End_Time__c, Visit_Reason__c
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
                + 'Your appointment has been created. Here are your appointment details:\n\n'
                + 'Appointment Number : ' + appt.Name + '\n'
                + 'Doctor             : ' + (appt.Doctor__r != null ? appt.Doctor__r.Name : 'N/A') + '\n'
                + 'Appointment Date   : ' + (appt.Appointment_Date__c != null ? appt.Appointment_Date__c.format() : 'N/A') + '\n'
                + 'Start Time         : ' + (appt.Start_Time__c != null ? String.valueOf(appt.Start_Time__c) : 'N/A') + '\n'
                + 'End Time           : ' + (appt.End_Time__c != null ? String.valueOf(appt.End_Time__c) : 'N/A') + '\n'
                + 'Visit Reason       : ' + (appt.Visit_Reason__c != null ? appt.Visit_Reason__c : 'N/A') + '\n\n'
                + 'Thank you.';
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ appt.Patient__r.Email });
            mail.setSubject('Appointment Confirmation - ' + appt.Name);
            mail.setPlainTextBody(body);
            mail.setOrgWideEmailAddressId(owea.Id);
            
            emails.add(mail);
        }
        
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }
}