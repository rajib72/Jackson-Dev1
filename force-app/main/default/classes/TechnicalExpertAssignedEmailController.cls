public without sharing class TechnicalExpertAssignedEmailController {

    private Id workOrderIdValue;
    private Boolean dataLoaded = false;

    private String engineerNameValue;
    private String engineerPhoneValue;
    private Datetime assignmentDateValue;

    /*
     * Receives Work Order ID from the Visualforce component.
     */
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

        /*
         * Fetch the latest Assigned Resource from a
         * Service Appointment belonging to this Work Order.
         */
        List<AssignedResource> assignedResources = [
            SELECT Id,
                   CreatedDate,
                   ServiceAppointmentId,
                   ServiceAppointment.ParentRecordId,
                   ServiceResourceId,
                   ServiceResource.Name,
                   ServiceResource.RelatedRecordId
            FROM AssignedResource
            WHERE ServiceAppointment.ParentRecordId = :workOrderIdValue
            AND ServiceResourceId != null
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (assignedResources.isEmpty()) {
            return;
        }

        AssignedResource assignedResource =
            assignedResources[0];

        // Service Resource name
        engineerNameValue =
            assignedResource.ServiceResource.Name;

        // Assigned Resource creation date
        assignmentDateValue =
            assignedResource.CreatedDate;

        /*
         * RelatedRecordId contains the User associated
         * with the Service Resource.
         */
        Id relatedRecordId =
            assignedResource.ServiceResource.RelatedRecordId;

        if (
            relatedRecordId != null &&
            relatedRecordId.getSObjectType() == User.SObjectType
        ) {
            List<User> engineerUsers = [
                SELECT Id,
                       Name,
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

    public String getEngineerName() {
        loadData();
        return engineerNameValue;
    }

    public String getEngineerPhone() {
        loadData();
        return engineerPhoneValue;
    }

    public Datetime getAssignmentDate() {
        loadData();
        return assignmentDateValue;
    }
}