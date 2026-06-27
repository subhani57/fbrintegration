# FBR API Testing with Postman

## Sandbox API Endpoints

### 1. Submit Invoice (Sandbox)
**URL:** `https://gw.fbr.gov.pk/di_data/v1/di/postinvoicedata_sb`

**Method:** `POST`

**Headers:**
```
Authorization: Bearer b27e020e-35ee-3bca-9c8c-7ccedb98bf1e
Content-Type: application/json
Accept: application/json
```

**Request Body (JSON):**
```json
{
  "invoiceType": "Sale Invoice",
  "invoiceDate": "2024-12-18",
  "sellerNTNCNIC": "0000000000000",
  "sellerBusinessName": "Your Business Name",
  "sellerProvince": "Punjab",
  "sellerAddress": "Seller Address",
  "buyerNTNCNIC": "0000000000000",
  "buyerBusinessName": "Buyer Business Name",
  "buyerProvince": "Punjab",
  "buyerAddress": "Buyer Address",
  "buyerRegistrationType": "Registered",
  "invoiceRefNo": "",
  "scenarioId": "SN000",
  "items": [
    {
      "hsCode": "0000.0000",
      "productDescription": "Test Product",
      "rate": "17%",
      "uoM": "Numbers, pieces, units",
      "quantity": 10,
      "totalValues": 1000,
      "valueSalesExcludingST": 830,
      "fixedNotifiedValueOrRetailPrice": 100,
      "salesTaxApplicable": 170,
      "salesTaxWithheldAtSource": 0,
      "extraTax": "",
      "furtherTax": 0,
      "sroScheduleNo": "",
      "fedPayable": 0,
      "discount": 0,
      "saleType": "",
      "sroItemSerialNo": ""
    }
  ]
}
```

### 2. Validate Invoice (Sandbox)
**URL:** `https://gw.fbr.gov.pk/di_data/v1/di/validateinvoicedata_sb`

**Method:** `POST`

**Headers:**
```
Authorization: Bearer b27e020e-35ee-3bca-9c8c-7ccedb98bf1e
Content-Type: application/json
Accept: application/json
```

**Request Body:** Same as Submit Invoice above

## Postman Setup Steps

### Step 1: Create a New Request
1. Open Postman
2. Click "New" → "HTTP Request"
3. Set method to `POST`

### Step 2: Enter URL
For Submit Invoice:
```
https://gw.fbr.gov.pk/di_data/v1/di/postinvoicedata_sb
```

For Validate Invoice:
```
https://gw.fbr.gov.pk/di_data/v1/di/validateinvoicedata_sb
```

### Step 3: Set Headers
Go to the "Headers" tab and add:
- Key: `Authorization`, Value: `Bearer b27e020e-35ee-3bca-9c8c-7ccedb98bf1e`
- Key: `Content-Type`, Value: `application/json`
- Key: `Accept`, Value: `application/json`

### Step 4: Set Body
1. Go to the "Body" tab
2. Select "raw"
3. Choose "JSON" from the dropdown
4. Paste the JSON payload above

### Step 5: Send Request
Click "Send" button

## Example Test Cases

### Test Case 1: Basic Sale Invoice
```json
{
  "invoiceType": "Sale Invoice",
  "invoiceDate": "2024-12-18",
  "sellerNTNCNIC": "1234567-8",
  "sellerBusinessName": "ABC Trading Company",
  "sellerProvince": "Punjab",
  "sellerAddress": "123 Main Street, Lahore",
  "buyerNTNCNIC": "8765432-1",
  "buyerBusinessName": "XYZ Corporation",
  "buyerProvince": "Sindh",
  "buyerAddress": "456 Business Avenue, Karachi",
  "buyerRegistrationType": "Registered",
  "invoiceRefNo": "INV-2024-001",
  "scenarioId": "SN001",
  "items": [
    {
      "hsCode": "8471.30.00",
      "productDescription": "Laptop Computer",
      "rate": "17%",
      "uoM": "Numbers, pieces, units",
      "quantity": 5,
      "totalValues": 500000,
      "valueSalesExcludingST": 415000,
      "fixedNotifiedValueOrRetailPrice": 100000,
      "salesTaxApplicable": 85000,
      "salesTaxWithheldAtSource": 0,
      "extraTax": "",
      "furtherTax": 0,
      "sroScheduleNo": "",
      "fedPayable": 0,
      "discount": 0,
      "saleType": "Goods at standard rate (default)",
      "sroItemSerialNo": ""
    }
  ]
}
```

### Test Case 2: Multiple Items
```json
{
  "invoiceType": "Sale Invoice",
  "invoiceDate": "2024-12-18",
  "sellerNTNCNIC": "1234567-8",
  "sellerBusinessName": "ABC Trading Company",
  "sellerProvince": "Punjab",
  "sellerAddress": "123 Main Street, Lahore",
  "buyerNTNCNIC": "8765432-1",
  "buyerBusinessName": "XYZ Corporation",
  "buyerProvince": "Sindh",
  "buyerAddress": "456 Business Avenue, Karachi",
  "buyerRegistrationType": "Registered",
  "invoiceRefNo": "INV-2024-002",
  "scenarioId": "SN001",
  "items": [
    {
      "hsCode": "8471.30.00",
      "productDescription": "Laptop Computer",
      "rate": "17%",
      "uoM": "Numbers, pieces, units",
      "quantity": 2,
      "totalValues": 200000,
      "valueSalesExcludingST": 166000,
      "fixedNotifiedValueOrRetailPrice": 100000,
      "salesTaxApplicable": 34000,
      "salesTaxWithheldAtSource": 0,
      "extraTax": "",
      "furtherTax": 0,
      "sroScheduleNo": "",
      "fedPayable": 0,
      "discount": 0,
      "saleType": "Goods at standard rate (default)",
      "sroItemSerialNo": ""
    },
    {
      "hsCode": "8517.12.00",
      "productDescription": "Mobile Phone",
      "rate": "17%",
      "uoM": "Numbers, pieces, units",
      "quantity": 10,
      "totalValues": 300000,
      "valueSalesExcludingST": 249000,
      "fixedNotifiedValueOrRetailPrice": 30000,
      "salesTaxApplicable": 51000,
      "salesTaxWithheldAtSource": 0,
      "extraTax": "",
      "furtherTax": 0,
      "sroScheduleNo": "",
      "fedPayable": 0,
      "discount": 0,
      "saleType": "Goods at standard rate (default)",
      "sroItemSerialNo": ""
    }
  ]
}
```

## Expected Response

### Success Response
```json
{
  "validationResponse": {
    "statusCode": "00",
    "invoiceNumber": "FBR-2024-123456",
    "error": null,
    "errorCode": null
  }
}
```

### Error Response
```json
{
  "validationResponse": {
    "statusCode": "01",
    "errorCode": "0052",
    "error": "Provide proper HS Code"
  }
}
```

## Common Error Codes

- **0001**: Seller not registered for sales tax
- **0002**: Invalid Buyer Registration No or NTN
- **0046**: Provide rate
- **0052**: Provide proper HS Code

## Testing Tips

1. **Start with Validate Endpoint**: Use `validateinvoicedata_sb` first to check if your invoice data is correct before submitting
2. **Check Response Status**: Look for `statusCode: "00"` for success
3. **Verify Required Fields**: Make sure all required fields are present
4. **Test Different Scenarios**: Try different `scenarioId` values (SN000, SN001, SN002, etc.)
5. **Validate Calculations**: Ensure `totalValues = valueSalesExcludingST + salesTaxApplicable`

## Postman Collection

You can create a Postman Collection with:
- Environment variables for the token
- Pre-request scripts to generate dynamic dates
- Tests to validate responses

### Environment Variables
Create a Postman Environment with:
- `fbr_token`: `b27e020e-35ee-3bca-9c8c-7ccedb98bf1e`
- `fbr_base_url`: `https://gw.fbr.gov.pk/di_data/v1/di`

Then use in headers:
```
Authorization: Bearer {{fbr_token}}
```

