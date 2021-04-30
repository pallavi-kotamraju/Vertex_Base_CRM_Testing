import { LightningElement, track, api, wire } from 'lwc';
import { getRecord, getFieldValue, updateRecord  } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// *************************** RESOURCES ********************************
//  Logo
import VERTEX_LOGO from '@salesforce/resourceUrl/VertLogo';

// *************************** METHODS and OBJECTS **********************
//  Method to validate address
import checkAddress from '@salesforce/apex/ValidateAndUpdateAddress.checkAddress';
import isValidationEnabled from '@salesforce/apex/ValidateAndUpdateAddress.isValidationEnabled';

//  Bind non-standard address fields
import ACCOUNT_SHIPPINGADDRESSVALID_FIELD from '@salesforce/schema/Account.ShippingAddressValid__c';
import ACCOUNT_BILLINGADDRESSVALID_FIELD from '@salesforce/schema/Account.BillingAddressValid__c';

//  No need to bind standard fields
const FIELDS = [
    'Account.ShippingStreet',
    'Account.ShippingCity',
    'Account.ShippingState',
    'Account.ShippingPostalCode',
    'Account.ShippingCountry',
    'Account.BillingStreet',
    'Account.BillingCity',
    'Account.BillingState',
    'Account.BillingPostalCode',
    'Account.BillingCountry',
    ACCOUNT_SHIPPINGADDRESSVALID_FIELD,
    ACCOUNT_BILLINGADDRESSVALID_FIELD
];

const VALIDCOUNTRIES = [
    'USA',
    'UNITED STATES',
    'UNITED STATES OF AMERICA',
    'US'
]


export default class VertexAddressValidation extends LightningElement {
    @api recordId;
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS }) 
    record;

    @track isEnabled = true;
    @track isLoading = true;

    vertexLogoUrl = VERTEX_LOGO;

    @track openmodel = false;

    @track showBillingBtns = false;
    @track billingPassIcon = false;

    @track showShippingBtns = false;
    @track shippingPassIcon = false;

    @track addressToTest = {};
    @track addressResponse = {};
    @track typeBeingChecked;
    @track errorMsg = '';

    connectedCallback(){
    }

    renderedCallback(){
        this.checkShippingAddress();
        this.checkBillingAddress();
        this.checkIsEnabled();
    }

    get billingText(){
        var billingTxt;
        if (getFieldValue(this.record.data, ACCOUNT_BILLINGADDRESSVALID_FIELD)  === true){
            billingTxt = 'Billing Address is correct';
        }
        else{
            //  Perform address check
            billingTxt = 'Billing Address may be incorrect'
        }
        return billingTxt;
    }

    get shippingText(){
        var shippingTxt;
        if (getFieldValue(this.record.data, ACCOUNT_SHIPPINGADDRESSVALID_FIELD)  === true){
            shippingTxt = 'Shipping Address is correct';
        }
        else{
            //  Perform address check
            shippingTxt = 'Shipping Address may be incorrect'
        }
        return shippingTxt;
    }

    checkBillingAddress(){
        if (getFieldValue(this.record.data, ACCOUNT_BILLINGADDRESSVALID_FIELD)  === true){
            this.billingPassIcon = true;
            this.showBillingBtns = false;
        }
        else{
            //  Perform address check
            this.billingPassIcon = false;
            this.showBillingBtns = true;
        }
    }

    checkShippingAddress(){
        if (getFieldValue(this.record.data, ACCOUNT_SHIPPINGADDRESSVALID_FIELD)  === true){
            this.shippingPassIcon = true;
            this.showShippingBtns = false
        }
        else{
            this.shippingPassIcon = false;
            this.showShippingBtns = true;
        }
    }

    closeModal() {
        this.openmodel = false;
    } 

    lookupAddress(event){
        var addyType = event.currentTarget.dataset.addresstype;
        var addyTypeCapped = addyType.charAt(0).toUpperCase() + addyType.slice(1);
        //  Reset possible error:
        this.errorMsg = '';

        if(getFieldValue(this.record.data, 'Account.'+addyTypeCapped+'Country') && VALIDCOUNTRIES.includes( getFieldValue(this.record.data, 'Account.'+addyTypeCapped+'Country').toUpperCase() )){
            checkAddress({id: this.recordId, type: addyType})
            .then(result => {
                this.addressToTest = {
                    "Address1__c"   : getFieldValue(this.record.data, 'Account.'+addyTypeCapped+'Street' ),
                    "City__c"       : getFieldValue(this.record.data, 'Account.'+addyTypeCapped+'City'),
                    "State__c"      : getFieldValue(this.record.data, 'Account.'+addyTypeCapped+'State'),
                    "PostalCode__c" : getFieldValue(this.record.data, 'Account.'+addyTypeCapped+'PostalCode'),
                    "Country__c"    : getFieldValue(this.record.data, 'Account.'+addyTypeCapped+'Country')
                };
                this.addressResponse = result;
                this.typeBeingChecked = addyType;
                if(result.Vertex__TaxAreaID__c === 'ERROR'){
                    this.errorMsg = 'ERROR: ' + result.Vertex__Address1__c;
                }
            });
        }
        else {
            this.addressToTest = {
                "Address1__c"   : getFieldValue(this.record.data, 'Account.'+addyTypeCapped+'Street' ),
                "City__c"       : getFieldValue(this.record.data, 'Account.'+addyTypeCapped+'City'),
                "State__c"      : getFieldValue(this.record.data, 'Account.'+addyTypeCapped+'State'),
                "PostalCode__c" : getFieldValue(this.record.data, 'Account.'+addyTypeCapped+'PostalCode'),
                "Country__c"    : getFieldValue(this.record.data, 'Account.'+addyTypeCapped+'Country')
            };
            this.errorMsg = 'Cannot validate non-US addresses';
        }
        
        this.openmodel = true;
    }

    approveAddress(event){
        var addyType = event.currentTarget.dataset.addresstype;
        var addyTypeCapped = addyType.charAt(0).toUpperCase() + addyType.slice(1);
        const fields = {};
        fields.Id = this.recordId;
        fields['Vertex__'+addyTypeCapped+'AddressValid__c'] = true;
        const approveRI = { fields };
        
        updateRecord(approveRI)
        .then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Address Accepted As-is',
                    variant: 'success'
                })
            );
        });
    }

    correctAddress(){
        var addyType = this.typeBeingChecked;
        var addyTypeCapped = addyType.charAt(0).toUpperCase() + addyType.slice(1);
        const fields = {};
        fields.Id = this.recordId;
        fields['Vertex__'+addyTypeCapped+'AddressValid__c'] = true;
        fields[addyTypeCapped+'Street'] = this.addressResponse.Vertex__Address1__c;
        fields[addyTypeCapped+'City'] = this.addressResponse.Vertex__City__c;
        fields[addyTypeCapped+'State'] = this.addressResponse.Vertex__State__c;
        fields[addyTypeCapped+'PostalCode'] = this.addressResponse.Vertex__PostalCode__c;
        fields[addyTypeCapped+'Country'] = this.addressResponse.Vertex__Country__c;

        const updateRI = { fields };
        updateRecord(updateRI)
        .then(() => {
            this.closeModal();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: addyTypeCapped+' Address Updated',
                    variant: 'success'
                })
            );
        });
    }

    get checkError(){
        var hasError;
        if (this.errorMsg === '')
            hasError = false;
        else
            hasError = true;
        return hasError;
    }

    checkIsEnabled(){
        isValidationEnabled()
            .then(result => {
                this.isEnabled = result;
                this.isLoading = false;
            });
    }

}