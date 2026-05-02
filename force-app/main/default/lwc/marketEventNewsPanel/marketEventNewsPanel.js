import { LightningElement, track } from 'lwc';
import getLatestNegativeEvent from '@salesforce/apex/MarketEventNewsController.getLatestNegativeEvent';
import getImpactedCustomers from '@salesforce/apex/MarketEventNewsController.getImpactedCustomers';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import notifyCustomer from '@salesforce/apex/MarketEventNewsController.notifyCustomer';
import { NavigationMixin } from 'lightning/navigation';
import findAccountByName from '@salesforce/apex/MarketEventNewsController.findAccountByName';
import { FlowNavigationNextEvent } from 'lightning/flowSupport';
import runEmailFlow from '@salesforce/apex/MarketEventNewsController.runEmailFlow';

export default class MarketEventNewsPanel extends NavigationMixin(LightningElement) {

    @track event;
    @track customers = [];
    @track columns = [];
    showFlow = false;
    flowInputVariables = [];

    selectedLevel = '';
    isLoading = false;

    connectedCallback() {
        this.loadEvent();
    }

    async loadEvent() {
        this.isLoading = true;
        try {
            const result = await getLatestNegativeEvent();
            this.event = result;
        } catch (error) {
            console.error('Error loading event', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleFilter(event) {
        this.selectedLevel = event.target.dataset.level;

        if (!this.event?.Industry__c) {
            console.warn('Industry not available yet');
            return;
        }

        this.isLoading = true;

        try {
            const result = await getImpactedCustomers({
                level: this.selectedLevel,
                industry: this.event.Industry__c
            });

            const field = this.getDynamicField();

this.customers = (result || []).map(row => {

    let value = Number(row[field]); // exposure %
    let impactScore = Number(this.event?.Impact_Percentage__c);

    let impactPercent = 0;

    if (!isNaN(value) && !isNaN(impactScore)) {
        impactPercent = value * (impactScore / 10);
    }

    return {
        ...row,
        accountId: row.Id,
        formattedPercent: value ? Math.round(value) + '%' : '0%',
        impactPercentFormatted: impactPercent
            ? Math.round(impactPercent) + '%'
            : '0%'
    };
});
            this.setColumns();
        } catch (error) {
            console.error('Error loading customers', error);
            this.customers = [];
        } finally {
            this.isLoading = false;
        }
    }

    setColumns() {
    this.columns = [
        {
            label: 'Customer Name',
            type: 'button',
            typeAttributes: {
                label: { fieldName: 'Customer_Name__c' },
                name: 'openAccount',
                variant: 'base'
            },
            cellAttributes: {
                alignment: 'center'
            }
        },
        {
            label: 'Portfolio',
            fieldName: 'Total_Portfolio__c',
            type: 'currency',
            typeAttributes: {
                currencyCode: 'INR'
            },
            cellAttributes: {
                alignment: 'center'
            }
        },
        {
            label: 'industry Exposure Percent %',
            fieldName: 'formattedPercent',
            type: 'text',
            cellAttributes: {
                alignment: 'center'
            }
        },
        {
            label: 'Portfolio Impacted %',
            fieldName: 'impactPercentFormatted',
            type: 'text',
            cellAttributes: {
                alignment: 'center'
            }
        },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [
                    { label: 'Notify Customer', name: 'notify' },
                    { label: 'View Account', name: 'view' },
                    { label: 'Send Email', name: 'send_email' }
                ]
            }
        }
    ];
}

    getDynamicField() {
        const industry = this.event?.Industry__c?.toLowerCase()?.trim();

        if (!industry) return 'Financials_Percentage__c';

        if (industry.includes('it') || industry.includes('tech') || industry.includes('technology'))
            return 'Technology_Percentage__c';

        if (industry.includes('bank') || industry.includes('financial'))
            return 'Financials_Percentage__c';

        if (industry.includes('pharma') || industry.includes('health'))
            return 'Healthcare_Percentage__c';

        if (industry.includes('fmcg'))
            return 'FMCG_Percentage__c';

        if (industry.includes('energy'))
            return 'Energy_Percentage__c';

        if (industry.includes('telecom'))
            return 'Telecom_Percentage__c';

        if (industry.includes('industrial'))
            return 'Industrials_Percentage__c';

        if (industry.includes('material'))
            return 'Materials_Percentage__c';

        if (industry.includes('utility'))
            return 'Utilities_Percentage__c';

        return 'Financials_Percentage__c'; 
    }

    get title() {
        return this.event?.News_Title__c || this.event?.Name || 'No Title';
    }

    get summary() {
        return this.event?.News_Summary__c || 'No summary available';
    }

    get suggestion() {
        return this.event?.News_Suggestion__c || 'No suggestion available';
    }

    get highClass() {
        return this.selectedLevel === 'High' ? 'btn high active' : 'btn high';
    }

    get mediumClass() {
        return this.selectedLevel === 'Medium' ? 'btn medium active' : 'btn medium';
    }

    get lowClass() {
        return this.selectedLevel === 'Low' ? 'btn low active' : 'btn low';
    }

    get hasCustomers() {
        return this.customers && this.customers.length > 0;
    }
    async handleRefresh() {
    this.isLoading = true;

    try {
        await this.loadEvent();

        this.customers = [];
        this.selectedLevel = '';

    } catch (error) {
        console.error('Refresh error', error);
    } finally {
        this.isLoading = false;
    }
}
handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;

    if (actionName === 'notify') {
        this.notifyCustomer(row);
    } 
    else if (actionName === 'view') {
        this.viewRecord(row);
    }
    else if (actionName === 'send_email') {
        this.triggerFlow(row);
    }
    else if (actionName === 'openAccount') {  
        this.viewRecord(row);
    }
}
async notifyCustomer(row) {
    try {
        await notifyCustomer({ customerId: row.Id });

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Customer notified successfully',
                variant: 'success'
            })
        );
    } catch (error) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'Failed to notify customer',
                variant: 'error'
            })
        );
    }
}
async viewRecord(row) {
    try {
        const accId = await findAccountByName({
            customerName: row.Customer_Name__c
        });

        if (accId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: accId,
                    objectApiName: 'Account',
                    actionName: 'view'
                }
            });
        } else {
            this.showToast('Error', 'No matching Account found', 'error');
        }

    } catch (error) {
        this.showToast('Error', 'Search failed', 'error');
    }
}
get highLabel() {
    return `High (${this.event?.High_Count__c || 0})`;
}

get mediumLabel() {
    return `Medium (${this.event?.Medium_Count__c || 0})`;
}

get lowLabel() {
    return `Low (${this.event?.Low_Count__c || 0})`;
}
async triggerFlow(row) {
    try {
        console.log('Row:', JSON.stringify(row));

        // 🔹 Step 1: Find Account Id from Name
        const accId = await findAccountByName({
            customerName: row.Customer_Name__c
        });

        if (!accId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'No matching Account found',
                    variant: 'error'
                })
            );
            return;
        }

        console.log('Account Id:', accId);

        // 🔹 Step 2: Call Flow
        await runEmailFlow({ recordId: accId });

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Email sent successfully',
                variant: 'success'
            })
        );

    } catch (error) {
        console.error('Flow Error:', error);

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: error?.body?.message || 'Flow execution failed',
                variant: 'error'
            })
        );
    }
}
handleFlowStatus(event) {

    if (event.detail.status === 'STARTED') {
        const flow = this.template.querySelector('lightning-flow');

        flow.startFlow('Market_Email_Notify', this.flowInputVariables);
    }

    if (event.detail.status === 'FINISHED') {
        this.showFlow = false;

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Email sent successfully',
                variant: 'success'
            })
        );
    }
}
}