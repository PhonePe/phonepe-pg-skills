# **Standard Checkout AutoPay Integration**

Standard Checkout AutoPay enables merchants to set up UPI recurring payment mandates using PhonePe's **hosted checkout page**. Customers authorize the mandate once through PhonePe's UI; all future deductions happen automatically.

> **Key distinction from Custom Checkout AutoPay:**
> Standard Checkout AutoPay uses PhonePe's hosted payment page — merchants do NOT specify a `paymentMode`, and the flow type is `SUBSCRIPTION_CHECKOUT_SETUP` (not `SUBSCRIPTION_SETUP`). All subscription management endpoints are under `/checkout/v2/subscriptions/` (not `/subscriptions/v2/`).

---

## **AutoPay Lifecycle**

```
Phase 1 — Setup (One-time, customer authorizes mandate on PhonePe's hosted page)
──────────────────────────────────────────────────────────────────────────────────
1. AUTOPAY_SC_SETUP       → POST /checkout/v2/pay → get redirectUrl
2. LAUNCH_PAYMENT_PAGE    → Open redirectUrl via PhonePe JS SDK
3. Customer authorizes mandate on PhonePe's page
4. PhonePe redirects to merchantUrls.redirectUrl
5. AUTOPAY_SC_ORDER_STATUS → Verify setup state = COMPLETED
6. AUTOPAY_SC_SUBSCRIPTION_STATUS → Confirm subscription state = ACTIVE

Phase 2 — Each Billing Cycle (Automated)
──────────────────────────────────────────
7. AUTOPAY_SC_NOTIFY      → POST /checkout/v2/subscriptions/notify (24h before debit)
8. AUTOPAY_SC_ORDER_STATUS → Confirm NOTIFIED state
9. AUTOPAY_SC_REDEEM      → POST /checkout/v2/subscriptions/redeem
10. AUTOPAY_SC_ORDER_STATUS → Poll until COMPLETED or FAILED

Phase 3 — Subscription Management
───────────────────────────────────
11. AUTOPAY_SC_SUBSCRIPTION_STATUS → Check mandate health
12. AUTOPAY_SC_CANCEL     → POST /checkout/v2/subscriptions/{id}/cancel
    (Pause/Revoke are user-initiated via PSP app — merchant receives webhooks only)
```

---

## **Skill: AUTOPAY_SC_SETUP**

**Description:** Creates a subscription mandate order via Standard Checkout. Returns a `redirectUrl` that must be opened via the PhonePe JS SDK.

---

### **Dependencies**

* **Auth:** [SKILL_AUTH_GENERATE](../SKILL.md#1-authentication-skill-base)
* **Payment Page:** [LAUNCH_PAYMENT_PAGE](../standardCheckoutIntegration/standard_checkout_integration_skill.md#skill-launch_payment_page)

---

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | POST   | `https://api-preprod.phonepe.com/apis/pg-sandbox/checkout/v2/pay` |
| Production  | POST   | `https://api.phonepe.com/apis/pg/checkout/v2/pay` |

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
| `merchantOrderId` | String | **YES** | Unique order ID for this setup transaction | Max 63 chars; alphanumeric, `_`, `-` only |
| `amount` | Long | **YES** | Mandate authorization amount in paisa | PENNY_DROP: must be exactly `200`; TRANSACTION: min `100` |
| `expireAfter` | Long | NO | Order expiry in **seconds** | Min: 300, Max: 3600. ⚠️ This is seconds — NOT epoch ms. Custom Checkout AutoPay uses `expireAt` (epoch milliseconds) instead. |
| `metaInfo` | Object | NO | Merchant metadata returned in callbacks | `udf1–udf10`: max 256 chars; `udf11–udf15`: max 50 chars, alphanumeric + `_ - + @ .` |
| `paymentFlow` | Object | **YES** | Subscription setup configuration | — |

#### **`paymentFlow` Fields**

| Field | Type | Required | Description | Values |
|-------|------|----------|-------------|--------|
| `type` | String | **YES** | Flow type | Must be `"SUBSCRIPTION_CHECKOUT_SETUP"` |
| `merchantUrls` | Object | **YES** | Callback URLs | — |
| `merchantUrls.redirectUrl` | String | **YES** | URL PhonePe redirects to after authorization | Must be HTTPS |
| `subscriptionDetails` | Object | **YES** | Mandate parameters | See below |

#### **`paymentFlow.subscriptionDetails` Fields**

| Field | Type | Required | Description | Values / Constraints |
|-------|------|----------|-------------|----------------------|
| `subscriptionType` | String | **YES** | Type of subscription | Must be `"RECURRING"` |
| `merchantSubscriptionId` | String | **YES** | Merchant's unique subscription ID | Max 63 chars |
| `authWorkflowType` | String | **YES** | Mandate verification method | `"TRANSACTION"` or `"PENNY_DROP"` |
| `amountType` | String | **YES** | Fixed or variable deduction | `"FIXED"` or `"VARIABLE"` |
| `maxAmount` | Long | **YES** | Max deductible per cycle (paisa) | Max: 1,500,000 paisa (₹15,000) |
| `frequency` | String | **YES** | Billing frequency | See table below |
| `productType` | String | **YES** | Mandate instrument type | Must be `"UPI_MANDATE"` |
| `expireAt` | epoch ms | NO | Subscription mandate expiry | Max: 30 years from now |

#### **`authWorkflowType` Options**

| Value | Description | Amount Constraint |
|-------|-------------|-------------------|
| `PENNY_DROP` | PhonePe debits ₹2 to verify UPI; amount is reversed | `amount` must be exactly `200` (₹2) |
| `TRANSACTION` | The `amount` in request is first debit + authorization | `amount` >= `100` |

#### **Frequency Options**

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
| `ON_DEMAND` | Merchant controls timing of each cycle |

---

### **Sample Request**

```json
{
    "merchantOrderId": "SC-SETUP-ORD-001",
    "amount": 200,
    "expireAfter": 1800,
    "paymentFlow": {
        "type": "SUBSCRIPTION_CHECKOUT_SETUP",
        "merchantUrls": {
            "redirectUrl": "https://merchant.com/subscription/callback"
        },
        "subscriptionDetails": {
            "subscriptionType": "RECURRING",
            "merchantSubscriptionId": "SUB-CUST-001-MONTHLY",
            "authWorkflowType": "PENNY_DROP",
            "amountType": "FIXED",
            "maxAmount": 49900,
            "frequency": "MONTHLY",
            "productType": "UPI_MANDATE",
            "expireAt": 1767225600000
        }
    }
}
```

### **Sample Response**

```json
{
    "orderId": "OMO123456789",
    "state": "PENDING",
    "expireAt": 1703756259307,
    "redirectUrl": "https://mercury-uat.phonepe.com/transact/pgv2?token=..."
}
```

---

### **Launching the Hosted Page**

Use the PhonePe JS SDK to open `redirectUrl` — **do NOT redirect the browser directly**. See [LAUNCH_PAYMENT_PAGE](../standardCheckoutIntegration/standard_checkout_integration_skill.md#skill-launch_payment_page) for the full SDK integration.

> ⚠️ **PhonePe validates the referrer header.** Direct navigation or server-side redirects will fail. The JS SDK sets the correct referrer automatically.

---

### **Error Handling**

| HTTP Code | Error Code | Cause | Action |
|-----------|------------|-------|--------|
| 400 | BAD_REQUEST | Missing or invalid field | Validate `subscriptionDetails` completeness |
| 401 | AUTHORIZATION_FAILED | Token expired | Refresh via `SKILL_AUTH_GENERATE`, retry |
| 417 | INVALID_TRANSACTION_ID | `merchantOrderId` already used | Generate a new unique ID |
| 500 | INTERNAL_SERVER_ERROR | Server error | Retry with backoff |

### **Implementation Checklist for AI**

- [ ] Call `SKILL_AUTH_GENERATE` to get `access_token`
- [ ] Set `paymentFlow.type = "SUBSCRIPTION_CHECKOUT_SETUP"` — different from Custom Checkout AutoPay
- [ ] Use `paymentFlow.subscriptionDetails` object — NOT flat fields at `paymentFlow` level
- [ ] Set `productType = "UPI_MANDATE"` and `subscriptionType = "RECURRING"` (both required)
- [ ] For PENNY_DROP: set `amount = 200` exactly; for TRANSACTION: set `amount` to first debit amount
- [ ] Set `maxAmount` to the ceiling of what any single cycle will ever charge (max ₹15,000)
- [ ] Provide `merchantUrls.redirectUrl` — required for hosted page callback
- [ ] Open `redirectUrl` using PhonePe JS SDK — inform merchant direct navigation will fail
- [ ] Call `AUTOPAY_SC_ORDER_STATUS` after redirect to verify `state = COMPLETED`
- [ ] Call `AUTOPAY_SC_SUBSCRIPTION_STATUS` to confirm subscription `state = ACTIVE` before first redeem

---

## **Skill: AUTOPAY_SC_ORDER_STATUS**

**Description:** Checks the status of a subscription setup order or a redemption order by `merchantOrderId`. Used after setup and after each redeem.

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | GET    | `https://api-preprod.phonepe.com/apis/pg-sandbox/checkout/v2/order/{merchantOrderId}/status` |
| Production  | GET    | `https://api.phonepe.com/apis/pg/checkout/v2/order/{merchantOrderId}/status` |

### **Setup Order States**

| State | Meaning | Action |
|-------|---------|--------|
| `COMPLETED` | Mandate authorized | Proceed; call `AUTOPAY_SC_SUBSCRIPTION_STATUS` |
| `PENDING` | Awaiting customer action | Poll every 5–10s |
| `FAILED` | Authorization failed | Check `errorCode`; retry setup with new `merchantOrderId` |

### **Redemption Order States**

| State | Meaning | Action |
|-------|---------|--------|
| `NOTIFICATION_IN_PROGRESS` | Notify sent, processing | Poll |
| `NOTIFIED` | Customer notified | Proceed to `AUTOPAY_SC_REDEEM` |
| `COMPLETED` | Deduction successful | Update records |
| `FAILED` | Deduction failed | Check `errorCode`; retry per strategy |
| `PENDING` | Redeem in progress | Poll |

---

## **Skill: AUTOPAY_SC_SUBSCRIPTION_STATUS**

**Description:** Checks the current state of the subscription mandate (not a specific order).

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | GET    | `https://api-preprod.phonepe.com/apis/pg-sandbox/checkout/v2/subscriptions/{merchantSubscriptionId}/status` |
| Production  | GET    | `https://api.phonepe.com/apis/pg/checkout/v2/subscriptions/{merchantSubscriptionId}/status` |

### **Sample Response**

```json
{
    "merchantSubscriptionId": "SUB-CUST-001-MONTHLY",
    "subscriptionId": "OMS2602061522174978849048",
    "state": "ACTIVE",
    "authWorkflowType": "TRANSACTION",
    "amountType": "FIXED",
    "currency": "INR",
    "maxAmount": 49900,
    "frequency": "ON_DEMAND",
    "expireAt": 2717056337500,
    "pauseStartDate": null,
    "pauseEndDate": null
}
```

### **Subscription States**

| State | Meaning | Action |
|-------|---------|--------|
| `ACTIVE` | Mandate live; deductions can proceed | Proceed with Notify → Redeem |
| `PENDING` | Awaiting customer authorization | Wait; poll order status |
| `PAUSED` | User paused via PSP app | Do NOT attempt redemption; wait for webhook |
| `REVOKED` | User removed mandate via PSP app | Subscription is terminated |
| `CANCELLED` | Merchant cancelled | No further deductions possible |
| `EXPIRED` | Past `expireAt` | Create new subscription |

> ⚠️ **Always check subscription state is `ACTIVE` before calling Notify or Redeem.**

---

## **AutoPay Recurring Debit Standards**

> These rules apply to **every billing cycle** after a successful mandate setup. Violating the Notify → 24h gap → Redeem sequence will result in API errors or regulatory failures.

### Rule 1 — Notify before every debit (mandatory)

For every new billing cycle, regardless of `frequency`, the customer **must be notified** via `AUTOPAY_SC_NOTIFY` before any deduction is executed. This is a regulatory requirement under UPI AutoPay guidelines. You cannot call `AUTOPAY_SC_REDEEM` without a preceding successful `AUTOPAY_SC_NOTIFY` for the same `merchantOrderId`.

### Rule 2 — Mandatory 24-hour gap between Notify and Redeem

After a successful `AUTOPAY_SC_NOTIFY` (confirmed by `AUTOPAY_SC_ORDER_STATUS` returning `NOTIFIED`), you must wait **at least 24 hours** before calling `AUTOPAY_SC_REDEEM`. This window allows the customer to be informed of the upcoming debit in advance.

```
Timeline for each billing cycle:

  Day N, 10:00 AM  →  AUTOPAY_SC_NOTIFY called
  Day N, 10:00 AM  →  Poll AUTOPAY_SC_ORDER_STATUS until state = NOTIFIED
  Day N+1, 10:00 AM+  →  AUTOPAY_SC_REDEEM called  (≥24 hours after Notify)
  Day N+1, 10:00 AM+  →  Poll AUTOPAY_SC_ORDER_STATUS until COMPLETED or FAILED
```

### Rule 3 — Verify subscription is ACTIVE before each cycle

Before calling `AUTOPAY_SC_NOTIFY` or `AUTOPAY_SC_REDEEM`, always call `AUTOPAY_SC_SUBSCRIPTION_STATUS` to confirm the subscription `state = ACTIVE`. Do not proceed if the subscription is `PAUSED`, `REVOKED`, `CANCELLED`, or `EXPIRED`.

### Rule 4 — New `merchantOrderId` per cycle

Each billing cycle must use a **fresh, unique `merchantOrderId`**. The same `merchantOrderId` used in Notify must be passed to Redeem. Never reuse a `merchantOrderId` across cycles.

### Rule 5 — Frequency cycle enforcement

Merchants are responsible for scheduling cycles according to the `frequency` agreed during setup:

| Frequency | Merchant's responsibility |
|-----------|--------------------------|
| `DAILY` | Trigger Notify + Redeem every day (respecting 24h gap) |
| `WEEKLY` | Trigger Notify + Redeem once per week |
| `MONTHLY` | Trigger Notify + Redeem once per month |
| `ON_DEMAND` | Trigger Notify + Redeem whenever a debit is needed (no fixed schedule) |
| Others | Trigger per the agreed interval |

PhonePe does not auto-schedule redemptions — the merchant's backend is responsible for initiating each cycle.

### Summary — Per-Cycle Mandatory Sequence

```
1. Check AUTOPAY_SC_SUBSCRIPTION_STATUS → must be ACTIVE
2. Call AUTOPAY_SC_NOTIFY (with new merchantOrderId + amount for this cycle)
3. Poll AUTOPAY_SC_ORDER_STATUS → wait for NOTIFIED
4. Wait ≥ 24 hours
5. Call AUTOPAY_SC_REDEEM (same merchantOrderId as Notify)
6. Poll AUTOPAY_SC_ORDER_STATUS → COMPLETED or FAILED
```

---

## **Skill: AUTOPAY_SC_NOTIFY**

**Description:** Notifies the customer of an upcoming deduction. **Must be called at least 24 hours before the scheduled debit.** Mandatory prerequisite before every `AUTOPAY_SC_REDEEM`.

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | POST   | `https://api-preprod.phonepe.com/apis/pg-sandbox/checkout/v2/subscriptions/notify` |
| Production  | POST   | `https://api.phonepe.com/apis/pg/checkout/v2/subscriptions/notify` |

### **Request Fields**

| Field | Type | Required | Description | Values |
|-------|------|----------|-------------|--------|
| `merchantOrderId` | String | **YES** | Unique order ID for this billing cycle | Max 63 chars; `_`, `-` only special chars |
| `amount` | Long | **YES** | Deduction amount in paisa | Min: 1 |
| `paymentFlow.type` | String | **YES** | Flow type | Must be `"SUBSCRIPTION_CHECKOUT_REDEMPTION"` |
| `paymentFlow.merchantSubscriptionId` | String | **YES** | Subscription ID from setup | — |
| `paymentFlow.redemptionRetryStrategy` | String | NO | Retry behavior | `"STANDARD"` (default) or `"CUSTOM"` |
| `paymentFlow.autoDebit` | Boolean | NO | If `true`, PhonePe automatically executes the debit after 24 hours — merchant does **not** call `AUTOPAY_SC_REDEEM`. If `false` (default), merchant must call `AUTOPAY_SC_REDEEM` explicitly. | Default: `false` |

#### **`autoDebit` — Two Execution Paths**

| `autoDebit` | Who calls Redeem? | Merchant action after Notify |
|-------------|-------------------|------------------------------|
| `false` (default) | **Merchant** calls `AUTOPAY_SC_REDEEM` explicitly after ≥24h | Wait 24h → call `AUTOPAY_SC_REDEEM` → poll `AUTOPAY_SC_ORDER_STATUS` |
| `true` | **PhonePe** auto-executes after ≥24h from successful notification | Do NOT call `AUTOPAY_SC_REDEEM`; poll `AUTOPAY_SC_ORDER_STATUS` or wait for S2S callback for terminal state |

> ⚠️ If `autoDebit = true` and you also call `AUTOPAY_SC_REDEEM`, the manual call will be rejected.

#### **`redemptionRetryStrategy` Details**

| Value | Behavior | Retry Window |
|-------|----------|--------------|
| `STANDARD` | PhonePe manages all retries automatically | Max 48 hours |
| `CUSTOM` | Merchant retries manually; 1 attempt + 3 retries max | Max 48 hours |

> ⚠️ **Retry timing:** All retries must occur during **non-peak hours only**: 9:31 PM–9:59 AM and 1:01 PM–4:59 PM IST. Retries must be separated by at least 1.5 hours.

### **Sample Request**

```json
{
    "merchantOrderId": "CYCLE-ORD-JAN-001",
    "amount": 47900,
    "paymentFlow": {
        "type": "SUBSCRIPTION_CHECKOUT_REDEMPTION",
        "merchantSubscriptionId": "SUB-CUST-001-MONTHLY",
        "redemptionRetryStrategy": "STANDARD",
        "autoDebit": false
    }
}
```

### **Sample Response**

```json
{
    "orderId": "OMO2603101528244777924698BW",
    "state": "NOTIFICATION_IN_PROGRESS",
    "expireAt": 1773309503656
}
```

### **Implementation Checklist for AI**

- [ ] Verify `AUTOPAY_SC_SUBSCRIPTION_STATUS` returns `state = ACTIVE` before calling Notify
- [ ] Generate a **new unique** `merchantOrderId` for each billing cycle
- [ ] Set `paymentFlow.type = "SUBSCRIPTION_CHECKOUT_REDEMPTION"` — NOT `"SUBSCRIPTION_CHECKOUT_SETUP"`
- [ ] Call Notify **at least 24 hours before** the scheduled debit (mandatory regulatory requirement)
- [ ] Call `AUTOPAY_SC_ORDER_STATUS` after Notify to confirm state reaches `NOTIFIED`
- [ ] If `autoDebit = true`: do **not** call `AUTOPAY_SC_REDEEM` — PhonePe executes after 24h; poll `AUTOPAY_SC_ORDER_STATUS` or wait for S2S callback
- [ ] If `autoDebit = false`: wait ≥24h after `NOTIFIED`, then call `AUTOPAY_SC_REDEEM`

---

## **Skill: AUTOPAY_SC_REDEEM**

**Description:** Executes the actual deduction for a billing cycle. Must be called after `AUTOPAY_SC_NOTIFY` confirms `NOTIFIED` state, and **only when `autoDebit = false`** in the Notify request. If `autoDebit = true`, skip this skill — PhonePe automatically executes the debit after 24 hours and will reject a manual Redeem call.

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | POST   | `https://api-preprod.phonepe.com/apis/pg-sandbox/checkout/v2/subscriptions/redeem` |
| Production  | POST   | `https://api.phonepe.com/apis/pg/checkout/v2/subscriptions/redeem` |

### **Request Fields**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `merchantOrderId` | String | **YES** | Same `merchantOrderId` used in the Notify call |

### **Sample Request**

```json
{
    "merchantOrderId": "CYCLE-ORD-JAN-001"
}
```

### **Sample Response**

```json
{
    "transactionId": "OM2603101539420517924712BW",
    "state": "PENDING"
}
```

> **Integration Note:** After a successful Redeem call, the initial response returns `PENDING`. A redemption can take **up to 48 hours** to reach a terminal state (`COMPLETED`, `FAILED`, or `EXPIRED`). Poll `AUTOPAY_SC_ORDER_STATUS` periodically or rely on S2S callbacks to detect the final outcome. If `autoDebit = true` was set in Notify, skip calling Redeem entirely — PhonePe handles execution; poll `AUTOPAY_SC_ORDER_STATUS` or wait for an S2S callback.

### **Implementation Checklist for AI**

- [ ] Only call `AUTOPAY_SC_REDEEM` if Notify was sent with `autoDebit = false`
- [ ] If `autoDebit = true`: skip this skill — PhonePe auto-executes after 24h; a manual call will be rejected
- [ ] Use the same `merchantOrderId` from the Notify call
- [ ] Store the returned `transactionId` for reconciliation
- [ ] Poll `AUTOPAY_SC_ORDER_STATUS` or wait for S2S callback to confirm terminal state (`COMPLETED`, `FAILED`, or `EXPIRED`) — can take up to 48 hours

---

## **Skill: AUTOPAY_SC_CANCEL**

**Description:** Permanently cancels a subscription mandate. No further deductions will occur.

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | POST   | `https://api-preprod.phonepe.com/apis/pg-sandbox/checkout/v2/subscriptions/{merchantSubscriptionId}/cancel` |
| Production  | POST   | `https://api.phonepe.com/apis/pg/checkout/v2/subscriptions/{merchantSubscriptionId}/cancel` |

No request body. HTTP **204 No Content** = cancellation successful.

> ⚠️ Cancellation is **permanent** and **merchant-initiated**. Call `AUTOPAY_SC_SUBSCRIPTION_STATUS` to confirm `state = CANCELLED`.

---

## **Webhook Callbacks**

PhonePe sends webhook callbacks for all subscription events. Configure Callback URL + Username + Password in the PhonePe dashboard.

### **Callback Validation**

```
Authorization: SHA256(username:password)
```

Extract the `Authorization` header and validate against your configured credentials.

### **Event Types Reference**

| Event Type | `event` field | When Triggered |
|------------|---------------|----------------|
| Setup succeeded | `checkout.order.completed` | Customer authorized mandate |
| Setup failed | `checkout.order.failed` | Authorization failed |
| Subscription paused | `subscription.paused` | Customer paused via PSP app |
| Subscription unpaused | `subscription.unpaused` | Customer unpaused via PSP app |
| Subscription revoked | `subscription.revoked` | Customer removed mandate via PSP app |
| Subscription cancelled | `subscription.cancelled` | Merchant cancelled |
| Notify succeeded | `subscription.notification.completed` | Notify processed successfully |
| Notify failed | `subscription.notification.failed` | Notify failed |
| Redemption order completed | `subscription.redemption.order.completed` | Redemption order done |
| Redemption order failed | `subscription.redemption.order.failed` | Redemption order failed |
| Redemption transaction completed | `subscription.redemption.transaction.completed` | Individual debit succeeded |
| Redemption transaction failed | `subscription.redemption.transaction.failed` | Individual debit failed |
| Refund accepted | `pg.refund.accepted` | Refund initiated |
| Refund completed | `pg.refund.completed` | Refund successful |
| Refund failed | `pg.refund.failed` | Refund failed |

> ⚠️ **Best Practice:** Use `payload.state` (not `type`) to determine subscription status. The `type` field will be deprecated. Do not use strict deserialization for webhook bodies.

### **Setup Callback Payload Example**

```json
{
    "type": "CHECKOUT_ORDER_COMPLETED",
    "event": "checkout.order.completed",
    "payload": {
        "merchantOrderId": "SC-SETUP-ORD-001",
        "orderId": "OMO2512091216567658772255V",
        "state": "COMPLETED",
        "amount": 200,
        "paymentFlow": {
            "type": "SUBSCRIPTION_CHECKOUT_SETUP",
            "merchantSubscriptionId": "SUB-CUST-001-MONTHLY",
            "authWorkflowType": "PENNY_DROP",
            "amountType": "FIXED",
            "maxAmount": 49900,
            "frequency": "MONTHLY",
            "expireAt": 2711947616753,
            "subscriptionId": "OMS2512091216567538772793V"
        }
    }
}
```

---

## **Pause & Revoke (User-Initiated — Webhook Only)**

Customers can pause or revoke their mandate directly from their PSP app (PhonePe, BHIM, GPay, etc.). The **merchant cannot programmatically pause, unpause, or revoke** — these are user-controlled actions.

| Event | Trigger | State | Merchant Action |
|-------|---------|-------|----------------|
| Paused | User pauses mandate in PSP app | `PAUSED` | Stop scheduling Notify/Redeem; wait for unpause webhook |
| Unpaused | User unpauses mandate in PSP app | `ACTIVE` | Re-send Notify, wait 24h, then Redeem |
| Revoked | User removes mandate in PSP app | `REVOKED` | No further deductions possible; create new subscription if needed |

> ⚠️ **After unpause:** If Notify was already sent before the pause, you must send a **new Notify** and wait 24 hours before executing Redeem.

---

## **Refund**

Use the standard refund endpoint (shared with Standard Checkout one-time payments):

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | POST   | `https://api-preprod.phonepe.com/apis/pg-sandbox/checkout/v2/refund` |
| Production  | POST   | `https://api.phonepe.com/apis/pg/checkout/v2/refund` |

```json
{
    "merchantRefundId": "REFUND-001",
    "originalMerchantOrderId": "CYCLE-ORD-JAN-001",
    "amount": 47900
}
```

---

## **Comparison: Standard Checkout AutoPay vs Custom Checkout AutoPay**

| Aspect | Standard Checkout AutoPay | Custom Checkout AutoPay |
|--------|--------------------------|------------------------|
| Setup endpoint | `/checkout/v2/pay` | `/subscriptions/v2/setup` |
| Setup flow type | `SUBSCRIPTION_CHECKOUT_SETUP` | `SUBSCRIPTION_SETUP` |
| Notify flow type | `SUBSCRIPTION_CHECKOUT_REDEMPTION` | `SUBSCRIPTION_REDEMPTION` |
| Notify endpoint | `/checkout/v2/subscriptions/notify` | `/subscriptions/v2/notify` |
| Redeem endpoint | `/checkout/v2/subscriptions/redeem` | `/subscriptions/v2/redeem` |
| Cancel endpoint | `/checkout/v2/subscriptions/{id}/cancel` → 204 | `/subscriptions/v2/{id}/cancel` → 200 |
| Payload structure | `paymentFlow.subscriptionDetails` (nested) | Flat fields directly in `paymentFlow` |
| Payment method | PhonePe hosted page (JS SDK required) | UPI_INTENT or UPI_COLLECT specified by merchant |
| Order-level expiry field | `expireAfter` (integer, **seconds**) | `expireAt` (epoch **milliseconds**) |
| Notify initial response state | `NOTIFICATION_IN_PROGRESS` | `PENDING` |
| Pause/Revoke | User-initiated only; merchant receives webhooks | Same |
| Best for | Web integrations | Mobile apps, merchant controls full UX |

---

## **Full Integration Checklist for AI**

- [ ] Use `SUBSCRIPTION_CHECKOUT_SETUP` flow type (not `SUBSCRIPTION_SETUP`)
- [ ] Put mandate params inside `paymentFlow.subscriptionDetails` (not flat in `paymentFlow`)
- [ ] Set `productType = "UPI_MANDATE"` and `subscriptionType = "RECURRING"` — both required
- [ ] Inform merchant: PENNY_DROP requires `amount = 200`; TRANSACTION requires `amount = first debit amount`
- [ ] Use PhonePe JS SDK to launch `redirectUrl` — direct navigation will fail referrer validation
- [ ] Verify `AUTOPAY_SC_SUBSCRIPTION_STATUS` = `ACTIVE` before every Notify and Redeem
- [ ] Call Notify **at least 24 hours** before each deduction (regulatory requirement)
- [ ] Use `SUBSCRIPTION_CHECKOUT_REDEMPTION` in Notify request (not `SUBSCRIPTION_CHECKOUT_SETUP`)
- [ ] Skip `AUTOPAY_SC_REDEEM` if Notify was sent with `autoDebit = true`
- [ ] Configure webhook endpoint to receive Pause/Revoke events — merchant cannot initiate these
- [ ] After unpause webhook: send fresh Notify and wait 24h before Redeem
- [ ] All endpoints use `/checkout/v2/subscriptions/` prefix — NOT `/subscriptions/v2/`
