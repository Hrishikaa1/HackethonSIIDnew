public class PrescriptionEmailQueueable implements Queueable, Database.AllowsCallouts {
    
    private List<Id> appointmentIds;
    
    public PrescriptionEmailQueueable(List<Appointment__c> apps) {
        this.appointmentIds = new List<Id>();
        for (Appointment__c a : apps) {
            this.appointmentIds.add(a.Id);
        }
    }
    
    public void execute(QueueableContext context) {
        
        Map<Id, Appointment__c> appointmentMap = new Map<Id, Appointment__c>(
            [
                SELECT Id,
                Patient__r.Name,
                Patient__r.Email,
                Doctor__r.Name
                FROM Appointment__c
                WHERE Id IN :appointmentIds
            ]
        );
        
        OrgWideEmailAddress owea = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE DisplayName = 'Apollo Care'
            LIMIT 1
        ];
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (Appointment__c app : appointmentMap.values()) {
            
            if (String.isBlank(app.Patient__r.Email)) continue;
            
            PageReference pdf = Page.AppointmentSummaryPdf;
            pdf.getParameters().put('id', app.Id);
            
            Blob pdfBlob;
            try {
                pdfBlob = pdf.getContentAsPDF();
            } catch (Exception e) {
                continue;
            }
            
            Messaging.EmailFileAttachment attach = new Messaging.EmailFileAttachment();
            attach.setFileName('Prescription.pdf');
            attach.setBody(pdfBlob);
            attach.setContentType('application/pdf');
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[]{app.Patient__r.Email});
            mail.setSubject('Your Appointment is Complete – Prescription Attached');
            mail.setPlainTextBody(
                'Dear ' + app.Patient__r.Name + ',\n\n' +
                'Your appointment with Apollo Care has been successfully completed.\n\n' +
                'Please find your prescription attached with this email.\n\n' +
                'IMPORTANT INSTRUCTIONS:\n' +
                '• Take medicines exactly as prescribed by the doctor.\n' +
                '• Do not skip doses; complete the full course of medication.\n' +
                '• Store medicines in a cool, dry place away from sunlight.\n' +
                '• Contact Apollo Care immediately in case of adverse reactions or allergies.\n\n' +
                'If you have any questions or concerns, feel free to reach out to us.\n\n' +
                'Wishing you good health.\n\n' +
                'Best Regards,\n' +
                'Apollo Care\n'
            );
            mail.setFileAttachments(new Messaging.EmailFileAttachment[]{attach});
            mail.setOrgWideEmailAddressId(owea.Id);
            
            emails.add(mail);
        }
        
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }
}