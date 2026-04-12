public class AppointmentReminderConfirmation {
    
    @InvocableMethod(label='Send Appointment Reminder Email')
    public static void sendEmails(List<Id> appointmentIds) {
        
        if (appointmentIds == null || appointmentIds.isEmpty()) {
            return;
        }
        
        OrgWideEmailAddress owea = [
            SELECT Id, Address, DisplayName
            FROM OrgWideEmailAddress
            WHERE DisplayName = 'Apollo Care'
            LIMIT 1
        ];
        
        List<Appointment__c> appointments = [
            SELECT Id,
            Name,
            Appointment_Date__c,
            Slot_Start__c,
            Slot_End__c,
            Patient__c,
            Patient__r.Name,
            Patient__r.Email,
            Doctor__c,
            Doctor__r.Name
            FROM Appointment__c
            WHERE Id IN :appointmentIds
        ];
        
        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
        
        for (Appointment__c appt : appointments) {
            
            if (appt.Patient__r.Email != null) {
                
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                //mail.setSenderDisplayName('Apollo Care');
                
                mail.setToAddresses(new List<String>{ appt.Patient__r.Email });
                
                mail.setSubject('Your Appointment is Confirmed – Apollo Care');
                
                mail.setOrgWideEmailAddressId(owea.Id);
                
                String dateStr = '';
                String timeStr = '';
                
                if (appt.Appointment_Date__c != null) {
                    dateStr = DateTime.newInstance(
                        appt.Appointment_Date__c,
                        Time.newInstance(0, 0, 0, 0)
                    ).format('dd MMM yyyy');
                }
                
                if (appt.Slot_Start__c != null && appt.Slot_End__c != null) {
                    timeStr = appt.Slot_Start__c.format('hh:mm a') + 
                        ' - ' + 
                        appt.Slot_End__c.format('hh:mm a');
                }
                
                String body = ''
                    + '<p>Dear ' + appt.Patient__r.Name + ',</p>'
                    
                    + '<p>'
                    + 'This is a friendly reminder that you have an upcoming appointment with Apollo Care.'
                    + '</p>'
                    
                    + '<p><b>Appointment Details:</b></p>'
                    
                    + '<p><b>Date:</b> ' + dateStr + '</p>'
                    + '<p><b>Time:</b> ' + timeStr + '</p>'
                    + '<p><b>Doctor:</b> ' + appt.Doctor__r.Name + '</p>'
                    
                    + '<p>'
                    + 'Please make sure to arrive at least 10 minutes early to allow time for check-in.'
                    + '</p>'
                    
                    + '<p>'
                    + 'If you are unable to attend or need to reschedule, kindly contact us as soon as possible.'
                    + '</p>'
                    
                    + '<p>'
                    + 'We look forward to seeing you and taking care of your health.'
                    + '</p>'
                    
                    + '<p>Warm regards,<br/>Apollo Team</p>';
                
                mail.setHtmlBody(body);
                
                emailList.add(mail);
            }
        }
        
        if (!emailList.isEmpty()) {
            Messaging.sendEmail(emailList);
        }
    }
}