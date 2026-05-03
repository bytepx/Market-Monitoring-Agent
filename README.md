# Market Monitoring Agent

[Project Documentation](https://docs.google.com/document/d/18jG_v32s0ASjB1y3ZA1zyHEFuMYUE-yv0Sv0VWEFp7c/edit?usp=sharing)
## 🗂️ File Descriptions
 
### Salesforce FSC Objects
 
**`SF_Contact_450.xlsx`** contains 450 Indian customer contacts with standard fields including mobile, email, DOB along with a custom field `LifeEventStatus__c` to capture life events like Marriage, Retirement, Job Change etc.
 
**`SF_Account_450.xlsx`** contains 450 Person Account records with custom fields `PAN__c` and `PersonBirthdate` along with full billing and shipping address mapped to Indian cities and pincodes.
 
**`SF_FinancialAccount_450.xlsx`** contains 450 FSC Financial Account records covering all standard picklist types — Savings, Checking, Mortgage, Credit Card, Automotive Loan, Automotive Lease, Loan, Investment Account and Home Equity Line of Credit — with context-aware field population per type.
 
### Core Banking System (CBS)
 
**`CBS_CustomerData_dlm.xlsx`** is the CIF master record for all 450 customers. It contains PAN, mobile, email, address, customer segment, KYC status, residential status and occupation. This is the anchor object for CBS linking and maps to `CBSCustomerData_dlm` in Data Cloud.
  
 
### Demat & Trading Platform
 
**`Demat_DematAccount_dlm.xlsx`** contains 450 demat account records with DP ID, Client ID, depository (NSDL/CDSL), pledge value, margin available and Power of Attorney flag. Maps to `DematAccount_dlm` in Data Cloud.
 
**`Demat_Holding_dlm.xlsx`** contains approximately 2,272 NSE equity holding records. Each holding includes instrument name, ticker symbol (valid NSE tickers for use with indianapi.in), ISIN, quantity, buy price, current price, market value, unrealised P&L, XIRR and sector. Primary key is PAN + ISIN composite. Maps to `Holding_dlm` in Data Cloud.
 
 
### KYC & Risk Assessment
 
**`KYC_KYCProfile_dlm.xlsx`** contains 450 KYC profile records with PAN, masked Aadhaar, CKYC number, KYC mode and status, FATCA flag, PEP flag, AML risk category, RBI investor category, annual income band and net worth band. Maps to `KYCProfile_dlm` in Data Cloud.
 
 
### Market Data
 
**`StockOHLCV_6M_dlm.xlsx`** contains 6,783 rows of daily OHLCV data for 51 NSE-listed stocks across 133 trading days (November 2025 to May 1, 2026). Each row includes Open, High, Low, Close, Volume, PrevClose, Change, ChangePct, VWAP, MarketCap, PE Ratio, 52W High/Low, NiftyIndex and Exchange. The data uses Geometric Brownian Motion with sector regime shifts and macro shock events for realistic price movement. Maps to `StockPastData__dlm` in Data Cloud.
 
  
---
 
## 🔑 Primary Keys
 
Each Data Cloud stream uses the following primary keys:
 
- **CBSCustomerData_dlm** → `CIF_Number`
- **BankAccount_dlm** → `PAN_Number`
- **DematAccount_dlm** → `PAN_Number`
- **Holding_dlm** → `PAN_Number + ISIN` (composite key)
- **KYCProfile_dlm** → `PAN`
- **StockPastData__dlm** → `Date + Ticker` (composite key)
---
 
## 🔗 Identity Resolution (IR)
 
Identity resolution in Data Cloud is configured using a combination of exact and fuzzy matching rules to unify customer profiles across all systems.
 
### Exact Match Rules
 
- **PAN Number** links `Account.PAN__c` in FSC, `CIF.PAN_Number` in CBS, `KYCProfile.PAN` in KYC and `Demat.PAN_Number` in the trading platform — this is the strongest and primary match key
- **Mobile Number** links `Contact.MobilePhone` in FSC, `Customer.MobileNo` in CBS and `KYCProfile.Mobile` in KYC
- **Email Address** links `Contact.Email` in FSC, `Customer.EmailId` in CBS and `KYCProfile.Email` in KYC
### Fuzzy Match Rules
 
- **Name + DOB + Pincode** is used as a fuzzy match combining `Account.Name` + `PersonBirthdate` + `BillingPostalCode` in FSC with `Customer.FullName` + `DOB` + `Pincode` in CBS and `KYCProfile.Name` + `DOB` + `Pincode` in KYC — this handles cases where PAN or contact details differ across systems
---
 
## 🏗️ Data Flow Architecture
 
```
┌─────────────────────────────────────────────────────────────────────┐
│                        DATA SOURCES                                 │
│                                                                     │
│  GitHub Repo (this)          indianapi.in/stock                    │
│  ├── CBS files                └── Live NSE stock prices            │
│  ├── Demat files                                                    │
│  ├── KYC files                                                      │
│  └── Market data                                                    │
└────────────────────┬────────────────────────────────────────────────┘
                     │ Upload
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        AWS S3 BUCKET                                │
│   s3://your-bucket/fsc-demo/                                       │
│   ├── cbs/         (CBSCustomerData, BankAccount)    │
│   ├── demat/       (DematAccount, Holding)                  │
│   ├── kyc/         (KYCProfile)                       │
│   └── market/      (StockOHLCV_6M)                                 │
└────────────────────┬────────────────────────────────────────────────┘
                     │ S3 Connector / Batch Ingestion
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   SALESFORCE DATA CLOUD                             │
│                                                                     │
│  Data Streams (DLM)              Data Model Objects (DMO)          │
│  ├── CBSCustomerData_dlm    ───► CBSCustomer DMO                   │
│  ├── BankAccount_dlm        ───► BankAccount DMO                   │
│  ├── DematAccount_dlm       ───► DematAccount DMO                  │
│  ├── Holding_dlm            ───► Holding DMO                       │
│  ├── KYCProfile_dlm         ───► KYCProfile DMO                    │
│  └── StockPastData__dlm     ───► StockPrice DMO                    │
│                                                                     │
│  Relationships (Many → One)                                         │
│  ├── CBSCustomerData → SF Account      (SalesforceAccountId)       │
│  ├── Holding → SF Account              (PAN_Number)                │
│  ├── StockPastData → Holding           (Ticker = Ticker_Symbol)    │
│  ├── KYCProfile → SF Account           (SalesforceAccountId)       │
└────────────────────┬────────────────────────────────────────────────┘
                     │
          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼
┌──────────────────┐   ┌─────────────────────────────────────────┐
│  SALESFORCE FSC  │   │           TABLEAU DASHBOARD             │
│                  │   │                                         │
│  Contacts        │   │  Connected via: Salesforce Data Cloud   │
│  Accounts        │   │  Connection type: Live                  │
│  FinancialAccts  │   │                                         │
│  Tasks           │   │  Sheets:                                │
│  Events          │   │  ├── Candlestick Chart (OHLCV)          │
│                  │   │  ├── Volume Bar Chart                   │
│  Home Page       │   │  ├── Market Overview (all sectors)      │
│  ├── Tableau Viz │   │  ├── % Change Heatmap                   │
│  ├── My Tasks    │   │  ├── KPI Cards (52W H/L, VWAP, PE)      │
│  └── My Events   │   │  └── Customer Portfolio View           │
└──────────────────┘   │                                         │
                       │  Parameter: Selected Stock dropdown     │
                       │  Filter: Ticker → all sheets            │
                       └─────────────────────────────────────────┘
```
 
---
 
## 📥 How to Import Data into Salesforce
 
### Step 1 — Salesforce FSC Objects
 
Import in this exact order to maintain relationship integrity. Start with Accounts since Contacts reference `AccountId`, then import Contacts, and finally Financial Accounts via Data Loader since it is an FSC custom object.
 
- `SF_Account_450` → Setup → Data Import Wizard → Accounts
- `SF_Contact_450` → Setup → Data Import Wizard → Contacts
- `SF_FinancialAccount_450` → Data Loader → Insert → `FinServ__FinancialAccount__c`
### Step 2 — Upload to S3
 
Convert each `.xlsx` to `.csv` and upload to your S3 bucket following this structure:
 
```bash
s3://your-bucket/fsc-demo/cbs/CBSCustomerData_dlm.csv
s3://your-bucket/fsc-demo/cbs/BankAccount_dlm.csv
s3://your-bucket/fsc-demo/demat/DematAccount_dlm.csv
s3://your-bucket/fsc-demo/demat/Holding_dlm.csv
s3://your-bucket/fsc-demo/kyc/KYCProfile_dlm.csv
s3://your-bucket/fsc-demo/market/StockOHLCV_6M_dlm.csv
```
 
### Step 3 — Create Data Streams in Data Cloud
 
For each CSV in S3 go to Data Cloud → Data Streams → New → Amazon S3, point to the file path, map the fields and set the primary key as listed in the Primary Keys section above, then activate the stream.
 
### Step 4 — Build Relationships in Data Model
 
Navigate to Data Cloud → Data Model → Relationships and create all 11 relationships in this order. All relationships are Many → One:
 
1. `CBSCustomerData_dlm` → `SF Account` on `PAN_Number = PAN__c`
2. `BankAccount_dlm` → `SF FinancialAccount` on `SalesforceFA_Id = FinancialAccount.Id`
3. `DematAccount_dlm` → `SF Account` on `PAN_Number = PAN__c`
4. `Holding_dlm` → `DematAccount_dlm` on `PAN_Number = PAN_Number`
5. `StockPastData__dlm` → `Holding_dlm` on `Ticker = Ticker_Symbol`
6. `KYCProfile_dlm` → `SF Account` on `PAN_Number = PAN__c`

 
---
 
## 📊 Tableau Setup
 
### Connect to Data Cloud
 
Open Tableau Desktop, go to Connect → Salesforce Data Cloud and sign in. Set `StockPastData__dlm` as the primary table, join `Holding_dlm` on `Ticker = Ticker_Symbol` and set the connection type to **Live** for real-time refresh.
 
### Calculated Fields
 
Create the following calculated fields in Tableau via Analysis → Create Calculated Field:
 
- **Day Change** → `[Close__c] - [PrevClose__c]`
- **Day Change %** → `([Close__c] - [PrevClose__c]) / [PrevClose__c] * 100`
- **VWAP** → `([High__c] + [Low__c] + [Close__c]) / 3`
- **Candle Color** → `IF [Close__c] >= [Open__c] THEN "Bullish" ELSE "Bearish" END`
- **Candle Size** → `ABS([Close__c] - [Open__c])`
- **Market Value** → `[Close__c] * [Quantity__c]`
- **P&L %** → `([Close__c] - [BuyPrice__c]) / [BuyPrice__c] * 100`
### Embed in Salesforce Home Page
 
Publish the workbook to Tableau Cloud via Server → Publish Workbook. Then in Salesforce go to Setup → Visualforce Pages → New and paste an iframe pointing to the Tableau Cloud URL. Finally open Lightning App Builder on the Home Page, drag the Visualforce component onto the page, select the page and activate it as Org Default.
 
---
 

## 🛠️ Tech Stack
 
The project uses Salesforce Financial Services Cloud as the CRM layer and Salesforce Data Cloud as the unified data platform. Raw files are stored in AWS S3 and ingested into Data Cloud via the S3 connector. Tableau Desktop and Tableau Cloud handle visualization with the dashboard embedded directly on the Salesforce Home Page. Live NSE stock price data is fetched via the indianapi.in `/stock` endpoint using valid NSE ticker symbols. Identity resolution uses PAN, Mobile and Email for exact matching and Name + DOB + Pincode for fuzzy matching across all systems.
 
---
 
> ⚠️ All data is synthetic — generated for demo purposes only. PAN numbers, Aadhaar, phone numbers and account numbers are randomly generated.
