import { LightningElement, api } from "lwc";
import getStockData from "@salesforce/apex/StockController.getStockData";

export default class StockViewer extends LightningElement {
    @api recordId;

    stocks = [];
    error;
    isLoading = true;
    hasLoaded = false;

    // Modal state
    showChart = false;
    selectedTicker;

    renderedCallback() {
        if (this.recordId && !this.hasLoaded) {
            this.hasLoaded = true;
            this.loadData();
        }
    }

    // Refresh handler
    handleRefresh() {
        this.isLoading = true;
        this.loadData();
    }

    loadData() {
        getStockData({ accountId: this.recordId })
            .then((result) => {
                this.stocks = result.map((item) => {
                    const isPositive = item.gainLoss >= 0;

                    return {
                        ...item,
                        currentPriceFormatted: this.formatCurrency(
                            item.currentPrice
                        ),
                        buyPriceFormatted: this.formatCurrency(item.buyPrice),
                        gainFormatted: this.formatCurrency(item.gainLoss),

                        gainClass: isPositive ? "green" : "red",
                        gainIcon: isPositive
                            ? "utility:arrowup"
                            : "utility:arrowdown",
                        gainIconVariant: isPositive ? "success" : "error"
                    };
                });

                this.error = undefined;
            })
            .catch((error) => {
                console.error("ERROR:", JSON.stringify(error));
                this.error = error;
                this.stocks = [];
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Currency formatter
    formatCurrency(value) {
        if (value === null || value === undefined) return "";

        return new Intl.NumberFormat("en-IN", {
            style: "currency",
            currency: "INR",
            minimumFractionDigits: 2
        }).format(value);
    }

    // Open chart
    handleShowChart(event) {
        this.selectedTicker = event.currentTarget.dataset.ticker;
        this.showChart = true;
    }

    // Close modal
    closeModal() {
        this.showChart = false;
        this.selectedTicker = null;
    }
}