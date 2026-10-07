import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import JaksonLogo from '@salesforce/resourceUrl/JaksonLogo';


import getInitData from '@salesforce/apex/InstTermSheetController.getInitData';
import createTermSheetAndLineItems from '@salesforce/apex/InstTermSheetController.createTermSheetAndLineItems';

export default class InstTermSheetLWC extends LightningElement {
_recordId;

@api
get recordId() {
return this._recordId;
}

set recordId(value) {
this._recordId = value;

if (value && !this.hasLoaded) {
    this.hasLoaded = true;
    this.loadInitData();
}
}

@track isLoading = false;
@track productRows = [];
@track selectedRowIds = [];
@track isFirstStep = true;

jaksonLogo = JaksonLogo;
hasLoaded = false;
modalStyleApplied = false;
modalStyleId = 'inst-termsheet-modal-fix';

opportunityName = '';
accountName = '';
termSheetName = '';

issueDateDisplay = '';
issueDateDb = '';

docNo = '';
revNo = '';

tenderName = '';
projectCapacity = '';
agreedPrice = '';
deliverySchedule = '';
paymentTerm = '';
ldClause = '';

yesNoOptions = [
{ label: 'Yes', value: 'Yes' },
{ label: 'No', value: 'No' }
];

// get selectedCount() {
//     return this.selectedRowIds.length;
// }
// get selectedCount() {
// return this.productRows.length;
// }
renderedCallback() {
if (this.modalStyleApplied) {
    return;
}

this.modalStyleApplied = true;

if (!document.getElementById(this.modalStyleId)) {
    const style = document.createElement('style');
    style.id = this.modalStyleId;

    style.innerText = `
        .slds-modal__container {
            width: 96vw !important;
            max-width: 96vw !important;
        }

        .slds-modal__content {
            overflow-x: auto !important;
        }

        @media (max-width: 768px) {
            .slds-modal__container {
                width: 100vw !important;
                max-width: 100vw !important;
                margin: 0 !important;
            }
        }
    `;

    document.head.appendChild(style);
}
}

disconnectedCallback() {
const style = document.getElementById(this.modalStyleId);

if (style) {
    style.remove();
}
}

async loadInitData() {
this.isLoading = true;

try {
    const {
        quoteLines = [],
        opp,
        todayDateDisplay,
        todayDateDb,
        revNo
    } = await getInitData({ opportunityId: this.recordId });

//         this.productRows = (quoteLines || []).map((row, i) => {
//             const binApplicable = row.binPercentageInput || 'No';
//             this.selectedRowIds = this.productRows.map(
// row => row.quoteLineItemId
// );

//             return {
//                 quoteLineItemId: row.quoteLineItemId,
//                 srNo: i + 1,

//                 productId: row.productId || '',
//                 productName: row.productName || '',
//                 opportunityProductId: row.opportunityProductId || '',

//                 materialDescription: row.materialDescription || '',

//                 moduleType: row.moduleType || '',
//                 moduleTechnology: row.moduleTechnology || '',
//                 productRatingBin: row.productRatingBin || '',
//                 productSubType: row.productSubType || '',
//                 cableLength: row.cableLength ? `${row.cableLength} mm` : '',
//                 warranty: row.warranty || '',

//                 nos: row.nos || '',
//                 projectCapacity: row.projectCapacity || '',
//                 uom: row.uom || '',
//                 capacityInKW: row.capacityInKW || '',
//                 priceWp: row.priceWp || '',
//                 total: row.total || '',
//                 gst: row.gst || '',
//                 grandTotal: row.grandTotal || '',

//                 binPercentageInput: binApplicable,
//                 binPercentageValueInput: row.binPercentageValueInput || '',
//                 showBinPercentageValue: binApplicable === 'Yes',

//                 moduleEfficiencyCriteriaInput: row.moduleEfficiencyCriteriaInput || '',
//                 systemVoltageInput: row.systemVoltageInput || '',


//                 isSelected: true
//             };
//         });

this.productRows = (quoteLines || []).map((row, i) => {

const binApplicable = row.binPercentageInput || 'No';

return {
    quoteLineItemId: row.quoteLineItemId,
    srNo: i + 1,

    productId: row.productId || '',
    productName: row.productName || '',
    opportunityProductId: row.opportunityProductId || '',

    materialDescription: row.materialDescription || '',

    moduleType: row.moduleType || '',
    moduleTechnology: row.moduleTechnology || '',
    productRatingBin: row.productRatingBin || '',
    productSubType: row.productSubType || '',
    cableLength: row.cableLength ? `${row.cableLength} mm` : '',
    warranty: row.warranty || '',

    nos: row.nos || '',
    projectCapacity: row.projectCapacity || '',
    uom: row.uom || '',
    capacityInKW: row.capacityInKW || '',
    priceWp: row.priceWp || '',
    total: row.total || '',
    gst: row.gst || '',
    grandTotal: row.grandTotal || '',

    binPercentageInput: binApplicable,
    binPercentageValueInput: row.binPercentageValueInput || '',
    showBinPercentageValue: binApplicable === 'Yes',

    moduleEfficiencyCriteriaInput: row.moduleEfficiencyCriteriaInput || '',
    systemVoltageInput: row.systemVoltageInput || '',

    isSelected: true
};
});

// IMPORTANT
this.selectedRowIds = this.productRows.map(
row => row.quoteLineItemId
);

    if (opp) {
        this.opportunityName = opp.Name || '';
        this.accountName = opp.Account?.Name || '';
        this.termSheetName = `TS - ${opp.Name || ''}`;
        this.docNo = opp.Name || '';
        this.tenderName = opp.Tender_Name__c || '';
    }

    this.revNo = revNo || '';
    this.issueDateDisplay = todayDateDisplay || '';
    this.issueDateDb = todayDateDb || '';
} catch (e) {
    this.toast('Error', this.getError(e), 'error');
} finally {
    this.isLoading = false;
}
}

handleInputChange(e) {
const fieldName = e.target.dataset.field;
this[fieldName] = e.detail?.value ?? e.target.value;
}

handleProductSelect(e) {
const rowId = e.target.dataset.id;
const isChecked = e.target.checked;

this.productRows = this.productRows.map(row => {
    if (row.quoteLineItemId === rowId) {
        return {
            ...row,
            isSelected: isChecked
        };
    }

    return row;
});

// this.selectedRowIds = this.productRows
//     .filter(row => row.isSelected)
//     .map(row => row.quoteLineItemId);
}

handleProductRowChange(e) {
    const rowId = e.target.dataset.id;
    const field = e.target.dataset.field;
    const value = e.detail?.value ?? e.target.value;

    this.productRows = this.productRows.map(row => {
        if (row.quoteLineItemId !== rowId) {
            return row;
        }

        const updatedRow = {
            ...row,
            [field]: value
        };

        if (field === 'binPercentageInput') {
            updatedRow.showBinPercentageValue = value === 'Yes';

            if (value !== 'Yes') {
                updatedRow.binPercentageValueInput = '';
            }
        }

        return updatedRow;
    });
}



async handleSave() 
{
// if (!this.selectedRowIds.length) {
//     this.toast('Error', 'Select at least one line item.', 'error');
//     return;
// }

const requiredHeaderFields = [
    'tenderName',
    'projectCapacity',
    'agreedPrice',
    'deliverySchedule',
    'paymentTerm',
    'ldClause'
];

let allValid = true;

requiredHeaderFields.forEach(field => {
    const input = this.template.querySelector(`lightning-input[data-field="${field}"]`);

    if (input) {
        input.reportValidity();

        if (!input.checkValidity()) {
            allValid = false;
        }
    }

    if (!this[field]) {
        allValid = false;
    }
});

if (!allValid) {
    this.toast('Error', 'Please fill all required header fields.', 'error');
    return;
}

// const selectedRows = this.productRows.filter(row => row.isSelected);
const selectedRows = [...this.productRows];

const invalidRow = selectedRows.find(row => {
    return !row.materialDescription ||
        !row.nos ||
        !row.projectCapacity ||
        !row.uom ||
        !row.priceWp ||
        !row.total ||
        !row.gst ||
        !row.grandTotal ||
        !row.binPercentageInput ||
        !row.moduleEfficiencyCriteriaInput ||
        !row.systemVoltageInput ||
        (row.binPercentageInput === 'Yes' && !row.binPercentageValueInput);
});


if (invalidRow) {

    this.toast(
        'Error',
        'Please fill all required column values for selected line items.',
        'error'
    );
    return ;
}

this.isLoading = true;

try {
    const payload = {
        termSheetName: this.termSheetName,
        docNo: this.docNo,
        revNo: this.revNo,
        issueDate: this.issueDateDb,

        tenderName: this.tenderName,
        projectCapacity: this.projectCapacity,
        agreedPrice: this.agreedPrice,
        deliverySchedule: this.deliverySchedule,
        paymentTerm: this.paymentTerm,
        ldClause: this.ldClause,

        productRows: selectedRows
    };


    // await createTermSheetAndLineItems({
    //     opportunityId: this.recordId,
    //     selectedIdsJson: JSON.stringify(this.selectedRowIds),
    //     reqJson: JSON.stringify(payload)
    // });

    const allIds = this.productRows.map(row => row.quoteLineItemId);

console.log('All Quote Line Ids', JSON.stringify(allIds));

await createTermSheetAndLineItems({
opportunityId: this.recordId,
selectedIdsJson: JSON.stringify(allIds),
reqJson: JSON.stringify(payload)
});

    this.toast('Success', 'Term Sheet created successfully.', 'success');
    this.handleCancel();
} catch (e) {
    this.toast('Error', this.getError(e), 'error');
} finally {
    this.isLoading = false;
}
System.debug('selectedQuoteLineIds = ' + selectedQuoteLineIds);
System.debug('selectedQliList size = ' + selectedQliList.size());
}

handleCancel() {
this.dispatchEvent(new CloseActionScreenEvent());
}

toast(title, message, variant) {
this.dispatchEvent(
    new ShowToastEvent({
        title,
        message,
        variant
    })
);
}

getError(e) {
return e?.body?.message || e?.message || 'Unknown error';
}
}