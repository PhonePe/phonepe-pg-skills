---
name: phonepe-pg-skill
description: Assist in integrating with PhonePe PG APIs for one-time payments and refunds
metadata:
  author: PhonePe
  version: "1.3.1"
---

## When to Apply
Reference these guidelines when:
- Implementing PhonePe PG Standard Checkout payment integration
- Implementing PhonePe PG Custom Checkout with UPI, Card, or Net Banking
- Setting up AutoPay / recurring subscription payments via PhonePe PG
- Generating or refreshing PhonePe PG OAuth authentication tokens
- Processing refunds for completed PhonePe PG transactions
- Checking PhonePe payment or subscription status
- Handling PhonePe payment callbacks or webhook verification
- Debugging `AUTHORIZATION_FAILED`, `INVALID_TRANSACTION_ID`, or token expiry errors
- Switching between PhonePe sandbox and production environments

# **Payment Gateway Integration Skills**

## **1. Authentication Skill (Base)**

**ID:** SKILL_AUTH_GENERATE

**Description:** Every PhonePe PG API request requires an `O-Bearer` access token obtained from `/v1/oauth/token`. Tokens should be cached and reused until near expiry to avoid unnecessary round-trips.

> ⚠️ **Environment Note:** The OAuth API path differs between Sandbox and Production — a simple host swap is **not** sufficient. See the endpoint table below.

### **Execution Flow**

1. **Check Cache:** If a valid cached token exists and `current_time < expires_at - 60 seconds`, use it.
2. **Fetch Token:** POST to the environment-specific OAuth endpoint with credentials.
3. **Cache Result:** Store `access_token` and `expires_at` from the response.
4. **Return Token:** Pass `access_token` to the calling skill via `Authorization: O-Bearer <access_token>`.

### **Environment & Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | POST   | `https://api-preprod.phonepe.com/apis/pg-sandbox/v1/oauth/token` |
| Production  | POST   | `https://api.phonepe.com/apis/identity-manager/v1/oauth/token` |

### **Request**

**Headers:**
```
Content-Type: application/x-www-form-urlencoded
```

**Request Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `client_id` | String | **YES** | Merchant Client ID provided by PhonePe |
| `client_secret` | String | **YES** | Merchant Client Secret provided by PhonePe |
| `client_version` | Integer | **YES** | Client version number provided by PhonePe |
| `grant_type` | String | **YES** | Must be `client_credentials` |

**Sample Request:**
```bash
curl --location 'https://api-preprod.phonepe.com/apis/pg-sandbox/v1/oauth/token' \
--header 'Content-Type: application/x-www-form-urlencoded' \
--data-urlencode 'client_id=CLIENT_ID' \
--data-urlencode 'client_version=CLIENT_VERSION' \
--data-urlencode 'client_secret=CLIENT_SECRET' \
--data-urlencode 'grant_type=client_credentials'
```

### **Response**

**Response Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `access_token` | String | Bearer token for API authorization |
| `token_type` | String | Always `O-Bearer` |
| `expires_at` | Long | Token expiry (Unix epoch seconds) |
| `issued_at` | Long | Token issue time (Unix epoch seconds) |

**Sample Response:**
```json
{
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHBpcmVzT24iOjE3MjA2MzUzMjE5OTYsIm1lcmNoYW50SWQiOiJWUlVBVCJ9.4YjYHI6Gy6gzOisD_628wfbaI46dMSc5T_0gZ2-SAJo",
    "encrypted_access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHBpcmVzT24iOjE3MjA2MzUzMjE5OTYsIm1lcmNoYW50SWQiOiJWUlVBVCJ9.4YjYHI6Gy6gzOisD_628wfbaI46dMSc5T_0gZ2-SAJo",
    "issued_at": 1706073005,
    "expires_at": 1706697605,
    "session_expires_at": 1706697605,
    "token_type": "O-Bearer"
}
```

### **Error Handling**

| HTTP Code | Cause | Action |
|-----------|-------|--------|
| 400 | Missing or malformed credentials | Verify all 4 request fields are present |
| 401 | Invalid `client_id` or `client_secret` | Check credentials with PhonePe PG team |
| 500 | Server error | Retry after a short delay |

### **Implementation Checklist for AI**

- [ ] Always check the token cache before fetching a new token
- [ ] Use the correct environment endpoint — Sandbox and Production paths differ
- [ ] Set `Content-Type: application/x-www-form-urlencoded`
- [ ] Include all 4 required fields: `client_id`, `client_secret`, `client_version`, `grant_type=client_credentials`
- [ ] Cache `access_token` and `expires_at`; refresh proactively 60 seconds before expiry
- [ ] Use `Authorization: O-Bearer <access_token>` in all downstream API calls

---

## **2. Refund Skill**

**ID:** SKILL_PAYMENT_REFUND

**Description:** Processes a full or partial refund for a successful PhonePe transaction.

**Prerequisite:** The original order must be in `COMPLETED` state. Call `SKILL_AUTH_GENERATE` to obtain a valid token.

### **Execution Flow**

1. **Call Dependency:** Call `SKILL_AUTH_GENERATE` to obtain `access_token`.
2. **Validate State:** Confirm the original order is `COMPLETED` before proceeding.
3. **Build Payload:** Construct the refund JSON with all required fields.
4. **Make API Call:** POST to the refund endpoint with `Authorization: O-Bearer <access_token>`.
5. **Handle Response:** Return `refundId` and `state`, or surface error details.

### **Environment & Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | POST   | `https://api-preprod.phonepe.com/apis/pg-sandbox/payments/v2/refund` |
| Production  | POST   | `https://api.phonepe.com/apis/pg/payments/v2/refund` |

### **Request**

**Headers:**
```
Authorization: O-Bearer <access_token>
Content-Type: application/json
```

**Request Fields:**

| Field | Type | Required | Description | Validation |
|-------|------|----------|-------------|------------|
| `merchantRefundId` | String | **YES** | Unique identifier for this refund | Max 63 chars; alphanumeric, `_`, `-` only |
| `originalMerchantOrderId` | String | **YES** | The `merchantOrderId` of the order being refunded | Must correspond to a `COMPLETED` order |
| `amount` | Long | **YES** | Refund amount in paisa | Must be ≤ original order amount |

**Sample Request:**
```json
{
    "merchantRefundId": "REFUND-12345",
    "originalMerchantOrderId": "ORDER-12345",
    "amount": 1234
}
```

### **Response**

**Sample Response (Refund Accepted):**
```json
{
    "refundId": "OMRxxxxx",
    "amount": 1234,
    "state": "PENDING"
}
```

**Refund States:**

| State | Meaning | Recommended Action |
|-------|---------|-------------------|
| `PENDING` | Refund accepted and queued for processing | Track `refundId`; poll or await webhook for completion |
| `COMPLETED` | Refund successfully credited to the customer | Notify the customer and update your records |
| `FAILED` | Refund could not be processed | Contact PhonePe PG support with the `refundId` |

### **Error Handling**

| HTTP Code | Error Code | Cause | Action |
|-----------|------------|-------|--------|
| 200/201 | — | Refund accepted | Return `refundId` and `state` |
| 400 | BAD_REQUEST | Invalid payload or amount exceeds original | Validate all fields; check `amount` |
| 401 | AUTHORIZATION_FAILED | Expired or invalid token | Call `SKILL_AUTH_GENERATE` to refresh, then retry once |
| 402 | — | Refund not eligible | Review refund eligibility with PhonePe |
| 403 | FORBIDDEN | Insufficient permissions | Verify merchant credentials |
| 500 | INTERNAL_SERVER_ERROR | Server error | Retry after delay; escalate to support if persistent |

### **Implementation Checklist for AI**

- [ ] Call `SKILL_AUTH_GENERATE` first to obtain `access_token`
- [ ] Use `Authorization: O-Bearer <access_token>` header (not `Bearer`)
- [ ] Ensure `merchantRefundId` is unique — do **not** reuse refund IDs
- [ ] Confirm `amount` does not exceed the original order amount
- [ ] Handle 401 by refreshing the token and retrying once
- [ ] Store the returned `refundId` for tracking
- [ ] Inform the user that the initial `state` will be `PENDING`; completion is asynchronous

---

## **3. Standard Checkout One-Time Payment Skills**

For Standard Checkout (PhonePe-hosted payment page + JS SDK), refer to:
[Standard Checkout Integration](./standardCheckoutIntegration/standard_checkout_integration_skill.md)

Skills included:
- **INITIATE_STANDARD_CHECKOUT_PAYMENT** — Create a payment order and get the hosted page URL
- **LAUNCH_PAYMENT_PAGE** — Open the payment page via PhonePe JS SDK (required; direct navigation fails)
- **CHECK_PAYMENT_STATUS** — Poll order status until COMPLETED or FAILED

---

## **4. Standard Checkout AutoPay Skills**

For recurring subscription mandate setup using PhonePe's hosted page and JS SDK, refer to:
[Standard Checkout AutoPay](./standardCheckoutAutoPay/standard_checkout_auto_pay_skill.md)

Skills included:
- **AUTOPAY_SC_SETUP** — Create subscription order (`SUBSCRIPTION_CHECKOUT_SETUP`); launch hosted page via JS SDK
- **AUTOPAY_SC_ORDER_STATUS** — Check setup or redemption order status
- **AUTOPAY_SC_SUBSCRIPTION_STATUS** — Check subscription mandate health
- **AUTOPAY_SC_NOTIFY** — Notify customer 24h before deduction (`SUBSCRIPTION_CHECKOUT_REDEMPTION`)
- **AUTOPAY_SC_REDEEM** — Execute the deduction for a billing cycle
- **AUTOPAY_SC_CANCEL** — Cancel the subscription permanently (merchant-initiated)

---

## **5. Custom Checkout One-Time Payment Skills**

For Custom Checkout (merchant-controlled payment UI), refer to:
[Custom Checkout Integration](./customCheckoutIntegration/custom_checkout_integration_skill.md)

Skills included:
- **CUSTOM_CHECKOUT_PAY** — Initiate payment with UPI_INTENT, UPI_COLLECT, UPI_QR, NET_BANKING, CARD, TOKEN
- **CUSTOM_CHECKOUT_ORDER_STATUS** — Check payment order status
- **CUSTOM_CHECKOUT_TRANSACTION_STATUS** — Check specific transaction attempt status

---

## **6. Custom Checkout AutoPay Skills**

For recurring subscription mandate setup where the merchant controls the payment UI (UPI_INTENT or UPI_COLLECT), refer to:
[Custom Checkout AutoPay](./customCheckoutAutoPay/custom_checkout_auto_pay_skill.md)

Skills included:
- **AUTOPAY_SETUP** — Set up mandate via API with UPI_INTENT or UPI_COLLECT (`SUBSCRIPTION_SETUP`)
- **AUTOPAY_NOTIFY** — Notify PhonePe before each billing cycle
- **AUTOPAY_REDEEM** — Execute deduction for a billing cycle
- **AUTOPAY_SUBSCRIPTION_STATUS** — Check subscription mandate status
- **AUTOPAY_ORDER_STATUS** — Check specific order status
- **AUTOPAY_CANCEL** — Cancel the subscription permanently
