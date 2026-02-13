# **Standard Checkout One-Time Payment Integration**

## **Skill: INITIATE_STANDARD_CHECKOUT_PAYMENT**

**Description:** Processes a single transaction by fetching a token from the core auth skill and submitting the payload.

---

### **Dependencies**

* **Auth Provider:** [SKILL_AUTH_GENERATE](../SKILL.md#1-authentication-skill-base) 
* **Refund Provider:** [SKILL_PAYMENT_REFUND](../SKILL.md#2-refund-skill)

---

### **Execution Flow**

1. **Call Dependency:** Initialize by calling `SKILL_AUTH_GENERATE`
2. **Context Passing:** Pass the `access_token` returned from the parent skill into the request header
3. **Build Request Payload:** Construct the payload with REQUIRED fields (see below)
4. **Make API Call:** POST to the appropriate endpoint
5. **Handle Response:** Return `redirectUrl` on success or error details on failure

---

### **API Configuration**

#### **Endpoints**
* **Sandbox:** `POST https://api-preprod.phonepe.com/apis/pg-sandbox/checkout/v2/pay`
* **Production:** `POST https://api.phonepe.com/apis/pg/checkout/v2/pay`

#### **Request Headers**
```
Authorization: O-Bearer {{SKILL_AUTH_GENERATE.output.access_token}}
Content-Type: application/json
```

---

### **Request Payload**

#### **🚨 AI IMPLEMENTATION REQUIREMENTS 🚨**

**AI MUST include these REQUIRED fields:**
- `merchantOrderId` (String) - Unique order identifier
- `amount` (Long) - Amount in paisa (minimum 100)
- `paymentFlow` (Object) - Payment flow configuration
- `paymentFlow.type` (String) - Must be "PG_CHECKOUT"
- `paymentFlow.merchantUrls` (Object) - URL configuration
- `paymentFlow.merchantUrls.redirectUrl` (String) - Valid callback URL

**⚠️ DO NOT include fields not documented here** (e.g., currency, customer, etc.)

---

#### **Minimum Required Payload Example**

```json
{
    "merchantOrderId": "TX123456",
    "amount": 1000,
    "paymentFlow": {
        "type": "PG_CHECKOUT",
        "merchantUrls": {
            "redirectUrl": "https://yoursite.com/payment/callback"
        }
    }
}
```

---

#### **Complete Payload with Optional Fields**

```json
{
    "merchantOrderId": "TX123456",
    "amount": 1000,
    "expireAfter": 600,
    "metaInfo": {
        "udf1": "additional-information-1",
        "udf2": "additional-information-2"
    },
    "paymentFlow": {
        "type": "PG_CHECKOUT",
        "message": "Payment for order TX123456",
        "merchantUrls": {
            "redirectUrl": "https://yoursite.com/payment/callback"
        },
        "paymentModeConfig": {
            "enabledPaymentModes": [
                {
                    "type": "UPI_INTENT"
                },
                {
                    "type": "UPI_COLLECT"
                },
                {
                    "type": "UPI_QR"
                },
                {
                    "type": "NET_BANKING"
                },
                {
                    "type": "CARD",
                    "cardTypes": [
                        "DEBIT_CARD",
                        "CREDIT_CARD"
                    ]
                }
            ]
        }
    }
}
```

---

#### **Field Specifications**

| Field Path                                           | Type   | Required | Description                                    | Validation Rules                                                        |
|------------------------------------------------------|--------|----------|------------------------------------------------|-------------------------------------------------------------------------|
| `merchantOrderId`                                    | String | **YES** | Unique merchant order ID                       | Max 63 chars. Only alphanumeric, underscore `_`, and hyphen `-` allowed |
| `amount`                                             | Long   | **YES** | Transaction amount in paisa (₹10 = 1000 paisa) | Minimum: 100                                                            |
| `paymentFlow`                                        | Object | **YES** | Payment flow configuration object              | -                                                                       |
| `paymentFlow.type`                                   | String | **YES** | Payment flow type                              | Must be `"PG_CHECKOUT"`                                                 |
| `paymentFlow.merchantUrls`                           | Object | **YES** | Merchant callback URLs                         | -                                                                       |
| `paymentFlow.merchantUrls.redirectUrl`               | String | **YES** | Redirect URL after payment completion          | Must be valid URL                                                       |
| `expireAfter`                                        | Long   | NO | Order expiry time in seconds                   | Min: 300, Max: 3600. Default: 600                                       |
| `metaInfo`                                           | Object | NO | Additional metadata for tracking               | Returned in status/callback                                             |
| `metaInfo.udf1-udf10`                                | String | NO | User-defined fields 1-10                       | Max 256 chars each                                                      |
| `metaInfo.udf11-udf15`                               | String | NO | User-defined fields 11-15                      | Max 50 chars. Only alphanumeric + `_-+@.`                               |
| `paymentFlow.message`                                | String | NO | Payment description message                    | -                                                                       |
| `paymentFlow.paymentModeConfig`                      | Object | NO      | Configure available payment methods            | Controls which payment options are shown                                |
| `paymentFlow.paymentModeConfig.enabledPaymentModes`  | Array  | NO      | List of payment modes to enable                | Array of payment mode objects (see below)                               |
| `paymentFlow.paymentModeConfig.disabledPaymentModes` | Array  | NO      | List of payment modes to disable               | Array of payment mode objects (see below)                               |

---

#### **Payment Mode Configuration**

Each object in `enabledPaymentModes` or `disabledPaymentModes` supports the following structure:

| Payment Mode Type | Additional Fields | Description | Example |
|-------------------|-------------------|-------------|---------|
| `UPI_INTENT` | None | UPI apps installed on device | `{"type": "UPI_INTENT"}` |
| `UPI_COLLECT` | None | UPI collect request (VPA) | `{"type": "UPI_COLLECT"}` |
| `UPI_QR` | None | UPI QR code scan | `{"type": "UPI_QR"}` |
| `NET_BANKING` | None | Net banking via banks | `{"type": "NET_BANKING"}` |
| `CARD` | `cardTypes` (Array) | Card payments (debit/credit) | `{"type": "CARD", "cardTypes": ["DEBIT_CARD", "CREDIT_CARD"]}` |

**Card Types (when type = "CARD"):**
- `DEBIT_CARD` - Enable debit card payments
- `CREDIT_CARD` - Enable credit card payments
- Both can be included in the `cardTypes` array

**Example - Enable only UPI and Debit Cards:**
```json
"paymentModeConfig": {
    "enabledPaymentModes": [
        {"type": "UPI_INTENT"},
        {"type": "UPI_COLLECT"},
        {"type": "CARD", "cardTypes": ["DEBIT_CARD"]}
    ]
}
```

**Example - Disable specific payment modes:**
```json
"paymentModeConfig": {
    "disabledPaymentModes": [
        {"type": "NET_BANKING"}
    ]
}
```

---

### **Response Handling**

#### **✅ Success Response (HTTP 200)**

The API returns a payment URL that must be presented to the user.

**Sample Success Response:**
```json
{
    "orderId": "OMO123456789",
    "state": "PENDING",
    "expireAt": 1703756259307,    
    "redirectUrl": "https://mercury-uat.phonepe.com/transact/uat_v2?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**AI Implementation:**
- Extract `redirectUrl` from response
- Return/display this URL to the user
- User must navigate to this URL to complete payment

---

#### **❌ Error Responses**

| HTTP Code | Error Code | Description | AI Action Required |
|-----------|------------|-------------|-------------------|
| 400 | BAD_REQUEST | Invalid request payload | Validate payload structure and required fields |
| 401 | AUTHORIZATION_FAILED | Token expired or invalid | Call `SKILL_AUTH_GENERATE` to refresh token and retry |
| 417 | INVALID_TRANSACTION_ID | Order ID is invalid or already used | Generate new unique `merchantOrderId` |
| 500 | INTERNAL_SERVER_ERROR | PhonePe server error | Retry after delay or show error to user |

**Sample Error Response:**
```json
{
    "code": "INVALID_TRANSACTION_ID",
    "message": "Order ID has already been used",
    "success": false
}
```

---

### **Implementation Checklist for AI**

- [ ] Call `SKILL_AUTH_GENERATE` first to get `access_token`
- [ ] Include ALL required fields: `merchantOrderId`, `amount`, `paymentFlow` object with nested structure
- [ ] Set `paymentFlow.type` = `"PG_CHECKOUT"`
- [ ] Provide valid `redirectUrl` for callback
- [ ] Use correct endpoint based on environment (sandbox/production)
- [ ] Handle 401 errors by refreshing token
- [ ] Return `redirectUrl` to user on success
- [ ] Handle error responses appropriately

---

## **Skill: CHECK_PAYMENT_STATUS**

**Description:** Check the current status of a specific order by providing its merchant order ID. Returns information about the order state (COMPLETED, PENDING, FAILED) and payment details.

---

### **Dependencies**

* **Auth Provider:** [SKILL_AUTH_GENERATE](../SKILL.md#skill-auth-generate)

---

### **Execution Flow**

1. **Call Dependency:** Initialize by calling `SKILL_AUTH_GENERATE`
2. **Context Passing:** Pass the `access_token` returned from the parent skill into the request header
3. **Build Request:** Use the `merchantOrderId` from the payment initiation
4. **Make API Call:** GET to the appropriate endpoint
5. **Handle Response:** Return order state and payment details

---

### **API Configuration**

#### **Endpoints**
* **Sandbox:** `GET https://api-preprod.phonepe.com/apis/pg-sandbox/checkout/v2/order/{merchantOrderId}/status`
* **Production:** `GET https://api.phonepe.com/apis/pg/checkout/v2/order/{merchantOrderId}/status`

#### **Request Headers**
```
Authorization: O-Bearer {{SKILL_AUTH_GENERATE.output.access_token}}
Content-Type: application/json
```

---

### **Request Parameters**

#### **Path Parameters**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `merchantOrderId` | String | **YES** | Order ID created in payment request (TX123456) |

#### **Query Parameters**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `details` | Boolean | NO | false | `true` → return all attempt details<br>`false` → return only latest attempt |
| `errorContext` | Boolean | NO | false | `true` → include errorContext block for failed transactions<br>`false` → exclude error context |

---

#### **Example Requests**

**Basic status check (latest attempt only):**
```bash
GET https://api-preprod.phonepe.com/apis/pg-sandbox/checkout/v2/order/TX123456/status?details=false
```

**Get all payment attempts:**
```bash
GET https://api-preprod.phonepe.com/apis/pg-sandbox/checkout/v2/order/TX123456/status?details=true
```

**Include error context for failed payments:**
```bash
GET https://api-preprod.phonepe.com/apis/pg-sandbox/checkout/v2/order/TX123456/status?details=false&errorContext=true
```

---

### **Response Handling**

#### **✅ Success Response - COMPLETED**

```json
{
    "orderId": "OMO2403282020198641071317",
    "state": "COMPLETED",
    "amount": 1000,
    "payableAmount": 1000,
    "feeAmount": 0,
    "expireAt": 1711867462542,
    "metaInfo": {
        "udf1": "additional-information-1",
        "udf2": "additional-information-2"
    },
    "paymentDetails": [
        {
            "transactionId": "OM2403282020198651071949",
            "paymentMode": "UPI_QR",
            "timestamp": 1711694662542,
            "amount": 1000,
            "payableAmount": 1000,
            "feeAmount": 0,
            "state": "COMPLETED",
            "rail": {
                "type": "UPI",
                "utr": "455069731511",
                "upiTransactionId": "YBL369f6d962de74c2680789bff8c11aec9",
                "vpa": "12****78@ybl"
            },
            "instrument": {
                "type": "ACCOUNT",
                "maskedAccountNumber": "******1234",
                "accountType": "SAVINGS",
                "accountHolderName": "John Doe"
            }
        }
    ]
}
```

---

#### **⏳ Success Response - PENDING**

```json
{
    "orderId": "OMO2407111821482103732111",
    "state": "PENDING",
    "amount": 100,
    "expireAt": 1720702908208,
    "metaInfo": {
        "udf1": "additional-information-1"
    },
    "paymentDetails": []
}
```

---

#### **❌ Success Response - FAILED**

```json
{
    "orderId": "OMO2407121214395503786511",
    "state": "FAILED",
    "amount": 200,
    "expireAt": 1720767279548,
    "errorCode": "INVALID_MPIN",
    "detailedErrorCode": "ZM",
    "metaInfo": {
        "udf1": "additional-information-1"
    },
    "paymentDetails": [
        {
            "transactionId": "OM2407121214579231302711",
            "paymentMode": "UPI_COLLECT",
            "timestamp": 1720766697944,
            "amount": 200,
            "payableAmount": 200,
            "feeAmount": 0,
            "state": "FAILED",
            "errorCode": "INVALID_MPIN",
            "detailedErrorCode": "ZM"
        }
    ],
    "errorContext": {
        "errorCode": "INVALID_MPIN",
        "detailedErrorCode": "ZM",
        "source": "CUSTOMER",
        "stage": "AUTHENTICATION",
        "description": "Wrong MPIN was entered"
    }
}
```

---

#### **Response Field Specifications**

| Field Path | Type | Description | Possible Values |
|------------|------|-------------|-----------------|
| `orderId` | String | PhonePe generated internal order ID | - |
| `state` | String | Current state of the order | `PENDING`, `COMPLETED`, `FAILED` |
| `amount` | Long | Order amount in paisa | - |
| `payableAmount` | Long | Actual amount payable (after discounts/offers) | - |
| `feeAmount` | Long | Transaction fee amount in paisa | - |
| `expireAt` | Long | Order expiry timestamp (epoch milliseconds) | - |
| `metaInfo` | Object | Merchant metadata from order creation | - |
| `metaInfo.udf1-udf15` | String | User-defined fields passed during payment | - |
| `errorCode` | String | Error code (present when state=FAILED) | See error codes below |
| `detailedErrorCode` | String | Detailed error code | - |
| `paymentDetails` | Array | List of payment attempts | Empty if no attempts |
| `paymentDetails[*].transactionId` | String | PhonePe transaction ID | - |
| `paymentDetails[*].paymentMode` | String | Payment method used | `UPI_INTENT`, `UPI_COLLECT`, `UPI_QR`, `CARD`, `NET_BANKING` |
| `paymentDetails[*].timestamp` | Long | Payment attempt timestamp (epoch) | - |
| `paymentDetails[*].amount` | Long | Amount for this attempt in paisa | - |
| `paymentDetails[*].state` | String | State of this payment attempt | `PENDING`, `COMPLETED`, `FAILED` |
| `paymentDetails[*].errorCode` | String | Error code for failed attempt | - |
| `paymentDetails[*].rail` | Object | Processing rail details | - |
| `paymentDetails[*].rail.type` | String | Rail type | `UPI`, `PG` |
| `paymentDetails[*].rail.utr` | String | UTR for UPI payments | - |
| `paymentDetails[*].rail.vpa` | String | Masked VPA (UPI ID) | - |
| `paymentDetails[*].instrument` | Object | Payment instrument details | - |
| `paymentDetails[*].instrument.type` | String | Instrument type | `ACCOUNT`, `CREDIT_CARD`, `DEBIT_CARD`, `NET_BANKING`, `WALLET` |
| `paymentDetails[*].instrument.maskedAccountNumber` | String | Masked account number | - |
| `paymentDetails[*].instrument.maskedCardNumber` | String | Masked card number (for cards) | - |
| `paymentDetails[*].instrument.cardNetwork` | String | Card network (for cards) | `VISA`, `MASTERCARD`, etc. |
| `paymentDetails[*].splitInstruments` | Array | Split payment details (if applicable) | - |
| `errorContext` | Object | Detailed error information (if errorContext=true) | Only for FAILED state |
| `errorContext.source` | String | Error source | `CUSTOMER`, `MERCHANT`, `BANK`, `GATEWAY` |
| `errorContext.stage` | String | Transaction stage where error occurred | `AUTHENTICATION`, `AUTHORIZATION`, etc. |
| `errorContext.description` | String | Human-readable error description | - |

---

#### **❌ Error Responses**

| HTTP Code | Error Code | Description | AI Action Required |
|-----------|------------|-------------|-------------------|
| 400 | INVALID_MERCHANT_ORDER_ID | Order ID not found or invalid | Verify the merchantOrderId is correct |
| 401 | AUTHORIZATION_FAILED | Token expired or invalid | Call `SKILL_AUTH_GENERATE` to refresh token and retry |
| 500 | INTERNAL_SERVER_ERROR | PhonePe server error | Retry after delay or show error to user |

**Sample Error Response:**
```json
{
    "code": "INVALID_MERCHANT_ORDER_ID",
    "message": "No entry found for given merchant order id"
}
```

---

### **Order State Interpretation**

| State | Meaning | Action Required |
|-------|---------|-----------------|
| `COMPLETED` | Payment successful | Confirm order, deliver goods/services |
| `PENDING` | Payment in progress or not yet attempted | Wait or prompt user to complete payment |
| `FAILED` | Payment failed | Check errorCode/errorContext, allow retry with new order |

---

### **Common Error Codes**

| Error Code | Description | User Action |
|------------|-------------|-------------|
| `INVALID_MPIN` | Wrong UPI PIN entered | Ask user to retry with correct PIN |
| `INSUFFICIENT_FUNDS` | Insufficient balance | Ask user to try different payment method |
| `TRANSACTION_TIMEOUT` | Payment timed out | Create new order and retry |
| `AUTHENTICATION_FAILED` | Authentication failed | Retry payment |
| `BANK_ERROR` | Bank/PSP error | Try again or use different method |

---

### **Implementation Checklist for AI**

- [ ] Call `SKILL_AUTH_GENERATE` first to get `access_token`
- [ ] Use the exact `merchantOrderId` from payment initiation
- [ ] Include `details=true` if multiple payment attempts need to be tracked
- [ ] Include `errorContext=true` for detailed failure information
- [ ] Use correct endpoint based on environment (sandbox/production)
- [ ] Handle 401 errors by refreshing token
- [ ] Interpret `state` field to determine next action
- [ ] Parse `paymentDetails` array to get transaction details
- [ ] Display appropriate message based on order state
- [ ] For FAILED state, show `errorContext.description` to user

---

### **Integration with Payment Initiation**

**Typical Flow:**

1. Call `INITIATE_STANDARD_CHECKOUT_PAYMENT` → Get `redirectUrl`
2. User completes payment on PhonePe page
3. User redirected back to merchant's `redirectUrl`
4. Call `CHECK_PAYMENT_STATUS` with `merchantOrderId` to verify payment
5. Based on `state`:
   - **COMPLETED** → Fulfill order
   - **PENDING** → Poll status until COMPLETED/FAILED or timeout
   - **FAILED** → Show error, allow retry

**Status Polling Best Practice:**
- Poll every 5-10 seconds for PENDING orders
- Stop polling after order `expireAt` timestamp
- Maximum 10-15 poll attempts to avoid excessive API calls
