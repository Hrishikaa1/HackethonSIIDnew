public class AppointmentBookingController {

    public class DoctorWrapper {
        @AuraEnabled public String doctorId   { get; set; }
        @AuraEnabled public String doctorName { get; set; }
        @AuraEnabled public String department { get; set; }
    }

    @AuraEnabled
    public static List<DoctorWrapper> getDoctors(String department) {
        List<DoctorWrapper> result = new List<DoctorWrapper>();
        String query = 'SELECT Id, Name, Department__c FROM User WHERE Is_Doctor__c = true';
        if (String.isNotBlank(department)) {
            query += ' AND Department__c = :department';
        }
        query += ' ORDER BY Name';
        for (User u : Database.query(query)) {
            DoctorWrapper w = new DoctorWrapper();
            w.doctorId   = u.Id;
            w.doctorName = u.Name;
            w.department = u.Department__c;
            result.add(w);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getDoctorDepartments() {
        List<AggregateResult> results = [
            SELECT Department__c
            FROM User
            WHERE Is_Doctor__c = true
            AND Department__c != null
            GROUP BY Department__c
            ORDER BY Department__c
        ];
        List<String> departments = new List<String>();
        for (AggregateResult ar : results) {
            String dept = (String) ar.get('Department__c');
            if (String.isNotBlank(dept)) departments.add(dept);
        }
        return departments;
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact> searchPatients(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.trim().length() < 2) {
            return new List<Contact>();
        }
        String likeSearch = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
        return [
            SELECT Id, Name, Phone, Email, Patient_ID__c
            FROM   Contact
            WHERE  (Name LIKE :likeSearch OR Patient_ID__c LIKE :likeSearch)
            ORDER BY Name
            LIMIT  10
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getBookedSlots(Id doctorId, Date appointmentDate) {
        List<Appointment__c> appts = [
            SELECT Slot_Time__c
            FROM   Appointment__c
            WHERE  Doctor__c           = :doctorId
              AND  Appointment_Date__c = :appointmentDate
              AND  Status__c           NOT IN ('Cancelled')
        ];
        List<String> bookedSlots = new List<String>();
        for (Appointment__c a : appts) {
            if (String.isNotBlank(a.Slot_Time__c)) bookedSlots.add(a.Slot_Time__c);
        }
        return bookedSlots;
    }

    @AuraEnabled
    public static Id createNewPatientAndAppointment(
        String firstName, String lastName, String phone, String email,
        Id doctorId, Date appointmentDate, String slotTime, String visitReason
    ) {
        if (String.isBlank(firstName) || String.isBlank(lastName)) {
            throw new AuraHandledException('First name and last name are required.');
        }
        validateSlot(doctorId, appointmentDate, slotTime);

        Id accountId = getOrCreateAccount(firstName, lastName, phone, email);
        Contact patient = new Contact(
            FirstName = firstName, LastName = lastName,
            Phone = phone, Email = email
        );
        if (accountId != null) patient.AccountId = accountId;
        insert patient;

        Map<String, DateTime> slotDTs = buildSlotDateTimes(appointmentDate, slotTime);
        Appointment__c appt = new Appointment__c(
            Patient__c          = patient.Id,
            Doctor__c           = doctorId,
            Appointment_Date__c = appointmentDate,
            Slot_Time__c        = slotTime,
            Slot_Start__c       = slotDTs.get('start'),
            Slot_End__c         = slotDTs.get('end'),
            Visit_Reason__c     = visitReason,
            Status__c           = 'Scheduled'
        );
        insert appt;
        return appt.Id;
    }

    @AuraEnabled
    public static Id createAppointmentForExistingPatient(
        Id patientId, Id doctorId, Date appointmentDate,
        String slotTime, String visitReason
    ) {
        validateSlot(doctorId, appointmentDate, slotTime);

        Map<String, DateTime> slotDTs = buildSlotDateTimes(appointmentDate, slotTime);
        Appointment__c appt = new Appointment__c(
            Patient__c          = patientId,
            Doctor__c           = doctorId,
            Appointment_Date__c = appointmentDate,
            Slot_Time__c        = slotTime,
            Slot_Start__c       = slotDTs.get('start'),
            Slot_End__c         = slotDTs.get('end'),
            Visit_Reason__c     = visitReason,
            Status__c           = 'Scheduled'
        );
        insert appt;
        return appt.Id;
    }

    // ── Server-side double-booking guard ───────────────────────────
    private static void validateSlot(Id doctorId, Date appointmentDate, String slotTime) {
        if (doctorId == null || appointmentDate == null || String.isBlank(slotTime)) {
            throw new AuraHandledException('Doctor, appointment date, and slot time are required.');
        }
        List<Appointment__c> conflicts = [
            SELECT Id FROM Appointment__c
            WHERE  Doctor__c           = :doctorId
              AND  Appointment_Date__c = :appointmentDate
              AND  Slot_Time__c        = :slotTime
              AND  Status__c           NOT IN ('Cancelled')
            LIMIT 1
        ];
        if (!conflicts.isEmpty()) {
            throw new AuraHandledException(
                'The slot "' + slotTime + '" was just booked by someone else. Please select a different time.'
            );
        }
    }

    // ── Parse slot string → Slot_Start__c / Slot_End__c ───────────
    private static Map<String, DateTime> buildSlotDateTimes(Date apptDate, String slotTime) {
        Map<String, DateTime> result = new Map<String, DateTime>();
        if (apptDate == null || String.isBlank(slotTime)) return result;

        List<String> parts = slotTime.toLowerCase().split(' to ');
        if (parts.size() != 2) return result;

        result.put('start', parseSlotPart(apptDate, parts[0].trim()));
        result.put('end',   parseSlotPart(apptDate, parts[1].trim()));
        return result;
    }

    private static DateTime parseSlotPart(Date apptDate, String timePart) {
        // handles: "11am", "12pm", "2pm", "3pm" etc.
        Boolean isPM   = timePart.endsWith('pm');
        String  numStr = timePart.replace('am', '').replace('pm', '').trim();
        Integer hour   = Integer.valueOf(numStr);

        if (isPM && hour != 12) hour += 12;   // 2pm → 14, 3pm → 15 …
        if (!isPM && hour == 12) hour = 0;     // 12am → midnight (edge case)

        return DateTime.newInstance(apptDate, Time.newInstance(hour, 0, 0, 0));
    }

    // ── Create or reuse an Account for the new patient Contact ─────
    private static Id getOrCreateAccount(
        String firstName, String lastName, String phone, String email
    ) {
        String fullName = (firstName + ' ' + lastName).trim();
        Schema.DescribeFieldResult dfr = Contact.AccountId.getDescribe();
        if (!dfr.isNillable() && !dfr.isDefaultedOnCreate()) {
            List<Account> existing = [SELECT Id FROM Account WHERE Name = :fullName LIMIT 1];
            if (!existing.isEmpty()) return existing[0].Id;
            Account acct = new Account(Name = fullName, Phone = phone);
            try { acct.put('Email__c', email); } catch (Exception ex) { }
            insert acct;
            return acct.Id;
        }
        return null;
    }
}