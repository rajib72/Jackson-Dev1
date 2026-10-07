public class SiteVisitScheduledEmailController {
    private Id workOrderIdValue;
    private Boolean dataLoaded = false;

    private String caseNumberValue;
    private String appointmentNumberValue;
    private Datetime expectedVisitDateValue;
    private String engineerNameValue;
    private String engineerPhoneValue;

    public Id getWorkOrderId() {
        return workOrderIdValue;
    }

    public void setWorkOrderId(Id value) {
        workOrderIdValue = value;
        dataLoaded = false;
    }

    private void loadData() {

        if (dataLoaded || workOrderIdValue == null) {
            return;
        }

        dataLoaded = true;

        /* Fetch Case Number from Work Order */
        List<WorkOrder> workOrders = [
            SELECT Id,
                   CaseId,
                   Case.CaseNumber
            FROM WorkOrder
            WHERE Id = :workOrderIdValue
            LIMIT 1
        ];

        if (!workOrders.isEmpty()) {
            WorkOrder workOrderRecord = workOrders[0];

            if (workOrderRecord.CaseId != null) {
                caseNumberValue =
                    workOrderRecord.Case.CaseNumber;
            }
        }

        /*
         * Fetch the latest Service Appointment
         * created under this Work Order.
         */
        List<ServiceAppointment> appointments = [
            SELECT Id,
                   AppointmentNumber,
                   SchedStartTime,
                   EarliestStartTime,
                   ParentRecordId,
                   CreatedDate
            FROM ServiceAppointment
            WHERE ParentRecordId = :workOrderIdValue
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (appointments.isEmpty()) {
            return;
        }

        ServiceAppointment appointment =
            appointments[0];

        appointmentNumberValue =
            appointment.AppointmentNumber;

        /*
         * Prefer Scheduled Start Time.
         * Use Earliest Start Time when it is blank.
         */
        expectedVisitDateValue =
            appointment.SchedStartTime != null
            ? appointment.SchedStartTime
            : appointment.EarliestStartTime;

        /*
         * Fetch Assigned Resource from the selected
         * Service Appointment.
         */
        List<AssignedResource> assignedResources = [
            SELECT Id,
                   CreatedDate,
                   ServiceAppointmentId,
                   ServiceResourceId,
                   ServiceResource.Name,
                   ServiceResource.RelatedRecordId
            FROM AssignedResource
            WHERE ServiceAppointmentId = :appointment.Id
            AND ServiceResourceId != null
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (assignedResources.isEmpty()) {
            return;
        }

        AssignedResource assignedResource =
            assignedResources[0];

        engineerNameValue =
            assignedResource.ServiceResource.Name;

        Id relatedRecordId =
            assignedResource.ServiceResource.RelatedRecordId;

        /*
         * Get Phone from the User associated
         * with the Service Resource.
         */
        if (
            relatedRecordId != null &&
            relatedRecordId.getSObjectType() == User.SObjectType
        ) {
            List<User> engineerUsers = [
                SELECT Id,
                       Phone,
                       MobilePhone
                FROM User
                WHERE Id = :relatedRecordId
                LIMIT 1
            ];

            if (!engineerUsers.isEmpty()) {
                User engineerUser = engineerUsers[0];

                engineerPhoneValue =
                    String.isNotBlank(engineerUser.Phone)
                    ? engineerUser.Phone
                    : engineerUser.MobilePhone;
            }
        }
    }

    public String getCaseNumber() {
        loadData();
        return caseNumberValue;
    }

    public String getAppointmentNumber() {
        loadData();
        return appointmentNumberValue;
    }

    public Datetime getExpectedVisitDate() {
        loadData();
        return expectedVisitDateValue;
    }

    public String getEngineerName() {
        loadData();
        return engineerNameValue;
    }

    public String getEngineerPhone() {
        loadData();
        return engineerPhoneValue;
    }

}