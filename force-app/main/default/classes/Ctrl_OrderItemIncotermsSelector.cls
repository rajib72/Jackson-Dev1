public with sharing class Ctrl_OrderItemIncotermsSelector {

    /**
     * One Incoterms option returned to the LWC.
     */
    public class IncotermsOption {

        @AuraEnabled
        public Id recordId;

        @AuraEnabled
        public String value;

        @AuraEnabled
        public String label;

        @AuraEnabled
        public String details;

        public IncotermsOption() {
        }

        public IncotermsOption(
            Id recordId,
            String incotermsCode,
            String incotermsDetails
        ) {
            this.recordId = recordId;
            this.value = incotermsCode;
            this.details = incotermsDetails;

            this.label =
                String.isBlank(incotermsDetails)
                    ? incotermsCode
                    : incotermsDetails + ' - ' + incotermsCode;
        }
    }

    /**
     * Returns all available Incoterms Master values.
     */
    @AuraEnabled(cacheable=true)
    public static List<IncotermsOption>
        getIncotermsOptions() {

        validateReadAccess();

        List<IncotermsOption> options =
            new List<IncotermsOption>();

        Set<String> existingCodes =
            new Set<String>();

        List<Incoterms_Master__c> records = [
            SELECT
                Id,
                INCOTERMS__c,
                IncoTerms_Details__c
            FROM Incoterms_Master__c
            WHERE INCOTERMS__c != null
            ORDER BY
                IncoTerms_Details__c ASC,
                INCOTERMS__c ASC
        ];

        for (
            Incoterms_Master__c record :
            records
        ) {
            String code =
                record.INCOTERMS__c == null
                    ? ''
                    : record.INCOTERMS__c.trim();

            String details =
                record.IncoTerms_Details__c == null
                    ? ''
                    : record.IncoTerms_Details__c.trim();

            if (String.isBlank(code)) {
                continue;
            }

            /*
             * Prevent duplicate dropdown values when multiple
             * master records contain the same Incoterms code.
             */
            String normalizedCode =
                code.toLowerCase();

            if (
                existingCodes.contains(
                    normalizedCode
                )
            ) {
                continue;
            }

            existingCodes.add(
                normalizedCode
            );

            options.add(
                new IncotermsOption(
                    record.Id,
                    code,
                    details
                )
            );
        }

        return options;
    }

    /**
     * Validate access to the Master object and fields used
     * by the component.
     */
    private static void validateReadAccess() {

		if (
			!Incoterms_Master__c.SObjectType
				.getDescribe()
				.isAccessible()
		) {
			throw new AuraHandledException(
				'You do not have access to the InCoTerms Master object.'
			);
		}

		if (
			!Incoterms_Master__c.INCOTERMS__c
				.getDescribe()
				.isAccessible()
		) {
			throw new AuraHandledException(
				'You do not have access to the InCoTerms field.'
			);
		}

		if (
			!Incoterms_Master__c.IncoTerms_Details__c
				.getDescribe()
				.isAccessible()
		) {
			throw new AuraHandledException(
				'You do not have access to the InCoTerms Details field.'
			);
		}
	}
}