public with sharing class AppointmentController {
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Appointment__c>> getCompletedAppointments(Id contactId) {
        
        List<Appointment__c> completed = [
            SELECT Id, Name, Medical_Notes__c,
            Doctor__c, Doctor__r.Name, Visit_Reason__c
            FROM Appointment__c
            WHERE Status__c = 'Completed'
            AND patient__c = :contactId
            ORDER BY CreatedDate DESC
        ];
        
        return new Map<String, List<Appointment__c>>{
            'completed' => completed
                };
                    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Appointment__c>> getAppointmentsOverview(Id contactId) {
        
        List<Appointment__c> upcoming = [
            SELECT Id, Name, Medical_Notes__c,
            patient__c, patient__r.Name,
            Doctor__c, Doctor__r.Name,
            Appointment_Date__c, Visit_Reason__c
            FROM Appointment__c
            WHERE Status__c = 'Scheduled'
            AND patient__c = :contactId
            ORDER BY Appointment_Date__c ASC
            LIMIT 5
        ];
        
        List<Appointment__c> completed = [
            SELECT Id, Name, Medical_Notes__c,
            Doctor__c, Doctor__r.Name, Visit_Reason__c
            FROM Appointment__c
            WHERE Status__c = 'Completed'
            AND patient__c = :contactId
            ORDER BY CreatedDate DESC
        ];
        
        return new Map<String, List<Appointment__c>>{
            'upcoming' => upcoming,
                'completed' => completed
                };
                    }
    
}