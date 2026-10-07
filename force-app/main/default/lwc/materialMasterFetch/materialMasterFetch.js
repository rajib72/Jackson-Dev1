import { LightningElement, track } from 'lwc';
import fetchMaterials from '@salesforce/apex/MaterialMasterController.fetchMaterials';
import saveMaterials from '@salesforce/apex/MaterialMasterController.saveMaterials';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class MaterialMasterFetch extends LightningElement {

    requestType = 'CREATION';
    fromDate;
    toDate;
    connectedCallback(){
        console.log('connectedCallback');
    }
    showSaveButton = false;

    @track materialData = [];

    isLoading = false;
    showEmptyMessage = false;
    showMessage = false;

    options = [
        { label: 'Creation From Date', value: 'CREATION' },
        { label: 'Changed From Date', value: 'CHANGED' }
    ];

    columns = [
        { label: 'Material Code', fieldName: 'MATERIAL_CODE' },
        { label: 'Description', fieldName: 'MATERIAL_DESCRIPTION' },
        { label: 'Plant', fieldName: 'PLANT' },
        { label: 'Distribution Channel', fieldName: 'DISTRIBUTION_CHANNEL' },
        { label: 'Sales Org', fieldName: 'SALES_ORG' },
        { label: 'Storage Location', fieldName: 'STORAGE_LOCATION' },
        { label: 'Division', fieldName: 'DIVISION' }
        //{ label: 'Material Type', fieldName: 'MATERIAL_TYPE' }
    ];


    handleTypeChange(event){
        this.requestType = event.detail.value;
    }

    handleFromDate(event){
        this.fromDate = event.target.value;
    }

    handleToDate(event){
        this.toDate = event.target.value;
    }


    fetchData(){
        this.showEmptyMessage = false;

        if(!this.fromDate || !this.toDate){

            this.showToast('Error','Please select From Date and To Date','error');
            return;
        }

        this.isLoading = true;
        //this.showSaveButton = false;

        fetchMaterials({
            requestType : this.requestType,
            fromDate : this.fromDate,
            toDate : this.toDate
        })
        .then(result=>{

            this.materialData = result;
            if(this.materialData.length > 0){
                this.showSaveButton = true;
                this.showEmptyMessage=false;
            }
            else{
                this.showEmptyMessage=true;
            }
            

            this.showToast('Success','Materials fetched successfully','success');

        })
        .catch(error=>{
             this.showSaveButton = false;

            console.error(error);

            this.showToast('Error', error.body?.message || 'Error fetching materials','error');

        })
        .finally(()=>{
            this.isLoading = false;
        });

    }



    saveData(){

        if(!this.materialData || this.materialData.length === 0){

            this.showToast('Error','No data available to save','error');
            return;
        }

        this.isLoading = true;

        saveMaterials({
            materials : JSON.parse(JSON.stringify(this.materialData))
        })
        .then(result=>{

            this.showToast('Success', result,'success');
            this.showSaveButton = false;
            this.showMessage = true;

        })
        .catch(error=>{

            console.error(error);

            this.showToast('Error', error.body?.message || 'Error saving materials','error');

        })
        .finally(()=>{
            this.isLoading = false;
        });

    }



    showToast(title, message, variant){

        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });

        this.dispatchEvent(evt);

    }

}