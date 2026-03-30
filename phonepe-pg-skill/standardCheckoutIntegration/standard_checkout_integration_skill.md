# **Standard Checkout One-Time Payment Integration**

## **Skill: INITIATE_STANDARD_CHECKOUT_PAYMENT**

**Description:** Processes a single transaction by fetching a token from the core auth skill and submitting the payload.

---

### **Dependencies**

* **Auth Provider:** [SKILL_AUTH_GENERATE](../SKILL.md#1-authentication-skill-base) 
---

### **Execution Flow**

1. **Call Dependency:** Initialize by calling `SKILL_AUTH_GENERATE`
2. **Context Passing:** Pass the `access_token` returned from the parent skill into the request header
3. **Build Request Payload:** Construct the payload with REQUIRED fields (see below)
4. **Make API Call:** POST to the appropriate endpoint
5. **Handle Response:** Extract `redirectUrl` from the success response
6. **Launch Payment Page:** Pass `redirectUrl` to `LAUNCH_PAYMENT_PAGE` — the PhonePe JS SDK **must** be used; directly navigating to the URL will fail

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
{
    "paymentModeConfig": {
        "enabledPaymentModes": [
            {"type": "UPI_INTENT"},
            {"type": "UPI_COLLECT"},
            {"type": "CARD", "cardTypes": ["DEBIT_CARD"]}
        ]
    }
}
```

**Example - Disable specific payment modes:**
```json
{
    "paymentModeConfig": {
        "disabledPaymentModes": [
            {"type": "NET_BANKING"}
        ]
    }
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
- [ ] Pass the returned `redirectUrl` to `LAUNCH_PAYMENT_PAGE` — **never** navigate to it directly
- [ ] Handle error responses appropriately

---

## **Skill: LAUNCH_PAYMENT_PAGE**

**Description:** Launches the PhonePe payment page using the official PhonePe JavaScript SDK after obtaining `redirectUrl` from `INITIATE_STANDARD_CHECKOUT_PAYMENT`.

> ⚠️ **AI MUST inform merchants:** Simply opening `redirectUrl` in a browser tab (`window.location.href`, anchor tag, etc.) does **not** work. PhonePe's payment page validates the merchant's registered domain via HTTP referrer headers. The JS SDK is the only supported method to correctly set this context.

---

### **Dependencies**

* **Payment Initiator:** `INITIATE_STANDARD_CHECKOUT_PAYMENT` — provides the `redirectUrl` (used as `tokenUrl`)

---

### **Execution Flow**

1. **Receive `redirectUrl`** from `INITIATE_STANDARD_CHECKOUT_PAYMENT`
2. **Include JS SDK** — add `checkout.js` script tag to the checkout page
3. **Define callback** — handle `USER_CANCEL` and `CONCLUDED` responses
4. **Invoke `PhonePeCheckout.transact()`** with `tokenUrl`, `callback`, and `type`
5. **On `CONCLUDED`** — call `CHECK_PAYMENT_STATUS` to verify the actual payment outcome

---

### **Step 1 — Include the PhonePe Checkout Script**

Add the following script tag to your checkout page HTML. The script appends the `PhonePeCheckout` object to `window`.

| Environment | Script URL |
|-------------|-----------|
| Sandbox     | `https://mercury-stg.phonepe.com/web/bundle/checkout.js` |
| Production  | `https://mercury.phonepe.com/web/bundle/checkout.js` |

```html
<!-- Sandbox -->
<script src="https://mercury-stg.phonepe.com/web/bundle/checkout.js"></script>

<!-- Production -->
<script src="https://mercury.phonepe.com/web/bundle/checkout.js"></script>
```

**`PhonePeCheckout` exposes two methods:**

| Method | Description |
|--------|-------------|
| `PhonePeCheckout.transact(options)` | Launches the payment page (IFrame or Redirect) |
| `PhonePeCheckout.closePage()` | Manually closes the IFrame — exceptional cases only |

---

### **Step 2 — Launch the Payment Page**

Use the `redirectUrl` from `INITIATE_STANDARD_CHECKOUT_PAYMENT` as the `tokenUrl` parameter.

#### **IFrame Mode (Recommended)**

Opens the payment page embedded within your website. Provides the best user experience.

```javascript
function phonePeCallback(response) {
  if (response === 'USER_CANCEL') {
    // User dismissed the payment page without completing payment
    // Update UI to allow the user to retry
    return;
  } else if (response === 'CONCLUDED') {
    // Payment reached a terminal state (completed or failed)
    // ⚠️ Do NOT assume success — always verify via CHECK_PAYMENT_STATUS
    verifyPaymentStatus(merchantOrderId);
    return;
  }
}

window.PhonePeCheckout.transact({
  tokenUrl: redirectUrl,   // redirectUrl from INITIATE_STANDARD_CHECKOUT_PAYMENT
  callback: phonePeCallback,
  type: "IFRAME"
});
```

#### **Redirect Mode**

Navigates the user to the PhonePe payment page. After completion, the user is redirected to `merchantUrls.redirectUrl`.

```javascript
window.PhonePeCheckout.transact({ tokenUrl: redirectUrl });
```

---

### **Callback Response Reference**

| Response | Meaning | Required Action |
|----------|---------|-----------------|
| `USER_CANCEL` | User closed the payment IFrame without completing payment | Update UI; allow user to retry with the same or new order |
| `CONCLUDED` | Payment reached a terminal state | Call `CHECK_PAYMENT_STATUS` to confirm success or failure |

> ⚠️ `CONCLUDED` means the payment **flow ended** — it does not indicate success. Always call `CHECK_PAYMENT_STATUS` to get the definitive `state`.

---

### **Manually Closing the IFrame**

Only use in exceptional cases (e.g., session timeout). The IFrame closes automatically on payment conclusion.

```javascript
window.PhonePeCheckout.closePage();
```

---

### **Flutter Web Integration**

**1. Add the script to `web/index.html`:**

```html
<script src="https://mercury-stg.phonepe.com/web/bundle/checkout.js" defer></script>
```

**2. Define a JS bridge function in your HTML:**

```javascript
window.checkout = (tokenUrl, type, callback) => {
  if (window && window.PhonePeCheckout && window.PhonePeCheckout.transact) {
    window.PhonePeCheckout.transact({ tokenUrl, callback, type });
  }
};
```

**3. Invoke from Dart:**

```dart
import 'dart:js' as js;

void launchPhonePePayPage(String redirectUrl) {
  if (js.context.hasProperty('checkout')) {
    js.context.callMethod('checkout', [
      redirectUrl,
      'IFRAME',
      js.allowInterop(phonePeCallback),
    ]);
  }
}

void phonePeCallback(String response) {
  if (response == 'USER_CANCEL') {
    // Handle cancellation
  } else if (response == 'CONCLUDED') {
    // Verify via CHECK_PAYMENT_STATUS
  }
}
```

---

### **Implementation Checklist for AI**

- [ ] **Always inform the merchant** that the PhonePe JS SDK is required — direct URL navigation will fail
- [ ] Include the correct `checkout.js` script URL for the target environment (sandbox vs production)
- [ ] Use `redirectUrl` from `INITIATE_STANDARD_CHECKOUT_PAYMENT` as the `tokenUrl`
- [ ] Prefer **IFrame mode** (`type: "IFRAME"`) for embedded payment experience
- [ ] Implement the `callback` function to handle both `USER_CANCEL` and `CONCLUDED`
- [ ] On `CONCLUDED`, always call `CHECK_PAYMENT_STATUS` — never assume the outcome from the callback alone
- [ ] For Flutter web, use the JS interop bridge pattern with `js.allowInterop`

---

## **Skill: CHECK_PAYMENT_STATUS**

**Description:** Check the current status of a specific order by providing its merchant order ID. Returns information about the order state (COMPLETED, PENDING, FAILED) and payment details.

---

### **Dependencies**

* **Auth Provider:** [SKILL_AUTH_GENERATE](../SKILL.md#1-authentication-skill-base)

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
2. Call `LAUNCH_PAYMENT_PAGE` with the `redirectUrl` using the PhonePe JS SDK
3. User completes payment on the PhonePe payment page
4. Callback fires with `CONCLUDED` (or user cancels with `USER_CANCEL`)
5. Call `CHECK_PAYMENT_STATUS` with `merchantOrderId` to verify the definitive payment state
6. Based on `state`:
   - **COMPLETED** → Fulfill order
   - **PENDING** → Poll status until COMPLETED/FAILED or timeout
   - **FAILED** → Show error, allow retry

**Status Polling Best Practice:**
- Poll every 5-10 seconds for PENDING orders
- Stop polling after order `expireAt` timestamp
- Maximum 10-15 poll attempts to avoid excessive API calls

---

## **Retry Strategy**

### **`merchantOrderId` Uniqueness Rules**

`merchantOrderId` must be **unique per transaction**. PhonePe rejects any reuse with `INVALID_MERCHANT_ORDER_ID` (HTTP 417).

| Rule | Detail |
|------|--------|
| Always use a unique ID | Each new payment attempt requires a new `merchantOrderId` — reuse always fails |
| Never reuse on failure | If a payment fails or expires, generate a **new** unique `merchantOrderId` for the retry |
| Never reuse across customers | Each customer transaction must have a globally unique order ID |
| ID constraints | Max 63 chars; alphanumeric, `_`, and `-` only |

### **Retry Strategy for API Errors**

| Error | Retry? | Strategy |
|-------|--------|----------|
| 401 AUTHORIZATION_FAILED | Yes | Refresh token via `SKILL_AUTH_GENERATE`, retry once |
| 500 INTERNAL_SERVER_ERROR | Yes | Exponential backoff: wait 2s, 4s, 8s (max 3 retries) |
| 400 BAD_REQUEST | No | Fix request payload; do not retry as-is |
| 417 INVALID_TRANSACTION_ID | No | Generate a new unique `merchantOrderId` and retry |
| Network timeout | Yes | Check order status via `CHECK_PAYMENT_STATUS` before retrying to avoid duplicate orders |

---

## **Webhook / Server Callback Verification**

Server-side webhook callbacks provide a more reliable payment verification method than polling or relying on client-side redirects.

### **How Callbacks Work**

1. PhonePe POSTs a callback to your server URL after a payment state change
2. The callback payload contains the `merchantOrderId` and updated order `state`

### **Callback Payload Example**

```json
{
    "event": "checkout.order.completed",
    "payload": {
        "orderId": "OMO2403282020198641071317",
        "merchantId": "merchantId",
        "merchantOrderId": "merchantOrderId",
        "state": "COMPLETED",
        "amount": 10000,
        "expireAt": 1724866793837,
        "paymentDetails": [
            {
                "paymentMode": "UPI_QR",
                "transactionId": "OM12334",
                "timestamp": 1724866793837,
                "amount": 10000,
                "state": "COMPLETED"
            }
        ],
        "metaInfo": {
            "udf1": "",
            "udf2": "",
            "udf3": "",
            "udf4": "",
            "udf5": "",
            "udf6": "",
            "udf7": "",
            "udf8": "",
            "udf9": "",
            "udf10": "",
            "udf11": "",
            "udf12": "",
            "udf13": "",
            "udf14": "",
            "udf15": ""
        }
    }
}
```

### **Recommended Callback Handler Flow**

1. Receive POST callback from PhonePe
2. Extract `merchantOrderId` from payload
3. If `state == "COMPLETED"` → fulfill the order
4. Respond with HTTP 200 to acknowledge receipt

---

## **Edge Cases & Common Integration Errors**

| Scenario | Cause | Prevention / Fix |
|----------|-------|-----------------|
| Duplicate `merchantOrderId` | Same ID reused for a new transaction | Always generate a unique ID per transaction; PhonePe fails the request with `INVALID_MERCHANT_ORDER_ID` (HTTP 417) |
| Amount below minimum | `amount < 100` paisa | Enforce minimum ₹1 (100 paisa) on the client side before calling the API |
| Token expired mid-flow | Token used after `expires_at` | Check `current_time >= expires_at - 60`; proactively refresh token |
| Order expired before payment | User took too long; `expireAt` passed | Create a new order; expired orders cannot be paid |
| Order ID reuse after failure | Using same ID for a retry after FAILED | Generate a new `merchantOrderId`; failed orders are final |
| Environment mismatch | Sandbox credentials used against production URL | Use environment-aware config; validate `PHONEPE_ENV` at startup |
| Missing redirectUrl | `paymentFlow.merchantUrls.redirectUrl` omitted | This field is required; always provide a valid HTTPS callback URL |
| Card payments not appearing | `CARD` type not in `enabledPaymentModes` | Explicitly add `{"type": "CARD", "cardTypes": [...]}` to enable card payments |
