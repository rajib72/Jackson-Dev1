import { LightningElement, api, track } from 'lwc';
import saveFeedback from '@salesforce/apex/SRTfeedbackCOntroller.saveFeedback';
import getCaseDetails from '@salesforce/apex/SRTfeedbackCOntroller.getCaseDetails';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class SrtFeedbackForm extends LightningElement {

    _caseId;

@api
set recordId(value) {
    this._caseId = value;
    this.caseId = value;

    console.log('Record Id:', value);

    if (value) {
        this.loadCase();
    }
}

get recordId() {
    return this._caseId;
}

    @track feedbackRecord = {};

    showThankYouMessage = false;
    isSubmitting = false;
    errorMessage = '';
    thankYouTimer; 

    caseId;
    SRT_Case_No__c;
    ContactId;
    ContactPhone;
    Service_Completion_Date__c;
    comments = '';
    ContactName = '';

    // Ratings
    overallRating = 0;
    recommendationRating = 0;
    issueResolved = '';
    engineerRating = 0;
    experienceRating = 0;

//     connectedCallback() {

//     console.log('recordId => ', this.recordId);
//     console.log('caseId => ', this.caseId);

//     if (this.recordId) {
//         this.caseId = this.recordId;
//         this.loadCase();
//     } else {
//         this.errorMessage = 'Case Id not found.';
//     }
// }
    get issueResolvedOptions() {
    return [
        { label: 'Yes', value: 'Yes' },
        { label: 'Partially', value: 'Partially' },
        { label: 'No', value: 'No' }
    ];
}

    loadCase() {

    console.log('Calling Apex with Case Id:', this.caseId);

    getCaseDetails({ caseId: this.caseId })
        .then(result => {

            console.log('Apex Result:', JSON.stringify(result));

            this.SRT_Case_No__c = result.caseNumber;
            this.ContactId = result.contactId;
            this.ContactPhone = result.contactPhone;
            this.ContactName = result.contactName;

            if (result.feedbackReceived) {
                this.errorMessage = 'Feedback has already been submitted.';
            } else {
                this.errorMessage = '';
            }

        })
        .catch(error => {

            console.log('Apex Error:', JSON.stringify(error));

            this.errorMessage = error.body
                ? error.body.message
                : 'Unable to load Case.';
        });

}

    handleContactChange(event) {
        this.ContactId = event.detail.recordId;
    }

    handleContactNameChange(event) {
    this.ContactName = event.target.value;
    }

    handleMobileChange(event) {

    let phoneValue = event.target.value || '';

    // Remove non-numeric characters and restrict to 10 digits
    phoneValue = phoneValue
        .replace(/\D/g, '')
        .slice(0, 10);

    event.target.value = phoneValue;
    this.ContactPhone = phoneValue;

    event.target.setCustomValidity('');

    if (phoneValue && phoneValue.length !== 10) {
        event.target.setCustomValidity(
            'Phone / Mobile Number must contain exactly 10 digits.'
        );
    }

    event.target.reportValidity();
}


    handleServiceCompletionDate(event) {
        this.Service_Completion_Date__c = event.target.value;
    }

    handleIssueResolvedChange(event) {
    this.issueResolved = event.detail.value;
    }   

    handleComments(event) {
        this.comments = event.target.value;
    }

    // Generic star click
    handleStarClick(event) {

        const field = event.target.dataset.field;
        const value = Number(event.target.dataset.value);

        this.feedbackRecord = {
            ...this.feedbackRecord,
            [field]: value
        };

        switch (field) {

            case 'Overall_Satisfaction_CSAT__c':
                this.overallRating = value;
                break;

            case 'Would_you_recommend_Jakson_NPS__c':
                this.recommendationRating = value;
                break;

            case 'Engineer_behaviour_professionalism__c':
                this.engineerRating = value;
                break;

            case 'Response_turnaround_experience__c':
                this.experienceRating = value;
                break;

        }

    }

    // Build Stars
    buildStars(selected) {

        let arr = [];

        for (let i = 1; i <= 5; i++) {

            arr.push({
                value: i,
                class: i <= selected ? 'star selected' : 'star'
            });

        }

        return arr;

    }

    get stars() {
        return this.buildStars(this.overallRating);
    }

    get recommendationStars() {
        return this.buildStars(this.recommendationRating);
    }

    get engineerStars() {
        return this.buildStars(this.engineerRating);
    }

    get experienceStars() {
        return this.buildStars(this.experienceRating);
    }

    // Comments Required
    get isCommentRequired() {

        return (
            this.overallRating <= 3 && this.overallRating > 0 ||
            this.recommendationRating <= 3 && this.recommendationRating > 0 ||
            this.engineerRating <= 3 && this.engineerRating > 0 ||
            this.experienceRating <= 3 && this.experienceRating > 0
        );

    }

    handleSubmit() {

        this.errorMessage = '';

        if (!this.caseId) {
            this.errorMessage = 'Case Id missing.';
            return;
        }

        if (
        this.ContactPhone &&
        !/^\d{10}$/.test(this.ContactPhone)
        ) {
        this.errorMessage =
            'Phone / Mobile Number must contain exactly 10 digits.';
        return;
        }

        if (!this.Service_Completion_Date__c) {
            this.errorMessage = 'Please select Service Completion Date.';
            return;
        }

        if (!this.overallRating) {
            this.errorMessage = 'Please rate Overall Satisfaction.';
            return;
        }

        if (!this.recommendationRating) {
            this.errorMessage = 'Please rate Recommendation.';
            return;
        }

        if (!this.issueResolved) {
            this.errorMessage = 'Please select Issue Resolution.';
            return;
        }

        if (!this.engineerRating) {
            this.errorMessage = 'Please rate Engineer Behaviour.';
            return;
        }

        if (!this.experienceRating) {
            this.errorMessage = 'Please rate Overall Experience.';
            return;
        }

        if (this.isCommentRequired && (!this.comments || this.comments.trim() === '')) {
            this.errorMessage = 'Comments are mandatory when any rating is between 1 and 3.';
            return;
        }

        this.isSubmitting = true;

       saveFeedback({
    caseId: this.caseId,
    contactId: this.ContactId,
    contactName: this.ContactName,
    contactPhone: this.ContactPhone,
    serviceCompletionDate: this.Service_Completion_Date__c,
    overallSatisfaction: String(this.overallRating),
    recommendJakson: String(this.recommendationRating),
    issueResolved: this.issueResolved,
    engineerBehaviour: String(this.engineerRating),
    responseExperience: String(this.experienceRating),
    comments: this.comments
})

            .then(result => {

                this.isSubmitting = false;

                if (result.success) {
                this.showThankYouMessage = true;

                clearTimeout(this.thankYouTimer);
                this.thankYouTimer = setTimeout(() => {
                    this.showThankYouMessage = false;
                        this.dispatchEvent(new CloseActionScreenEvent());
                }, 1000);
                } else {
                this.errorMessage = result.message;
                }

            })
            .catch(error => {

                this.isSubmitting = false;

                console.error(error);

                this.errorMessage = error.body ? error.body.message : 'Unexpected error occurred.';

            });

    }
    disconnectedCallback() {
    clearTimeout(this.thankYouTimer);
}

}