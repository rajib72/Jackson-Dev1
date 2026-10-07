trigger ResourcePreferenceEditDeleteRestriction on ResourcePreference (
    before update,
    before delete
) {

    Profile currentProfile = [
        SELECT Id, Name
        FROM Profile
        WHERE Id = :UserInfo.getProfileId()
        LIMIT 1
    ];

    /*
     * Only System Administrator can
     * update or delete ResourcePreference records.
     */
    if (currentProfile.Name != 'System Administrator') {

        if (Trigger.isUpdate) {

            for (ResourcePreference preferenceRecord : Trigger.new) {

                preferenceRecord.addError(
                    'You do not have permission to edit this Resource Preference. Please contact your System Administrator.'
                );
            }
        }

        if (Trigger.isDelete) {

            for (ResourcePreference preferenceRecord : Trigger.old) {

                preferenceRecord.addError(
                    'You do not have permission to delete this Resource Preference. Please contact your System Administrator.'
                );
            }
        }
    }
}