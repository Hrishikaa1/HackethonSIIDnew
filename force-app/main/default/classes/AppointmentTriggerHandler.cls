public with sharing class AppointmentTriggerHandler {
    public static void handleAfterUpdate(List<Appointment__c> newList, Map<Id, Appointment__c> oldMap) {
        Set<Id> completedIds = new Set<Id>();
        for (Appointment__c a : newList) {
            Appointment__c old = oldMap.get(a.Id);
            if (a.Status__c == AppointmentService.STATUS_COMPLETED && 
                old.Status__c != AppointmentService.STATUS_COMPLETED) {
                completedIds.add(a.Id);
            }
        }
        if (!completedIds.isEmpty()) { 
            AppointmentService.sendCompletionEmails(completedIds);
        }
    }
}