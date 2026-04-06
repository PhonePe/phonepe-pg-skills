# **Payment Links Integration**

> 🔴 **MERCHANT ENABLEMENT REQUIRED — AI MUST CONFIRM BEFORE PROCEEDING**
>
> **Payment Links is not enabled by default for all merchants.** It is an individually enabled permission granted by the PhonePe team — separate from Standard Checkout, which is available by default.
>
> **Before starting any Payment Links integration, the AI must ask the merchant:**
> > *"Has your PhonePe account been enabled for Payment Links? This is a separate permission from Standard Checkout and must be explicitly granted by the PhonePe team. If you're unsure, please confirm with your PhonePe account manager or onboarding contact before proceeding."*
>
> Do **not** proceed with integration steps until the merchant confirms that the **Payment Links** permission has been enabled for their account.

Payment Links let merchants generate a shareable URL that takes customers to a PhonePe-hosted checkout page where they can pay via UPI, Cards, or NetBanking. This is ideal for use cases like invoicing, WhatsApp/SMS-based collections, and any scenario where the merchant cannot embed a checkout UI directly.

> ℹ️ **When to use Payment Links vs Custom/Standard Checkout:**
> - Use **Payment Links** when you want to collect payments without building a checkout UI — just generate a link and share it with the customer.
> - Use **Standard or Custom Checkout** when you need an embedded payment experience within your website or app.

---

## **Dependencies**

All Payment Links APIs require an OAuth access token.

* **Auth Provider:** [SKILL_AUTH_GENERATE](../SKILL.md#1-authentication-skill-base)

> ⚠️ **Partner Integrations:** All Payment Links API calls must include the `X-MERCHANT-ID` header with the end merchant's Merchant ID.

---

## **Execution Flow**

```
1. Call SKILL_AUTH_GENERATE → obtain access_token
2. Call PAYLINK_CREATE       → get paylinkUrl to share with customer
3. Share paylinkUrl via SMS / email / WhatsApp
4. (Optional) Call PAYLINK_NOTIFY   → trigger PhonePe to resend SMS/email to customer
5. (Optional) Call PAYLINK_CANCEL   → deactivate link if no longer needed
6. Poll / webhook PAYLINK_STATUS    → confirm payment completion
7. (If needed) Call PAYLINK_REFUND  → initiate refund for completed payment
8. Poll PAYLINK_REFUND_STATUS       → confirm refund completion
```

---

## **Skill: PAYLINK_CREATE**

**Description:** Creates a new payment link and returns a `paylinkUrl` that can be shared with the customer.

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | POST   | `https://api-preprod.phonepe.com/apis/pg-sandbox/paylinks/v1/pay` |
| Production  | POST   | `https://api.phonepe.com/apis/pg/paylinks/v1/pay` |

### **Request Headers**

```
Content-Type: application/json
Authorization: O-Bearer <access_token>
X-MERCHANT-ID: <merchantId>          (mandatory for partner integrations)
```

### **Request Fields**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `merchantOrderId` | String | **YES** | Unique order identifier | Max 63 chars; alphanumeric, `_`, `-` only |
| `amount` | Long | **YES** | Payment amount in paisa | Min: 100 |
| `metaInfo.udf1–udf10` | String | NO | Free-form metadata returned in status/callback | Max 256 chars each |
| `metaInfo.udf11–udf15` | String | NO | Restricted metadata | Max 50 chars; alphanumeric + `_ - @ . +` only |
| `paymentFlow.type` | String | **YES** | Must be `"PAYLINK"` | — |
| `paymentFlow.customerDetails.name` | String | NO | Customer's name | — |
| `paymentFlow.customerDetails.phoneNumber` | String | NO | Customer's mobile (with country code, e.g. `+919999988888`) | Required if SMS notification is needed |
| `paymentFlow.customerDetails.email` | String | NO | Customer's email address | Required if email notification is needed |
| `paymentFlow.notificationChannels.SMS` | Boolean | NO | Send SMS on link creation | Default: `false` |
| `paymentFlow.notificationChannels.EMAIL` | Boolean | NO | Send email on link creation | Default: `false` |
| `paymentFlow.expireAt` | Long | NO | Link expiry epoch (ms) | Max 30 days from creation |

> ⚠️ Do NOT rename `metaInfo.udf*` keys — renamed keys cause issues in status and webhook callbacks.

### **Sample Request**

```json
{
    "merchantOrderId": "ORD-PL-001",
    "amount": 10000,
    "metaInfo": {
        "udf1": "customer-ref-001",
        "udf2": "invoice-nov-2024"
    },
    "paymentFlow": {
        "type": "PAYLINK",
        "customerDetails": {
            "name": "Arjun",
            "phoneNumber": "+919999988888",
            "email": "arjun@example.com"
        },
        "notificationChannels": {
            "SMS": true,
            "EMAIL": false
        },
        "expireAt": 1734109588000
    }
}
```

### **Success Response**

```json
{
    "orderId": "OMOxxxxxxxxxxxx",
    "state": "ACTIVE",
    "expireAt": 1734109588000,
    "paylinkUrl": "https://phon.pe/some-key"
}
```

| Field | Description |
|-------|-------------|
| `orderId` | PhonePe internal order ID |
| `state` | Always `ACTIVE` on creation |
| `expireAt` | Link expiry (epoch milliseconds) |
| `paylinkUrl` | Shareable payment URL — send this to your customer |

### **Error Responses**

| Code | Meaning | Action |
|------|---------|--------|
| `BAD_REQUEST` | Invalid or missing fields | Validate all required fields |
| `INVALID_EXPIRY` | `expireAt` exceeds 30 days | Set `expireAt` within 30 days of creation |
| `INTERNAL_SERVER_ERROR` | Server error | Retry with exponential backoff |

### **Implementation Checklist for AI**

- [ ] Call `SKILL_AUTH_GENERATE` first to get `access_token`
- [ ] Set `paymentFlow.type = "PAYLINK"` — any other value will fail
- [ ] Include `customerDetails.phoneNumber` if SMS notifications are required
- [ ] Set `expireAt` to ≤ 30 days from now (in epoch milliseconds)
- [ ] Share the returned `paylinkUrl` with the customer via your preferred channel
- [ ] After sharing, poll `PAYLINK_STATUS` to confirm payment completion

---

## **Skill: PAYLINK_STATUS**

**Description:** Retrieves the current status of a payment link by `merchantOrderId`. Use this to confirm payment completion or track customer payment attempts.

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | GET    | `https://api-preprod.phonepe.com/apis/pg-sandbox/paylinks/v1/{merchantOrderId}/status?details=true` |
| Production  | GET    | `https://api.phonepe.com/apis/pg/paylinks/v1/{merchantOrderId}/status?details=true` |

### **Query Parameters**

| Parameter | Description |
|-----------|-------------|
| `details=true` | Returns all payment attempt details in `paymentDetails` list |
| `details=false` | Returns only the most recent attempt in `paymentDetails` list |

### **Request Headers**

```
Content-Type: application/json
Authorization: O-Bearer <access_token>
X-MERCHANT-ID: <merchantId>          (mandatory for partner integrations)
```

### **Response States**

| State | Meaning | Action |
|-------|---------|--------|
| `ACTIVE` | Link is live; no successful payment yet | Continue polling or wait for webhook |
| `COMPLETED` | Payment successful | Fulfill the order |
| `FAILED` | All payment attempts failed | Recreate link or contact customer |
| `EXPIRED` | Link passed `expireAt` without payment | Recreate a new payment link |
| `CANCELLED` | Link was cancelled via `PAYLINK_CANCEL` | No further action; create a new one if needed |

### **Sample Response (COMPLETED)**

```json
{
    "orderId": "OMOxxxxxxxxxxxx",
    "state": "COMPLETED",
    "amount": 10000,
    "expireAt": 1734109588000,
    "metaInfo": {
        "udf1": "customer-ref-001"
    },
    "paymentFlow": {
        "type": "PAYLINK",
        "paylinkUrl": "https://phon.pe/some-key"
    },
    "paymentDetails": [
        {
            "paymentMode": "UPI_QR",
            "transactionId": "OM12334",
            "timestamp": 1703756259307,
            "amount": 10000,
            "state": "COMPLETED",
            "rail": {
                "type": "UPI",
                "utr": "586756785",
                "upiTransactionId": "YBL5bc011fa9f8644763b52b96a29a9655",
                "vpa": "12****78@ybl"
            },
            "instrument": {
                "type": "ACCOUNT",
                "accountType": "SAVINGS",
                "accountNumber": "******1234"
            }
        }
    ]
}
```

### **`paymentDetails` Fields**

| Field | Description |
|-------|-------------|
| `paymentMode` | Payment method used: `UPI_INTENT`, `UPI_COLLECT`, `UPI_QR`, `CARD`, `TOKEN`, `NET_BANKING` |
| `transactionId` | PhonePe internal transaction ID for this attempt |
| `timestamp` | Epoch timestamp of this attempt |
| `amount` | Amount in paisa for this attempt |
| `state` | `PENDING`, `COMPLETED`, or `FAILED` |
| `errorCode` | Error code (only when `state = FAILED`) |
| `detailedErrorCode` | Detailed error reason (only when `state = FAILED`) |
| `rail.type` | `UPI` or `PG` |
| `instrument.type` | `ACCOUNT`, `CREDIT_CARD`, `DEBIT_CARD`, or `NET_BANKING` |

> ⚠️ **Always use the top-level `state` field to determine final payment status** — do not rely solely on `paymentDetails[].state`.

---

## **Skill: PAYLINK_NOTIFY**

**Description:** Triggers PhonePe to resend the payment link to the customer via SMS and/or email. Use this when the customer hasn't received the link or needs a reminder.

> ⚠️ PhonePe enforces a maximum number of notification attempts per order. Exceeding this returns `NOTIFICATION_ATTEMPTS_BREACHED`.

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | POST   | `https://api-preprod.phonepe.com/apis/pg-sandbox/paylinks/v1/notify` |
| Production  | POST   | `https://api.phonepe.com/apis/pg/paylinks/v1/notify` |

### **Request Headers**

```
Content-Type: application/json
Authorization: O-Bearer <access_token>
X-MERCHANT-ID: <merchantId>          (mandatory for partner integrations)
```

### **Request Fields**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `merchantOrderId` | String | **YES** | The `merchantOrderId` of the existing payment link |
| `notificationChannels.sms` | Boolean | **YES** | `true` to send SMS to the customer's registered mobile |
| `notificationChannels.email` | Boolean | **YES** | `true` to send email to the customer's registered email |

### **Sample Request**

```json
{
    "merchantOrderId": "ORD-PL-001",
    "notificationChannels": {
        "sms": true,
        "email": false
    }
}
```

### **Success Response**

```json
{
    "orderId": "OMOxxxxxxxxxxxx",
    "paylinkUrl": "https://phon.pe/some-key"
}
```

### **Error Responses**

| Code | Meaning | Action |
|------|---------|--------|
| `NOTIFICATION_ATTEMPTS_BREACHED` | Max notification attempts exceeded | Do not retry; inform the customer through another channel |
| `BAD_REQUEST` | Invalid `merchantOrderId` or missing fields | Verify the order exists and is in `ACTIVE` state |

### **Implementation Checklist for AI**

- [ ] Only call `PAYLINK_NOTIFY` for links that are in `ACTIVE` state
- [ ] Ensure `customerDetails.phoneNumber` was set during link creation before sending SMS
- [ ] Ensure `customerDetails.email` was set during link creation before sending email
- [ ] Do not loop on `NOTIFICATION_ATTEMPTS_BREACHED` — surface this to the merchant

---

## **Skill: PAYLINK_CANCEL**

**Description:** Deactivates an active payment link so the customer can no longer use it. Use this when an order is cancelled, the price changes, or the link is no longer valid.

> ⚠️ A link can only be cancelled if it is in `ACTIVE` state. Attempting to cancel a `COMPLETED`, `FAILED`, or already `CANCELLED` link returns `BAD_REQUEST`.

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | POST   | `https://api-preprod.phonepe.com/apis/pg-sandbox/paylinks/v1/{merchantOrderId}/cancel` |
| Production  | POST   | `https://api.phonepe.com/apis/pg/paylinks/v1/{merchantOrderId}/cancel` |

### **Request Headers**

```
Content-Type: application/json
Authorization: O-Bearer <access_token>
X-MERCHANT-ID: <merchantId>          (mandatory for partner integrations)
```

> ℹ️ The request body is empty (`{}`).

### **Success Response**

```json
{
    "orderId": "OMOxxxxxxxxxxxx",
    "state": "CANCELLED"
}
```

### **Error Responses**

| Code | Meaning | Action |
|------|---------|--------|
| `BAD_REQUEST` | Link already in a terminal state (`COMPLETED`, `FAILED`, `CANCELLED`, `EXPIRED`) | Check `PAYLINK_STATUS` before cancelling |

### **Implementation Checklist for AI**

- [ ] Call `PAYLINK_STATUS` first to confirm the link is `ACTIVE` before attempting cancellation
- [ ] Send an empty JSON body `{}` — no request body fields are needed
- [ ] After cancellation, create a new link via `PAYLINK_CREATE` if a replacement is needed

---

## **Skill: PAYLINK_REFUND**

**Description:** Initiates a full or partial refund for a completed payment link order. The refund is credited back to the customer's original payment instrument.

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | POST   | `https://api-preprod.phonepe.com/apis/pg-sandbox/payments/v2/refund` |
| Production  | POST   | `https://api.phonepe.com/apis/pg/payments/v2/refund` |

### **Request Headers**

```
Content-Type: application/json
Authorization: O-Bearer <access_token>
X-MERCHANT-ID: <merchantId>          (mandatory for partner integrations)
```

### **Request Fields**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `merchantRefundId` | String | **YES** | Unique identifier for this refund | Max 63 chars; alphanumeric, `_`, `-` only |
| `originalMerchantOrderId` | String | **YES** | The `merchantOrderId` of the completed payment link order | Order must be in `COMPLETED` state |
| `amount` | Long | **YES** | Refund amount in paisa | Must be ≤ original order amount |

### **Sample Request**

```json
{
    "merchantRefundId": "REFUND-PL-001",
    "originalMerchantOrderId": "ORD-PL-001",
    "amount": 10000
}
```

### **Success Response**

```json
{
    "originalMerchantOrderId": "ORD-PL-001",
    "amount": 10000,
    "state": "PENDING",
    "refundId": "OMR7878098045517540996"
}
```

### **Refund States**

| State | Meaning | Action |
|-------|---------|--------|
| `PENDING` | Refund accepted and queued | Store `refundId`; poll `PAYLINK_REFUND_STATUS` or await webhook |
| `COMPLETED` | Refund credited to customer | Notify customer; update your records |
| `FAILED` | Refund could not be processed | Contact PhonePe support with the `refundId` |

> ⚠️ Always use a **unique `merchantRefundId`** per refund. Never reuse refund IDs.

### **Implementation Checklist for AI**

- [ ] Confirm the original order is `COMPLETED` via `PAYLINK_STATUS` before initiating a refund
- [ ] Ensure `amount` ≤ original order amount
- [ ] Generate a new unique `merchantRefundId` — never reuse
- [ ] Store the returned `refundId` for tracking
- [ ] Poll `PAYLINK_REFUND_STATUS` or wait for webhook to confirm final state

---

## **Skill: PAYLINK_REFUND_STATUS**

**Description:** Retrieves the current status of a refund by `merchantRefundId`.

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | GET    | `https://api-preprod.phonepe.com/apis/pg-sandbox/payments/v2/refund/{merchantRefundId}/status` |
| Production  | GET    | `https://api.phonepe.com/apis/pg/payments/v2/refund/{merchantRefundId}/status` |

### **Request Headers**

```
Content-Type: application/json
Authorization: O-Bearer <access_token>
X-MERCHANT-ID: <merchantId>          (mandatory for partner integrations)
```

### **Sample Response (COMPLETED)**

```json
{
    "originalMerchantOrderId": "ORD-PL-001",
    "amount": 10000,
    "state": "COMPLETED",
    "timestamp": 1730869961754,
    "refundId": "OMR7878098045517540996",
    "splitInstruments": [
        {
            "amount": 10000,
            "rail": {
                "type": "UPI",
                "utr": "586756785",
                "upiTransactionId": "YBL5bc011fa9f8644763b52b96a29a9655",
                "vpa": "12****78@ybl"
            },
            "instrument": {
                "type": "ACCOUNT",
                "maskedAccountNumber": "******1234",
                "accountType": "SAVINGS"
            }
        }
    ]
}
```

| Field | Description |
|-------|-------------|
| `state` | `PENDING`, `COMPLETED`, or `FAILED` |
| `refundId` | PhonePe internal refund ID |
| `splitInstruments` | Breakdown of how the refund was credited (e.g. split across UPI + wallet) |
| `errorCode` | Error code — only present when `state = FAILED` |
| `detailedErrorCode` | Detailed error — only present when `state = FAILED` |

---

## **Overall Implementation Checklist for AI**

- [ ] Call `SKILL_AUTH_GENERATE` before every Payment Links API call
- [ ] Set `paymentFlow.type = "PAYLINK"` in create requests — no other value is valid
- [ ] Include `X-MERCHANT-ID` header for all calls in partner/aggregator integrations
- [ ] Set `expireAt` within 30 days of creation (in epoch milliseconds)
- [ ] Only call `PAYLINK_NOTIFY` for `ACTIVE` links; respect `NOTIFICATION_ATTEMPTS_BREACHED`
- [ ] Only call `PAYLINK_CANCEL` for `ACTIVE` links — check status first
- [ ] Only initiate `PAYLINK_REFUND` for `COMPLETED` orders
- [ ] Use a unique `merchantRefundId` for every refund — never reuse
- [ ] Do NOT rename `metaInfo.udf*` keys — renamed keys cause callback issues
- [ ] Always verify final payment state via `PAYLINK_STATUS` before fulfilling an order
