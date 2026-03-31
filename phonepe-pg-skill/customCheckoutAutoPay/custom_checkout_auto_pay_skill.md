# **AutoPay (Recurring Payments) Integration**

AutoPay enables merchants to collect recurring payments from customers with a single upfront authorization. After the customer authorizes the mandate, the merchant can trigger deductions automatically without requiring the customer's involvement for each payment.

**Typical use cases:** OTT subscriptions, insurance premiums, loan EMIs, SaaS billing, memberships.

---

## **AutoPay Lifecycle Overview**

```
1. SETUP    → Customer authorizes the subscription mandate (one-time)
2. NOTIFY   → Merchant informs PhonePe before each deduction cycle
3. REDEEM   → PhonePe executes the actual deduction
4. STATUS   → Merchant checks subscription or order status
5. CANCEL   → Merchant cancels the subscription when needed
```

---

## **Skill: AUTOPAY_SETUP**

**Description:** Initiates a subscription mandate setup. The customer authorizes the mandate once. All future deductions happen without customer involvement.

---

### **Dependencies**

* **Auth Provider:** [SKILL_AUTH_GENERATE](../SKILL.md#1-authentication-skill-base)

---

### **Execution Flow**

1. **Call Dependency:** Call `SKILL_AUTH_GENERATE` to obtain `access_token`
2. **Build Payload:** Construct `PgPaymentRequest` with `paymentFlow.type = "SUBSCRIPTION_SETUP"`
3. **Set Mandate Parameters:** `frequency`, `amountType`, `maxAmount`, `merchantSubscriptionId`
4. **Make API Call:** POST to the Setup endpoint
5. **Present to User:** Return `intentUrl` (for UPI_INTENT) for customer to authorize mandate
6. **Track Setup:** Call `AUTOPAY_ORDER_STATUS` to confirm mandate authorization

---

### **Environment & Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | POST   | `https://api-preprod.phonepe.com/apis/pg-sandbox/subscriptions/v2/setup` |
| Production  | POST   | `https://api.phonepe.com/apis/pg/subscriptions/v2/setup` |

### **Request Headers**

```
Authorization: O-Bearer <access_token>
Content-Type: application/json
```

---

### **Request Fields**

#### **Top-Level Fields**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `merchantOrderId` | String | **YES** | Unique order ID for the setup transaction | Max 63 chars; alphanumeric, `_`, `-` only |
| `amount` | Long | **YES** | Amount in paisa for the initial authorization transaction | `PENNY_DROP`: must be exactly `200`; `TRANSACTION`: ≥ `100` |
| `paymentFlow` | Object | **YES** | Subscription setup flow configuration | — |
| `deviceContext` | Object | **YES** | Device OS of the customer's device | Required for UPI_INTENT |
| `deviceContext.deviceOS` | String | **YES** | Operating system of the customer's device | `"ANDROID"` or `"IOS"` |
| `expireAt` | Long | NO | Order expiry (epoch milliseconds) | Default: 5 minutes |
| `metaInfo` | Object | NO | Merchant metadata (returned in status/callback) | `udf1–udf10`: max 256 chars; `udf11–udf15`: max 50 chars, alphanumeric + `_ - + @ .` only. **Key names must not be renamed — production error otherwise.** |

#### **`paymentFlow` Fields (type = `SUBSCRIPTION_SETUP`)**

| Field | Type | Required | Description | Values / Constraints |
|-------|------|----------|-------------|----------------------|
| `type` | String | **YES** | Flow type | Must be `"SUBSCRIPTION_SETUP"` |
| `merchantSubscriptionId` | String | **YES** | Merchant's unique subscription identifier | Max 63 chars |
| `authWorkflowType` | String | **YES** | How the mandate is verified | `"PENNY_DROP"` or `"TRANSACTION"` |
| `amountType` | String | **YES** | Whether deduction amount is fixed or variable | `"FIXED"` or `"VARIABLE"` |
| `maxAmount` | Long | **YES** | Maximum deductible per cycle (paisa) | For `VARIABLE`: treated as max cap |
| `frequency` | String | **YES** | Deduction frequency | See table below |
| `paymentMode` | Object | **YES** | How the customer authorizes the mandate | `UPI_INTENT` or `UPI_COLLECT` |
| `expireAt` | Long | NO | Subscription mandate expiry (epoch milliseconds) | Default: 30 years |

#### **`authWorkflowType` Options**

| Value | Description | `amount` Constraint |
|-------|-------------|---------------------|
| `PENNY_DROP` | PhonePe debits ₹2 to verify UPI ID; amount is reversed | Must be exactly `200` (₹2) |
| `TRANSACTION` | The `amount` is deducted as the first payment and serves as authorization | Must be ≥ `100` |

#### **`frequency` Options**

| Value | Description |
|-------|-------------|
| `DAILY` | Every day |
| `WEEKLY` | Every week |
| `FORTNIGHTLY` | Every two weeks |
| `MONTHLY` | Every month |
| `BIMONTHLY` | Every two months |
| `QUARTERLY` | Every quarter |
| `HALFYEARLY` | Every six months |
| `YEARLY` | Every year |
| `ONDEMAND` | No fixed schedule — merchant triggers each cycle manually via Notify + Redeem |

#### **`paymentMode` Options**

Only `UPI_INTENT` and `UPI_COLLECT` are supported for subscription setup.

**UPI_INTENT (Android):**
```json
"paymentMode": {
    "type": "UPI_INTENT",
    "targetApp": "com.phonepe.app"
}
```
Android `targetApp` = UPI app package name (e.g. `com.phonepe.app`, `com.google.android.apps.nbu.paisa.user`).

**UPI_INTENT (iOS):**
```json
"paymentMode": {
    "type": "UPI_INTENT",
    "targetApp": "PHONEPE"
}
```
iOS `targetApp` = static value from: `PHONEPE`, `GPAY`, `PAYTM`, `CRED`, `SUPERMONEY`, `BHIM`, `AMAZON`.

**UPI_COLLECT (via VPA):**
```json
"paymentMode": {
    "type": "UPI_COLLECT",
    "details": {
        "type": "VPA",
        "vpa": "customer@ybl"
    }
}
```

---

### **Sample Request — All Mandatory Fields (Android, UPI_INTENT)**

```json
{
    "merchantOrderId": "SETUP-ORD-001",
    "amount": 200,
    "paymentFlow": {
        "type": "SUBSCRIPTION_SETUP",
        "merchantSubscriptionId": "SUB-CUST-001-MONTHLY",
        "authWorkflowType": "PENNY_DROP",
        "amountType": "FIXED",
        "maxAmount": 49900,
        "frequency": "MONTHLY",
        "paymentMode": {
            "type": "UPI_INTENT",
            "targetApp": "com.phonepe.app"
        }
    },
    "deviceContext": {
        "deviceOS": "ANDROID"
    }
}
```

### **Sample Request — All Fields Including Optional**

```json
{
    "merchantOrderId": "SETUP-ORD-001",
    "amount": 200,
    "expireAt": 1770388701000,
    "paymentFlow": {
        "type": "SUBSCRIPTION_SETUP",
        "merchantSubscriptionId": "SUB-CUST-001-MONTHLY",
        "authWorkflowType": "PENNY_DROP",
        "amountType": "FIXED",
        "maxAmount": 49900,
        "frequency": "MONTHLY",
        "expireAt": 1800000000000,
        "paymentMode": {
            "type": "UPI_INTENT",
            "targetApp": "com.phonepe.app"
        }
    },
    "deviceContext": {
        "deviceOS": "ANDROID"
    },
    "metaInfo": {
        "udf1": "customer-tier:premium",
        "udf2": "plan:monthly-basic",
        "udf3": "source:app",
        "udf4": "",
        "udf5": "",
        "udf6": "",
        "udf7": "",
        "udf8": "",
        "udf10": "",
        "udf11": "ref-001",
        "udf12": "",
        "udf13": "",
        "udf14": "",
        "udf15": ""
    }
}
```

---

### **Sample Response**

```json
{
    "orderId": "OMO123456789",
    "state": "PENDING",
    "intentUrl": "ppe://transact?..."
}
```

| Field | Description |
|-------|-------------|
| `orderId` | PhonePe internal order ID |
| `state` | `PENDING` — customer must authorize |
| `intentUrl` | Deep-link to open the UPI app for mandate authorization (UPI_INTENT only) |

> **Integration Note:** After presenting the `intentUrl` to the customer, call `AUTOPAY_ORDER_STATUS` to verify the mandate was authorized (`state = COMPLETED`). Only proceed to `AUTOPAY_NOTIFY` after successful setup.

---

### **Error Handling**

| HTTP Code | Error Code | Description | Action |
|-----------|------------|-------------|--------|
| 400 | `BAD_REQUEST` | Missing required field or invalid field value | Validate all mandatory fields; check `deviceContext.deviceOS`, `paymentFlow.type`, `paymentMode` |
| 400 | `DUPLICATE_REQUEST_ID` | `merchantSubscriptionId` already used for an existing subscription | Generate a new unique `merchantSubscriptionId` |
| 401 | `AUTHORIZATION_FAILED` | Token missing, expired, or invalid | Refresh via `SKILL_AUTH_GENERATE`, retry once |
| 417 | `TRANSACTION_LIMIT_EXCEEDED` | `amount` or `maxAmount` exceeds the allowed limit | Reduce the amount; check per-transaction and mandate cap limits |
| 500 | `INTERNAL_SERVER_ERROR` | PhonePe server error | Retry with exponential backoff |

---

### **Implementation Checklist for AI**

- [ ] Call `SKILL_AUTH_GENERATE` to get `access_token`
- [ ] Set `paymentFlow.type = "SUBSCRIPTION_SETUP"`
- [ ] Provide a unique `merchantSubscriptionId` — this is the long-lived subscription identifier; reuse causes `DUPLICATE_REQUEST_ID`
- [ ] Choose `authWorkflowType`: `PENNY_DROP` (set `amount = 200` exactly) or `TRANSACTION` (set `amount` = first debit amount)
- [ ] Set `maxAmount` to the ceiling of what will ever be charged per cycle — PhonePe enforces this as a hard cap
- [ ] Include `deviceContext.deviceOS` — `"ANDROID"` or `"IOS"` (mandatory field)
- [ ] For UPI_INTENT Android: use package name in `targetApp`; for iOS: use static name (e.g. `"PHONEPE"`)
- [ ] Present `intentUrl` to the customer for mandate authorization
- [ ] Call `AUTOPAY_ORDER_STATUS` after setup to confirm `state = COMPLETED`

---

## **AutoPay Recurring Debit Standards**

> These rules apply to **every billing cycle** after a successful mandate setup. Violating the Notify → 24h gap → Redeem sequence will result in API errors or regulatory failures.

### Rule 1 — Notify before every debit (mandatory)

For every new billing cycle, regardless of `frequency`, the customer **must be notified** via `AUTOPAY_NOTIFY` before any deduction is executed. This is a regulatory requirement under UPI AutoPay guidelines. You cannot call `AUTOPAY_REDEEM` without a preceding successful `AUTOPAY_NOTIFY` for the same `merchantOrderId`.

### Rule 2 — Mandatory 24-hour gap between Notify and Redeem

After a successful `AUTOPAY_NOTIFY` (confirmed by `AUTOPAY_ORDER_STATUS` returning `NOTIFIED`), you must wait **at least 24 hours** before calling `AUTOPAY_REDEEM`. This window allows the customer to be informed of the upcoming debit in advance.

```
Timeline for each billing cycle:

  Day N, 10:00 AM  →  AUTOPAY_NOTIFY called
  Day N, 10:00 AM  →  Poll AUTOPAY_ORDER_STATUS until state = NOTIFIED
  Day N+1, 10:00 AM+  →  AUTOPAY_REDEEM called  (≥24 hours after Notify)
  Day N+1, 10:00 AM+  →  Poll AUTOPAY_ORDER_STATUS until COMPLETED or FAILED
```

### Rule 3 — Verify subscription is ACTIVE before each cycle

Before calling `AUTOPAY_NOTIFY` or `AUTOPAY_REDEEM`, always call `AUTOPAY_SUBSCRIPTION_STATUS` to confirm the subscription `state = ACTIVE`. Do not proceed if the subscription is `PAUSED`, `CANCELLED`, `REVOKED`, or `EXPIRED`.

### Rule 4 — New `merchantOrderId` per cycle

Each billing cycle must use a **fresh, unique `merchantOrderId`**. The same `merchantOrderId` used in Notify must be passed to Redeem. Never reuse a `merchantOrderId` across cycles.

### Rule 5 — Frequency cycle enforcement

Merchants are responsible for scheduling cycles according to the `frequency` agreed during setup:

| Frequency | Merchant's responsibility |
|-----------|--------------------------|
| `DAILY` | Trigger Notify + Redeem every day (respecting 24h gap) |
| `WEEKLY` | Trigger Notify + Redeem once per week |
| `MONTHLY` | Trigger Notify + Redeem once per month |
| `ONDEMAND` | Trigger Notify + Redeem whenever a debit is needed (no fixed schedule) |
| Others | Trigger per the agreed interval |

PhonePe does not auto-schedule redemptions — the merchant's backend is responsible for initiating each cycle.

### Summary — Per-Cycle Mandatory Sequence

```
1. Check AUTOPAY_SUBSCRIPTION_STATUS → must be ACTIVE
2. Call AUTOPAY_NOTIFY (with new merchantOrderId + amount for this cycle)
3. Poll AUTOPAY_ORDER_STATUS → wait for NOTIFIED
4. Wait ≥ 24 hours
5. Call AUTOPAY_REDEEM (same merchantOrderId as Notify)
6. Poll AUTOPAY_ORDER_STATUS → COMPLETED or FAILED
```

---

## **Skill: AUTOPAY_NOTIFY**

**Description:** Informs PhonePe that a deduction cycle is upcoming. Must be called before every `AUTOPAY_REDEEM`. PhonePe may notify the customer of the upcoming deduction.

---

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | POST   | `https://api-preprod.phonepe.com/apis/pg-sandbox/subscriptions/v2/notify` |
| Production  | POST   | `https://api.phonepe.com/apis/pg/subscriptions/v2/notify` |

---

### **Request Fields**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `merchantOrderId` | String | **YES** | Unique order ID for this deduction cycle |
| `paymentFlow.type` | String | **YES** | Must be `"SUBSCRIPTION_REDEMPTION"` |
| `paymentFlow.merchantSubscriptionId` | String | **YES** | The subscription ID from `AUTOPAY_SETUP` |
| `paymentFlow.redemptionRetryStrategy` | String | **YES** | Retry behavior on failure |
| `paymentFlow.autoDebit` | Boolean | NO | If `true`, PhonePe automatically executes the debit after 24 hours — merchant does **not** call `AUTOPAY_REDEEM`. If `false` (default), merchant must call `AUTOPAY_REDEEM` explicitly after 24 hours. |

#### **`autoDebit` — Two Execution Paths**

| `autoDebit` | Who calls Redeem? | Merchant action after Notify |
|-------------|-------------------|------------------------------|
| `false` (default) | **Merchant** calls `AUTOPAY_REDEEM` explicitly after ≥24h | Wait 24h → call `AUTOPAY_REDEEM` → poll `AUTOPAY_ORDER_STATUS` |
| `true` | **PhonePe** auto-executes after ≥24h from successful notification | Do NOT call `AUTOPAY_REDEEM`; poll `AUTOPAY_ORDER_STATUS` or wait for S2S callback for terminal state |

> ⚠️ If `autoDebit = true` and you also call `AUTOPAY_REDEEM`, the manual call will be rejected — PhonePe is already handling execution.

#### **`redemptionRetryStrategy` Options**

| Value | Description |
|-------|-------------|
| `STANDARD` | PhonePe retries on failure using a standard retry schedule |
| `CUSTOM` | Merchant controls retry timing (requires additional configuration) |

---

### **Sample Request**

```json
{
    "merchantOrderId": "CYCLE-ORD-001",
    "paymentFlow": {
        "type": "SUBSCRIPTION_REDEMPTION",
        "merchantSubscriptionId": "SUB-CUST-001-MONTHLY",
        "redemptionRetryStrategy": "STANDARD",
        "autoDebit": true
    }
}
```

### **Sample Response**

```json
{
    "orderId": "OMO987654321",
    "state": "PENDING"
}
```

---

### **Implementation Checklist for AI**

- [ ] Generate a **new unique** `merchantOrderId` for each billing cycle — never reuse
- [ ] Use the same `merchantSubscriptionId` from the original `AUTOPAY_SETUP`
- [ ] Call `AUTOPAY_NOTIFY` before calling `AUTOPAY_REDEEM`
- [ ] If `autoDebit = true`: do **not** call `AUTOPAY_REDEEM` — PhonePe executes after 24h automatically; poll `AUTOPAY_ORDER_STATUS` or wait for S2S callback
- [ ] If `autoDebit = false`: wait ≥24h after Notify is `NOTIFIED`, then call `AUTOPAY_REDEEM`

---

## **Skill: AUTOPAY_REDEEM**

**Description:** Triggers the actual deduction for a subscription cycle. Must be called after `AUTOPAY_NOTIFY` confirms `NOTIFIED` state, and only when `autoDebit = false`. If `autoDebit = true` was set in the Notify call, **do not call this API** — PhonePe handles execution automatically after 24 hours.

---

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | POST   | `https://api-preprod.phonepe.com/apis/pg-sandbox/subscriptions/v2/redeem` |
| Production  | POST   | `https://api.phonepe.com/apis/pg/subscriptions/v2/redeem` |

---

### **Request Fields**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `merchantOrderId` | String | **YES** | The same `merchantOrderId` used in `AUTOPAY_NOTIFY` |

### **Sample Request**

```json
{
    "merchantOrderId": "CYCLE-ORD-001"
}
```

### **Sample Response**

```json
{
    "transactionId": "TXN-987654321",
    "state": "PENDING"
}
```

| Field | Description |
|-------|-------------|
| `transactionId` | PhonePe transaction ID for this deduction |
| `state` | `PENDING` initially; becomes `COMPLETED` or `FAILED` |

> **Integration Note:** After a successful Redeem call, the initial response returns `PENDING`. A redemption can take **up to 48 hours** to reach a terminal state (`COMPLETED`, `FAILED`, or `EXPIRED`). Poll `AUTOPAY_ORDER_STATUS` periodically or rely on S2S callbacks to detect the final outcome. If `autoDebit = true` was set in Notify, skip calling Redeem entirely — PhonePe handles execution; poll `AUTOPAY_ORDER_STATUS` or wait for an S2S callback.

---

### **Implementation Checklist for AI**

- [ ] Only call `AUTOPAY_REDEEM` if Notify was sent with `autoDebit = false`
- [ ] If `autoDebit = true`: skip this skill — PhonePe auto-executes after 24h
- [ ] Use the same `merchantOrderId` from the Notify call
- [ ] Store the returned `transactionId` for tracking
- [ ] Poll `AUTOPAY_ORDER_STATUS` or wait for S2S callback to confirm terminal state (`COMPLETED`, `FAILED`, or `EXPIRED`) — can take up to 48 hours

---

## **Skill: AUTOPAY_SUBSCRIPTION_STATUS**

**Description:** Retrieves the current status of a subscription mandate (not a specific order).

---

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | GET    | `https://api-preprod.phonepe.com/apis/pg-sandbox/subscriptions/v2/{merchantSubscriptionId}/status` |
| Production  | GET    | `https://api.phonepe.com/apis/pg/subscriptions/v2/{merchantSubscriptionId}/status` |

---

### **Path Parameters**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `merchantSubscriptionId` | **YES** | The subscription ID from `AUTOPAY_SETUP` |

---

### **Response Fields**

| Field | Type | Description |
|-------|------|-------------|
| `merchantSubscriptionId` | String | Merchant's subscription ID |
| `subscriptionId` | String | PhonePe's internal subscription ID |
| `state` | String | Current subscription state |
| `authWorkflowType` | String | `PENNY_DROP` or `TRANSACTION` |
| `amountType` | String | `FIXED` or `VARIABLE` |
| `maxAmount` | Long | Max deductible amount per cycle (paisa) |
| `frequency` | String | Deduction frequency |
| `expireAt` | Long | Subscription expiry (epoch milliseconds) |
| `pauseStartDate` | Long | Pause start date (if paused) |
| `pauseEndDate` | Long | Pause end date (if paused) |

#### **Subscription States**

| State | Meaning |
|-------|---------|
| `ACTIVE` | Subscription is live; deductions can proceed |
| `PENDING` | Awaiting customer authorization (setup not yet complete) |
| `PAUSED` | Temporarily paused by customer |
| `CANCELLED` | Permanently cancelled; cannot be reactivated |
| `EXPIRED` | Past `expireAt`; no further deductions |

---

## **Skill: AUTOPAY_ORDER_STATUS**

**Description:** Retrieves the status of a specific subscription order (setup or redemption cycle) by `merchantOrderId`.

---

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | GET    | `https://api-preprod.phonepe.com/apis/pg-sandbox/subscriptions/v2/order/{merchantOrderId}/status` |
| Production  | GET    | `https://api.phonepe.com/apis/pg/subscriptions/v2/order/{merchantOrderId}/status` |

### **Response**

Returns the same `OrderStatusResponse` structure as `CHECK_PAYMENT_STATUS`.

| State | Meaning | Action |
|-------|---------|--------|
| `COMPLETED` | Setup authorized / deduction successful | Proceed; update records |
| `PENDING` | In progress | Poll every 5–10s |
| `FAILED` | Failed | Check `errorCode`; retry with new `merchantOrderId` |

---

## **Skill: AUTOPAY_CANCEL**

**Description:** Permanently cancels a subscription mandate. The customer will no longer be charged.

---

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | POST   | `https://api-preprod.phonepe.com/apis/pg-sandbox/subscriptions/v2/{merchantSubscriptionId}/cancel` |
| Production  | POST   | `https://api.phonepe.com/apis/pg/subscriptions/v2/{merchantSubscriptionId}/cancel` |

### **Request**

No request body required. Only the path parameter `merchantSubscriptionId` is needed.

### **Response**

HTTP 200 with no body = cancellation accepted.

> ⚠️ Cancellation is **permanent**. A cancelled subscription cannot be reactivated. The merchant must create a new subscription setup if needed.

---

## **Complete AutoPay Integration Flow**

```
Phase 1 — Setup (One-time, customer action required)
──────────────────────────────────────────────────
1. Call AUTOPAY_SETUP with merchantSubscriptionId, frequency, maxAmount
2. Present intentUrl to customer → Customer authorizes mandate in UPI app
3. Poll AUTOPAY_ORDER_STATUS until state = COMPLETED
   → Subscription is now ACTIVE

Phase 2 — Each Billing Cycle (Automated, no customer action)
─────────────────────────────────────────────────────────────
4. Call AUTOPAY_NOTIFY with new merchantOrderId for the cycle
5. Call AUTOPAY_REDEEM with the same merchantOrderId
6. Poll AUTOPAY_ORDER_STATUS until COMPLETED or FAILED
   → If FAILED: check errorCode, retry or notify customer

Phase 3 — Subscription Management
───────────────────────────────────
7. Call AUTOPAY_SUBSCRIPTION_STATUS to check mandate health
8. Call AUTOPAY_CANCEL when the subscription should end
```

---

## **Retry & Error Strategy for Redemptions**

| Scenario | Recommended Action |
|----------|-------------------|
| `FAILED` with `INSUFFICIENT_FUNDS` | Wait and retry in 24–48 hours; notify customer |
| `FAILED` with `INVALID_VPA` | Customer's UPI changed; re-setup required |
| `FAILED` with bank error | Retry once; if persists escalate to PhonePe support |
| `PENDING` after long wait | Check `expireAt`; if expired treat as failed |
| Subscription `EXPIRED` | Create new subscription via `AUTOPAY_SETUP` |
| Subscription `CANCELLED` | Cannot reactivate; create new `AUTOPAY_SETUP` |

---

## **Implementation Checklist for AI**

- [ ] Call `SKILL_AUTH_GENERATE` before every API call
- [ ] Use `paymentFlow.type = "SUBSCRIPTION_SETUP"` for setup, `"SUBSCRIPTION_REDEMPTION"` for notify/redeem
- [ ] Store `merchantSubscriptionId` persistently — it is the long-lived subscription identifier
- [ ] Generate a **fresh** `merchantOrderId` for each billing cycle
- [ ] Always call `AUTOPAY_NOTIFY` before `AUTOPAY_REDEEM` — skipping notify will result in errors
- [ ] Choose `authWorkflowType = "PENNY_DROP"` for non-disruptive setup (recommended)
- [ ] Set `maxAmount` to the maximum any single cycle could ever charge — it is a hard limit
- [ ] Poll `AUTOPAY_ORDER_STATUS` after setup and each redeem to verify outcomes
- [ ] Inform merchant: cancelled subscriptions cannot be reactivated
- [ ] Inform merchant: `ON_DEMAND` frequency means the merchant controls the timing of each cycle via Notify+Redeem
