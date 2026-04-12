public class RefillMeditionReminderTemplate {
    
    @InvocableMethod(label='Send Refill Medication Reminder Email (No Template)')
    public static void sendEmails(List<Id> prescriptionIds) {
        
        if (prescriptionIds == null || prescriptionIds.isEmpty()) {
            return;
        }
        
        OrgWideEmailAddress owea = [
            SELECT Id, Address, DisplayName
            FROM OrgWideEmailAddress
            WHERE DisplayName = 'Apollo Care'
            LIMIT 1
        ];
        
        List<Prescription__c> prescriptions = [
            SELECT Id,
            Name,
            Medication_Name__c,
            Start_Date__c,
            Duration__c,
            Remaining_Date__c,
            Reminder_Sent__c,
            Patient__c,
            Patient__r.Name,
            Patient__r.Email,
            Doctor__c,
            Doctor__r.Name
            FROM Prescription__c
            WHERE Id IN :prescriptionIds
        ];
        
        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
        
        for (Prescription__c pres : prescriptions) {
            
            if (pres.Reminder_Sent__c == true) {
                continue;
            }
            
            if (pres.Patient__r == null || pres.Patient__r.Email == null) {
                continue;
            }
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            
            mail.setToAddresses(new List<String>{ pres.Patient__r.Email });
            mail.setSubject('Medication Refill Reminder – Apollo Care');
            mail.setOrgWideEmailAddressId(owea.Id);
            
            String startDateStr = '';
            if (pres.Start_Date__c != null) {
                startDateStr = DateTime.newInstance(
                    pres.Start_Date__c,
                    Time.newInstance(0, 0, 0, 0)
                ).format('dd MMM yyyy');
            }
            
            String endDateStr = '';
            if (pres.Remaining_Date__c != null) {
                endDateStr = DateTime.newInstance(
                    pres.Remaining_Date__c,
                    Time.newInstance(0, 0, 0, 0)
                ).format('dd MMM yyyy');
            }
            
            String body = ''
                + '<p>Dear ' + pres.Patient__r.Name + ',</p>'
                
                + '<p>This is a friendly reminder that your prescribed medication is due for a refill.</p>'
                
                + '<p><b>Prescription Details:</b></p>'
                
                + '<p><b>Medication Name:</b> ' + pres.Medication_Name__c + '</p>'
                + '<p><b>Last Refill Date:</b> ' + endDateStr + '</p>'
                
                + '<p>Please refill your medication as soon as possible to avoid interruption in your treatment.</p>'
                
                + '<p>If you have already requested your refill, please ignore this message.</p>'
                
                + '<p>For any questions or help, please contact our support team.</p>'
                
                + '<p>Warm regards,<br/>Apollo Team</p>';
            
            mail.setHtmlBody(body);
            emailList.add(mail);
            
            pres.Reminder_Sent__c = true;
        }
        
        if (!emailList.isEmpty()) {
            Messaging.sendEmail(emailList);
            update prescriptions;
        }
    }
}