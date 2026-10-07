import { LightningElement, wire, track, api } from 'lwc';
import getMilestones from '@salesforce/apex/ProjectMilestoneController.getMilestones';
import saveProjectMilestones from '@salesforce/apex/ProjectMilestoneController.saveProjectMilestones';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class MilestonePopup extends LightningElement {

    @api recordId;

    @track milestoneOptions = [];
    @track dropdownList = [];

    counter = 1;

    connectedCallback(){
        this.dropdownList = [
            { id: 0, value: '', options: [],showRemove:false }
        ];
    }

    @wire(getMilestones)
    wiredMilestones({data,error}){

        if(data){

            this.milestoneOptions = data.map(item => ({
                label: item.Milestone_Name__c,
                value: item.Milestone_Name__c
            }));

            this.refreshOptions();
        }
        else if(error){
            console.error(error);
        }
    }

    handleChange(event){

        const index = event.target.dataset.index;
        const value = event.detail.value;

        this.dropdownList[index].value = value;

        this.refreshOptions();
    }

    addDropdown(){

        this.dropdownList = [
            ...this.dropdownList,
            { id: this.counter++, value: '', options: [] ,showRemove:true}
        ];

        this.refreshOptions();
    }
    removeDropdown(event){

    const index = event.target.dataset.index;

    this.dropdownList.splice(index,1);

    this.dropdownList = [...this.dropdownList];

    this.refreshOptions();
  }

    refreshOptions(){

        const selectedValues = this.dropdownList
            .map(d => d.value)
            .filter(v => v);

        this.dropdownList = this.dropdownList.map(row => {

            const filtered = this.milestoneOptions.filter(option =>
                !selectedValues.includes(option.value) || option.value === row.value
            );

            return {
                ...row,
                options: filtered
            };
        });

    }

    handleSave(){

        let selectedValues = this.dropdownList
            .map(item => item.value)
            .filter(v => v);

        if(selectedValues.length === 0){

            this.dispatchEvent(
                new ShowToastEvent({
                    title:'Error',
                    message:'Please select milestone',
                    variant:'error'
                })
            );
            return;
        }

        saveProjectMilestones({
            projectId:this.recordId,
            milestoneNames:selectedValues
        })
        .then(()=>{

            this.dispatchEvent(
                new ShowToastEvent({
                    title:'Success',
                    message:'Milestones added successfully',
                    variant:'success'
                })
            );

            this.dispatchEvent(new CloseActionScreenEvent());

        })
        .catch(error=>{
            console.error(error);
        });

    }

    handleClose(){
        this.dispatchEvent(new CloseActionScreenEvent());
    }

}