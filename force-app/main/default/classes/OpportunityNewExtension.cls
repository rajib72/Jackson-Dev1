public class OpportunityNewExtension {

    public Opportunity opp { get; set; }
    public Boolean isUnderDevelopment { get; set; }
    public String rtDevName { get; set; }
    public String recordTypeName { get; set; }

    public String selectedAccountId { get; set; }
    public String selectedAccountName { get; set; }
    public String selectedContactId { get; set; }

    public Boolean isAccountPrepopulated { get; set; }
    public String prepopulatedAccountName { get; set; }

    public List<SelectOption> contactOptions { get; set; }


    public OpportunityNewExtension(
        ApexPages.StandardController stdController
    ) {

        this.opp =
            (Opportunity)stdController.getRecord();

        this.isUnderDevelopment =
            false;


        String rtId =
            this.opp.RecordTypeId;


        if (String.isBlank(rtId)) {

            rtId =
                ApexPages.currentPage()
                    .getParameters()
                    .get('RecordType');
        }


        System.debug(
            '@@@DEBUG:: this.opp :: ' +
            JSON.serialize(this.opp)
        );


        if (String.isNotBlank(rtId)) {

            List<RecordType> rtList = [
                SELECT DeveloperName, Name
                FROM RecordType
                WHERE Id = :rtId
                LIMIT 1
            ];


            if (!rtList.isEmpty()) {

                rtDevName =
                    rtList[0].DeveloperName;

                recordTypeName =
                    rtList[0].Name;


                if (rtDevName == 'Residential') {

                    isUnderDevelopment = true;

                    return;
                }


                opp.RecordTypeId =
                    rtId;


                if (rtDevName == 'KAM') {

                    opp.Key_Account_Opp_Stages__c =
                        'Qualification';

                    opp.Business_Segment__c =
                        'KAM';


                } else if (
                    rtDevName == 'KAM_SRT'
                ) {

                    opp.KAM_SRT_Opp_Stages__c =
                        'Qualification';

                    opp.Business_Segment__c =
                        'KAM (SRT)';


                } else if (
                    rtDevName == 'Commercial_Industrial'
                ) {

                    opp.C_I_Opp_Stage__c =
                        'Qualification';

                    opp.Business_Segment__c =
                        'Commercial & Industrial (SRT)';


                } else if (
                    rtDevName == 'Institutional'
                ) {

                    opp.Institutional_Opp_Stages__c =
                        'Qualification';

                    opp.Business_Segment__c =
                        'Institutional';
                    
                    opp.Tender_Type__c =
                        'Module';


                } else if (
                    rtDevName == 'Retail'
                ) {

                    opp.Retail_Opp_Stages__c =
                        'Qualification';

                    opp.Business_Segment__c =
                        'Retail';
                }
            }
        }


        /*
         * ACCOUNT PREPOPULATION
         */

        if (
            String.isNotBlank(
                this.opp.AccountId
            )
        ) {

            selectedAccountId =
                this.opp.AccountId;


        } else if (
            String.isNotBlank(
                this.opp.Partner_Assigned__c
            )
        ) {

            selectedAccountId =
                this.opp.Partner_Assigned__c;
        }


        if (
            String.isNotBlank(
                selectedAccountId
            )
        ) {

            isAccountPrepopulated =
                true;


            try {

                Account acc = [
                    SELECT Id, Name
                    FROM Account
                    WHERE Id = :selectedAccountId
                    LIMIT 1
                ];


                prepopulatedAccountName =
                    acc.Name;

                selectedAccountName =
                    acc.Name;


            } catch (Exception e) {

                prepopulatedAccountName = '';
                selectedAccountName = '';
            }


        } else {

            isAccountPrepopulated =
                false;

            selectedAccountName =
                '';
        }


        loadContactOptions();


        /*
         * DEFAULT VALUES
         */

        opp.Probability =
            10;



        /*
         * DEFAULT CLOSE DATE
         *
         * For a brand-new Opportunity, CreatedDate is not available
         * until after insert. Therefore Date.today() represents the
         * creation date for this New Opportunity page.
         *
         * Do not overwrite CloseDate when Salesforce has already
         * populated it, for example from another creation flow.
         */

        if (opp.CloseDate == null) {

            opp.CloseDate =
                Date.today().addMonths(1);
        }


        String currentMonth =
            Datetime.now().format('MMM');

        String currentYear =
            Datetime.now().format('yyyy');


        String accNameForTitle =
            isAccountPrepopulated
            ? prepopulatedAccountName
            : '';


        opp.Name =
            'SLR/' +
            currentMonth +
            '/' +
            currentYear +
            '/' +
            recordTypeName +
            (
                String.isNotBlank(
                    accNameForTitle
                )
                ? '/' + accNameForTitle
                : ''
            );


        /*
         * INTERNAL BUSINESS TEAM
         */

        User currentUser = [
            SELECT Internal_Business_Team__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];


        opp.Internal_Business_Team__c =
            currentUser.Internal_Business_Team__c;
    }


    /*
     * ACCOUNT LOOKUP SEARCH
     */

    @RemoteAction
    public static List<AccountLookupWrapper>
        searchAccountsRemote(
            String searchKey
        ) {

        List<AccountLookupWrapper> resultList =
            new List<AccountLookupWrapper>();


        List<Account> accList;


        if (
            String.isBlank(searchKey)
        ) {

            accList = [
                SELECT Id, Name
                FROM Account
                ORDER BY Name
                LIMIT 999
            ];


        } else {

            String keyword =
                String.escapeSingleQuotes(
                    searchKey.trim()
                ) + '%';


            accList = [
                SELECT Id, Name
                FROM Account
                WHERE Name LIKE :keyword
                ORDER BY Name
                LIMIT 999
            ];
        }


        for (
            Account acc : accList
        ) {

            resultList.add(
                new AccountLookupWrapper(
                    acc.Id,
                    acc.Name
                )
            );
        }


        return resultList;
    }


    /*
     * ACCOUNT LOOKUP WRAPPER
     */

    public class AccountLookupWrapper {

        public String id { get; set; }
        public String name { get; set; }


        public AccountLookupWrapper(
            Id accountId,
            String accountName
        ) {

            this.id =
                String.valueOf(accountId);

            this.name =
                accountName;
        }
    }


    /*
     * ACCOUNT CHANGE
     */

    public void onAccountChange() {

        selectedContactId =
            null;

        selectedAccountName =
            '';


        if (
            String.isNotBlank(
                selectedAccountId
            )
        ) {

            try {

                Account acc = [
                    SELECT Id, Name
                    FROM Account
                    WHERE Id = :selectedAccountId
                    LIMIT 1
                ];


                selectedAccountName =
                    acc.Name;


            } catch (Exception e) {

                selectedAccountName =
                    '';
            }
        }


        loadContactOptions();


        String currentMonth =
            Datetime.now().format('MMM');

        String currentYear =
            Datetime.now().format('yyyy');


        opp.Name =
            'SLR/' +
            currentMonth +
            '/' +
            currentYear +
            '/' +
            recordTypeName +
            (
                String.isNotBlank(
                    selectedAccountName
                )
                ? '/' + selectedAccountName
                : ''
            );
    }


    /*
     * CONTACT OPTIONS
     */

    private void loadContactOptions() {

        contactOptions =
            new List<SelectOption>();


        contactOptions.add(
            new SelectOption(
                '',
                '-- None --'
            )
        );


        if (
            String.isNotBlank(
                selectedAccountId
            )
        ) {

            for (
                Contact con : [
                    SELECT Id, Name
                    FROM Contact
                    WHERE AccountId = :selectedAccountId
                    ORDER BY Name
                    LIMIT 999
                ]
            ) {

                contactOptions.add(
                    new SelectOption(
                        con.Id,
                        con.Name
                    )
                );
            }
        }
    }


    /*
     * MARKET SEGMENT CHANGE
     */

    public void onMarketSegmentChange() {

        if (
            opp.Market_Segment__c !=
            'Others'
        ) {

            opp.Market_Segment_Others__c =
                null;
        }
    }


    /*
     * OPPORTUNITY SOURCE CHANGE
     */

    public void onOpportunitySourceChange() {

        if (
            opp.LeadSource !=
            'Others'
        ) {

            opp.Opportunity_Source_Others__c =
                null;
        }
    }


    /*
     * SAVE OPPORTUNITY
     */

    public PageReference saveRecord() {

        try {

            Boolean hasValidationError =
                false;


            /*
             * CLOSE DATE VALIDATION
             */

            if (
                opp.CloseDate != null &&
                opp.CloseDate < Date.today()
            ) {

                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.ERROR,
                        'Close Date cannot be in the past. Please select today or a future date.'
                    )
                );


                hasValidationError =
                    true;
            }


            /*
             * RATING + EXPECTED CLOSURE DATE
             *
             * ONLY APPLICABLE FOR:
             * KAM
             * Institutional
             * Retail
             *
             * BOTH FIELDS ARE MANDATORY.
             */

            Boolean showAdditionalFields =
                rtDevName == 'KAM' ||
                rtDevName == 'Institutional' ||
                rtDevName == 'Retail';


            if (
                showAdditionalFields &&
                String.isBlank(opp.Rating__c)
            ) {

                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.ERROR,
                        'Rating is required.'
                    )
                );

                hasValidationError = true;
            }


            if (
                showAdditionalFields &&
                opp.Expected_Closure_Date__c == null
            ) {

                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.ERROR,
                        'Expected Closure Date is required.'
                    )
                );

                hasValidationError = true;
            }


            if (
                showAdditionalFields &&
                opp.Expected_Closure_Date__c != null &&
                opp.Expected_Closure_Date__c < Date.today()
            ) {

                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.ERROR,
                        'Expected Closure Date cannot be in the past. Please select today or a future date.'
                    )
                );

                hasValidationError = true;
            }


            if (
                rtDevName == 'Institutional' &&
                opp.Tender_Due_Date__c != null &&
                opp.Tender_Due_Date__c < Date.today()
            ) {

                ApexPages.addMessage(
                    new ApexPages.Message(
                        ApexPages.Severity.ERROR,
                        'Tender Due Date cannot be in the past. Please select today or a future date.'
                    )
                );

                hasValidationError =
                    true;
            }


            if (
                hasValidationError
            ) {

                return null;
            }


            opp.StageName =
                'Qualification';


            opp.AccountId =
                String.isNotBlank(
                    selectedAccountId
                )
                ? selectedAccountId
                : null;


            opp.Contact__c =
                String.isNotBlank(
                    selectedContactId
                )
                ? selectedContactId
                : null;


            insert opp;


            PageReference redirectPage =
                new PageReference(
                    '/' + opp.Id
                );


            redirectPage.setRedirect(
                true
            );


            return redirectPage;


        } catch (
            Exception e
        ) {

            ApexPages.addMessages(
                e
            );


            return null;
        }
    }
}