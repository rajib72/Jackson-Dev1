import { LightningElement } from 'lwc';
import saveFeedback from '@salesforce/apex/FeedbackController.saveFeedback';
import getCaseNumber from '@salesforce/apex/FeedbackController.getCaseNumber';

export default class FeedbackForm_lwc extends LightningElement {

    showThankYouMessage = false;
    isSubmitting = false;
    errorMessage = '';

    feedbackRecord = {};
    caseId;
    caseNumber;

    scaleNumbers = [0,1,2,3,4,5,6,7,8,9,10];

    installationOptions = [
        {label:'Residential', value:'Residential'},
        {label:'Commercial', value:'Commercial'},
        {label:'Industrial', value:'Industrial'},
        {label:'Other', value:'Other'}
    ];

    connectedCallback(){
        // Get Case Id from URL
        const urlParams = new URLSearchParams(window.location.search);
        this.caseId = urlParams.get('id');
       
        // console.log('CaseId from URL:', this.caseId);

        if(this.caseId){
        this.loadCaseNumber();
    } else {
        this.errorMessage = 'Invalid URL. Case Id missing';
    }
    }

    loadCaseNumber(){
    getCaseNumber({ caseId: this.caseId })
        .then(result => {
            this.caseNumber = result;
        })
        .catch(error => {
            console.error(error);
            this.errorMessage = 'Unable to load Case Number';
        });
}



    handleChange(event){

        const field = event.target.name;
        const value = event.target.value;

        this.feedbackRecord = {
            ...this.feedbackRecord,
            [field]: value
        };

        if(field === 'Installation_Type__c' && value !== 'Other'){
            this.feedbackRecord.Other__c = null;
        }
    }

    handleRating(event){

        const field = event.target.dataset.field;
        const value = event.target.dataset.value;

        this.feedbackRecord[field] = value;

        const buttons = this.template.querySelectorAll(
            `button[data-field="${field}"]`
        );

        buttons.forEach(btn => {
            btn.classList.remove('selected-rating');
        });

        event.target.classList.add('selected-rating');
    }

    get showOtherInstallation() {
        return this.feedbackRecord?.Installation_Type__c === 'Other';
    }

    handleKeyPress(event) {
    const charCode = event.which ? event.which : event.keyCode;

    // Allow only numbers (0–9)
    if (charCode < 48 || charCode > 57) {
        event.preventDefault();
    }
}

    handleSubmit(){

        console.log('Submit button clicked');

        this.errorMessage = '';

        if(!this.caseId){
            this.errorMessage = 'Invalid feedback link. Case Id missing.';
            return;
        }

        if(!this.feedbackRecord.Did_our_Service_Engineer_help_resolve_yo__c){
            this.errorMessage = "Please rate Question 5";
            return;
        }

        if(!this.feedbackRecord.How_would_you_rate_the_speed_of_issue_re__c){
            this.errorMessage = "Please rate Question 6";
            return;
        }

        if(!this.feedbackRecord.How_likely_are_you_to_recommend_us_to_a__c){
            this.errorMessage = "Please rate Question 8";
            return;
        }

        this.isSubmitting = true;

        const feedbackObj = {
            sobjectType: 'Feedback_Form__c',
            Installation_Type__c: this.feedbackRecord.Installation_Type__c,
            Please_Enter_Your_Name__c: this.feedbackRecord.Please_Enter_Your_Name__c,
            State__c: this.feedbackRecord.State__c,
            Mobile_Number__c: this.feedbackRecord.Mobile_Number__c,
            Did_our_Service_Engineer_help_resolve_yo__c: this.feedbackRecord.Did_our_Service_Engineer_help_resolve_yo__c,
            How_would_you_rate_the_speed_of_issue_re__c: this.feedbackRecord.How_would_you_rate_the_speed_of_issue_re__c,
            How_likely_are_you_to_recommend_us_to_a__c: this.feedbackRecord.How_likely_are_you_to_recommend_us_to_a__c,
            How_can_we_enhance_our_product_or_servic__c: this.feedbackRecord.How_can_we_enhance_our_product_or_servic__c,
            Other__c: this.feedbackRecord.Other__c
        };

        console.log('Sending object to Apex:', JSON.stringify(feedbackObj));

        saveFeedback({
            feedback: feedbackObj,
            caseId: this.caseId
        })
        .then(result => {

            console.log('Apex response:', result);

            if(result.success){
                this.showThankYouMessage = true;
            } 
            else{
                this.errorMessage = result.message;
            }

            this.isSubmitting = false;
        })
        .catch(error => {

            console.error(error);

            this.errorMessage = 'Error saving feedback';

            this.isSubmitting = false;
        });

    }
}