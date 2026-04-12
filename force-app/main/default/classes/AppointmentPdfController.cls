public class AppointmentPdfController {
    
    public Appointment__c appointment { get; set; }
    public List<Prescription__c> prescriptions { get; set; }
    
    public AppointmentPdfController(ApexPages.StandardController std) {
        
        Id appointmentId = std.getId();
        
        appointment = [
            SELECT Id,
            Patient__r.Name,
            Patient__r.Date_of_Birth__c,
            Patient__r.Gender__c,
            Doctor__r.Name
            FROM Appointment__c
            WHERE Id = :appointmentId
        ];
        
        prescriptions = [
            SELECT Medication_Name__c, Duration__c
            FROM Prescription__c
            WHERE Appointment__c = :appointmentId
        ];
    }
}