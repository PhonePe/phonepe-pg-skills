# **Custom Checkout One-Time Payment Integration**

> 🔴 **MERCHANT ENABLEMENT REQUIRED — AI MUST CONFIRM BEFORE PROCEEDING**
>
> **Custom Checkout is not enabled by default for all merchants.** It requires explicit activation and permission grant by the PhonePe team during or after onboarding.
>
> **Before starting any Custom Checkout integration, the AI must ask the merchant:**
> > *"Has your PhonePe account been enabled for Custom Checkout? This flow requires explicit permission from the PhonePe team. If you're unsure, please confirm with your PhonePe account manager or onboarding contact before proceeding."*
>
> Do **not** proceed with integration steps until the merchant confirms that Custom Checkout has been enabled for their account.

Custom Checkout gives merchants full control over the payment UI. Unlike Standard Checkout (which uses PhonePe's hosted page), Custom Checkout lets merchants build their own payment forms and call PhonePe APIs directly for each payment mode.

> ⚠️ **AI MUST inform merchants:** Custom Checkout requires more integration effort than Standard Checkout. For simple web integrations, Standard Checkout is recommended. Choose Custom Checkout only when the merchant needs full UI control.

---

## **Skill: CUSTOM_CHECKOUT_PAY**

**Description:** Initiates a one-time payment using Custom Checkout. The merchant presents their own payment UI and calls this API with the selected payment mode and instrument details.

---

### **Dependencies**

* **Auth Provider:** [SKILL_AUTH_GENERATE](../SKILL.md#1-authentication-skill-base)

---

### **Execution Flow**

1. **Call Dependency:** Call `SKILL_AUTH_GENERATE` to obtain `access_token`
2. **Collect Payment Details:** Merchant UI collects payment mode and instrument details from user
3. **Build Payload:** Construct request with `paymentFlow.type = "PG"` and the selected `paymentMode`
4. **Select Endpoint:** Use standard PG endpoint for UPI/NetBanking; use PCI endpoint for CARD/TOKEN
5. **Make API Call:** POST to the appropriate endpoint
6. **Handle Response:** For UPI_INTENT return `intentUrl`; for UPI_QR return `qrData`; for CARD/NET_BANKING return `redirectUrl`
7. **Verify Payment:** Call `CUSTOM_CHECKOUT_ORDER_STATUS` to confirm final payment state

---

### **API Configuration**

#### **Endpoints**

| Environment | Standard Modes (UPI, NetBanking) | PCI Modes (CARD, TOKEN) |
|-------------|----------------------------------|------------------------|
| Sandbox     | `POST https://api-preprod.phonepe.com/apis/pg-sandbox/payments/v2/pay` | `POST https://api-preprod.phonepe.com/apis/pg-sandbox/payments/v2/pay` |
| Production  | `POST https://api.phonepe.com/apis/pg/payments/v2/pay` | `POST https://cards.phonepe.com/apis/pg/payments/v2/pay` |

> ⚠️ **CARD and TOKEN payment modes must always use the PCI host (`cards.phonepe.com`) in production.** Using the standard host (`api.phonepe.com`) for card payments will fail. Sandbox uses the same host for all payment modes.

#### **Request Headers**

```
Authorization: O-Bearer <access_token>
Content-Type: application/json
```

---

### **Common Request Fields**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `merchantOrderId` | String | **YES** | Unique order identifier | Max 63 chars; alphanumeric, `_`, `-` only |
| `amount` | Long | **YES** | Amount in paisa | Min: 100 |
| `expireAfter` | Long | NO | Order expiry in seconds | Min: 300, Max: 5184000. Default varies by mode (see table) |
| `metaInfo` | Object | NO | Merchant metadata (returned in status/callback) | Do not rename `udf*` keys |
| `metaInfo.udf1–udf10` | String | NO | Free-form metadata | Max 256 chars each |
| `metaInfo.udf11–udf15` | String | NO | Restricted metadata | Max 50 chars; alphanumeric + `_ - @ . +` only |
| `deviceContext` | Object | NO | Device info — required for UPI_INTENT | — |
| `deviceContext.deviceOS` | String | YES (for UPI_INTENT) | Device operating system | `ANDROID` or `IOS` |
| `deviceContext.merchantCallBackScheme` | String | YES (iOS UPI_INTENT with PHONEPE targetApp) | iOS deep-link scheme for redirect back | Alphanumeric, `.`, `-` only; must start with a letter |
| `paymentFlow` | Object | **YES** | Payment flow configuration | — |
| `paymentFlow.type` | String | **YES** | Payment flow type | Must be `"PG"` |
| `paymentFlow.paymentMode` | Object | **YES** | Payment mode and instrument details | See per-mode tables below |
| `paymentFlow.merchantUrls.redirectUrl` | String | YES (NET_BANKING, CARD, TOKEN) | Post-payment redirect URL | Valid HTTPS URL |

**Default `expireAfter` values by payment mode:**
| Mode | Default (seconds) |
|------|-------------------|
| UPI_INTENT | 600 |
| UPI_QR | 480 |
| UPI_COLLECT | 480 |
| CARD | 720 |
| NET_BANKING | 480 |

---

### **Payment Mode: UPI_INTENT**

Launches a UPI app installed on the user's device to complete payment.

#### **paymentMode Fields**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| `type` | String | **YES** | Payment mode | Must be `"UPI_INTENT"` |
| `targetApp` | String | **YES** | UPI app to open | Android: package name (e.g. `com.phonepe.app`). iOS: `PHONEPE`, `GPAY`, `PAYTM`, `CRED`, `SUPERMONEY`, `BHIM`, `AMAZON` |

> ⚠️ `deviceContext.deviceOS` is **required** for UPI_INTENT.
> For iOS with `targetApp = PHONEPE`, `deviceContext.merchantCallBackScheme` is also required.

#### **Android Example**

```json
{
    "merchantOrderId": "TX123456",
    "amount": 1000,
    "deviceContext": {
        "deviceOS": "ANDROID"
    },
    "paymentFlow": {
        "type": "PG",
        "paymentMode": {
            "type": "UPI_INTENT",
            "targetApp": "com.phonepe.app"
        }
    }
}
```

#### **iOS Example**

```json
{
    "merchantOrderId": "TX123456",
    "amount": 1000,
    "deviceContext": {
        "deviceOS": "IOS",
        "merchantCallBackScheme": "mymerchantapp"
    },
    "paymentFlow": {
        "type": "PG",
        "paymentMode": {
            "type": "UPI_INTENT",
            "targetApp": "PHONEPE"
        }
    }
}
```

#### **Success Response**

```json
{
    "orderId": "OMO123456789",
    "state": "PENDING",
    "expireAt": 1703756259307,
    "intentUrl": "ppe://transact?pa=merchant@phonepe&pn=Merchant&am=10.00&tr=TX123456&tn=Payment"
}
```

| Field | Description |
|-------|-------------|
| `orderId` | PhonePe internal order ID |
| `state` | Always `PENDING` on initiation |
| `expireAt` | Order expiry (epoch milliseconds) |
| `intentUrl` | Deep-link URL to open the UPI app |

> **Integration Note:** On Android, open `intentUrl` via an Intent. On iOS, open it via `UIApplication.open()`. After the user completes payment in the UPI app, they are returned to the app via `merchantCallBackScheme`. Then call `CUSTOM_CHECKOUT_ORDER_STATUS` to verify the outcome.

---

### **Payment Mode: UPI_COLLECT**

Sends a collect request (payment request) to the user's UPI ID (VPA) or mobile number.

#### **paymentMode Fields**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | String | **YES** | Must be `"UPI_COLLECT"` |
| `details.type` | String | **YES** | Collect target: `"VPA"` or `"PHONE_NUMBER"` |
| `details.vpa` | String | YES (if `details.type = "VPA"`) | User's UPI VPA e.g. `user@ybl` |
| `details.phoneNumber` | String | YES (if `details.type = "PHONE_NUMBER"`) | User's registered UPI mobile number |
| `message` | String | NO | Message shown in the collect request |

#### **Example — Collect via VPA**

```json
{
    "merchantOrderId": "TX123456",
    "amount": 1000,
    "paymentFlow": {
        "type": "PG",
        "paymentMode": {
            "type": "UPI_COLLECT",
            "details": {
                "type": "VPA",
                "vpa": "user@ybl"
            },
            "message": "Payment for order TX123456"
        }
    }
}
```

#### **Example — Collect via Phone Number**

```json
{
    "merchantOrderId": "TX123456",
    "amount": 1000,
    "paymentFlow": {
        "type": "PG",
        "paymentMode": {
            "type": "UPI_COLLECT",
            "details": {
                "type": "PHONE_NUMBER",
                "phoneNumber": "9999999999"
            }
        }
    }
}
```

#### **Success Response**

```json
{
    "orderId": "OMO123456789",
    "state": "PENDING",
    "expireAt": 1703756259307
}
```

> **Integration Note:** A collect request is sent to the user's UPI app. The user must approve it. Poll `CUSTOM_CHECKOUT_ORDER_STATUS` until `state` is `COMPLETED` or `FAILED`.

---

### **Payment Mode: UPI_QR**

Generates a QR code for the user to scan with any UPI-enabled app.

#### **paymentMode Fields**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | String | **YES** | Must be `"UPI_QR"` |

#### **Example**

```json
{
    "merchantOrderId": "TX123456",
    "amount": 1000,
    "paymentFlow": {
        "type": "PG",
        "paymentMode": {
            "type": "UPI_QR"
        }
    }
}
```

#### **Success Response**

```json
{
    "orderId": "OMO123456789",
    "state": "PENDING",
    "expireAt": 1703756259307,
    "intentUrl": "upi://pay?pa=...",
    "qrData": "data:image/png;base64,..."
}
```

| Field | Description |
|-------|-------------|
| `intentUrl` | UPI deep-link (can also encode as QR) |
| `qrData` | Base64-encoded QR image ready to display |

---

### **Payment Mode: NET_BANKING**

Redirects the user to their bank's net banking portal.

#### **paymentMode Fields**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | String | **YES** | Must be `"NET_BANKING"` |
| `bankId` | String | **YES** | Bank identifier code provided by PhonePe |
| `merchantUserId` | String | NO | Merchant's internal user ID for tracking |

#### **Supported Bank IDs**

> ⚠️ **HDFC Bank and State Bank of India (SBI)** require explicit enablement during merchant onboarding. Merchants must confirm with the PhonePe team whether these banks are activated for their account before using them.

| Bank ID | Bank Name |
|---------|-----------|
| `ICIC` | ICICI Bank |
| `HDFC` | HDFC Bank ⚠️ |
| `UTIB` | Axis Bank |
| `IBKL` | IDBI Bank |
| `TMBL` | Tamilnad Mercantile Bank |
| `FDRL` | Federal Bank |
| `CIUB` | City Union Bank |
| `IDIB` | Indian Bank |
| `KVBL` | Karur Vysya Bank |
| `KARB` | Karnataka Bank |
| `IOBA` | Indian Overseas Bank |
| `SIBL` | South Indian Bank |
| `BARB` | Bank of Baroda |
| `YESB` | Yes Bank |
| `UBIN` | Union Bank of India |
| `BKID` | Bank of India |
| `DEUT` | Deutsche Bank |
| `JAKA` | Jammu and Kashmir Bank |
| `DLXB` | Dhanlaxmi Bank |
| `SCBL` | Standard Chartered Bank |
| `DCBL` | DCB Bank Personal |
| `CBIN` | Central Bank of India |
| `MAHB` | Bank of Maharashtra |
| `INDB` | IndusInd Bank |
| `KKBK` | Kotak Mahindra Bank |
| `CNRB` | Canara Bank |
| `CSBK` | CSB Bank Ltd |
| `PUNB` | Punjab National Bank |
| `RATN` | RBL Bank Limited |
| `SVCB` | SVC Cooperative Bank Ltd |
| `IDFB` | IDFC First Bank |
| `PSIB` | Punjab and Sind Bank |
| `AIRP` | Airtel Payments Bank |
| `AUBL` | AU Small Finance Bank Limited |
| `BDBL` | Bandhan Bank |
| `COSB` | Cosmos Bank |
| `ESFB` | Equitas Bank |
| `JSFB` | Jana Small Finance Bank |
| `JSBP` | Janata Sahakari Bank Ltd Pune |
| `NKGS` | NKGSB Co-op Bank Ltd |
| `SRCB` | Saraswat Bank – Retail |
| `SBIN` | State Bank of India ⚠️ |
| `SURY` | Suryoday Small Finance Bank Ltd |
| `UCBA` | UCO Bank |
| `UJVN` | Ujjivan Small Finance Bank |
| `APGB` | Andhra Pragathi Grameena Bank |
| `BBKM` | Bank of Bahrain and Kuwait |
| `BCCB` | Bassein Catholic Coop Bank |
| `DBSS` | Digibank by DBS |
| `ESMF` | ESAF Small Finance Bank |
| `FSFB` | Fincare Bank |
| `KJSB` | Kalyan Janata Sahakari Bank |
| `PKGB` | Karnataka Gramin Bank |
| `KVGB` | Karnataka Vikas Grameena Bank |
| `MSNU` | Mehsana Urban Coop Bank |
| `TJSB` | TJSB Bank |
| `ZCBL` | Zoroastrian Cooperative Bank Ltd |
| `OTHERS` | Capital Small Finance Bank, Lakshmi Vilas Bank, Nainital Bank, Royal Bank of Scotland |

#### **Example**

```json
{
    "merchantOrderId": "TX123456",
    "amount": 1000,
    "paymentFlow": {
        "type": "PG",
        "paymentMode": {
            "type": "NET_BANKING",
            "bankId": "HDFC",
            "merchantUserId": "USER_001"
        },
        "merchantUrls": {
            "redirectUrl": "https://yoursite.com/payment/callback"
        }
    }
}
```

#### **Success Response**

```json
{
    "orderId": "OMO123456789",
    "state": "PENDING",
    "expireAt": 1703756259307,
    "redirectUrl": "https://netbanking.hdfc.com/..."
}
```

> **Integration Note:** Redirect the user to `redirectUrl`. After banking, they return to `merchantUrls.redirectUrl`. Call `CUSTOM_CHECKOUT_ORDER_STATUS` to verify.

---

### **Card Data Encryption**

> ⚠️ **PCI-DSS Compliance Required.** Sensitive card fields (`cardNumber`, `cvv`, `token`) must be encrypted **before** being sent in the request. PhonePe provides each merchant with a unique RSA public key and key index during onboarding.

#### **Encryption Details**

| Property | Value |
|----------|-------|
| Algorithm | RSA |
| Padding | PKCS1v15 |
| Key format | PEM-encoded RSA public key (`cardEncryptionKey`) — provided by PhonePe during onboarding |
| Key index | Integer (`cardEncryptionKeyIndex`) — provided by PhonePe during onboarding; sent as `encryptionKeyId` in the request |
| Output format | Base64-encoded string |

#### **Encryption Reference (Python)**

```python
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
import base64

def encrypt(data: str, public_key_pem: str) -> str:
    """Encrypt sensitive card data using merchant's RSA public key from PhonePe onboarding."""
    public_key = serialization.load_pem_public_key(
        public_key_pem.encode(),
        backend=default_backend()
    )
    encrypted = public_key.encrypt(data.encode(), padding.PKCS1v15())
    return base64.b64encode(encrypted).decode()

# Usage
encrypted_card_number = encrypt(card_number, merchant_card_encryption_key)
encrypted_cvv         = encrypt(cvv,         merchant_card_encryption_key)
```

> ⚠️ The `cardEncryptionKey` (PEM public key) and `cardEncryptionKeyIndex` are **merchant-specific** credentials issued by PhonePe at onboarding. Do not share or hardcode these values.

---

### **Payment Mode: CARD**

> ⚠️ **PCI-DSS Compliance Required.** Encrypt `cardNumber` and `cvv` using the merchant's PhonePe-issued RSA key (see [Card Data Encryption](#card-data-encryption) above) before sending. In **production**, use `https://cards.phonepe.com/apis/pg/payments/v2/pay` (not `api.phonepe.com`). Sandbox uses the standard host.

#### **paymentMode Fields**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | String | **YES** | Must be `"CARD"` |
| `authMode` | String | **YES** | Must be `"3DS"` |
| `cardDetails.encryptedCardNumber` | String | **YES** | RSA+PKCS1v15 encrypted card number, base64-encoded (use `cardEncryptionKey` from onboarding) |
| `cardDetails.encryptionKeyId` | Long | **YES** | `cardEncryptionKeyIndex` provided by PhonePe during onboarding |
| `cardDetails.cardHolderName` | String | NO | Cardholder name |
| `cardDetails.expiry.month` | String | **YES** | Card expiry month (2 digits, e.g. `"12"`) |
| `cardDetails.expiry.year` | String | **YES** | Card expiry year (4 digits, e.g. `"2029"`) |
| `cardDetails.encryptedCvv` | String | **YES** | RSA+PKCS1v15 encrypted CVV, base64-encoded (use `cardEncryptionKey` from onboarding) |
| `merchantUserId` | String | NO | Merchant's user ID |

#### **Example** *(Production: use `https://cards.phonepe.com/apis/pg/payments/v2/pay`)*

```json
{
    "merchantOrderId": "TX123456",
    "amount": 1000,
    "paymentFlow": {
        "type": "PG",
        "paymentMode": {
            "type": "CARD",
            "authMode": "3DS",
            "cardDetails": {
                "encryptedCardNumber": "<encrypt(cardNumber, cardEncryptionKey)>",
                "encryptionKeyId": "<cardEncryptionKeyIndex>",
                "cardHolderName": "John Doe",
                "expiry": {
                    "month": "12",
                    "year": "2029"
                },
                "encryptedCvv": "<encrypt(cvv, cardEncryptionKey)>"
            },
            "merchantUserId": "USER_001"
        },
        "merchantUrls": {
            "redirectUrl": "https://yoursite.com/payment/callback"
        }
    }
}
```

#### **Success Response**

```json
{
    "orderId": "OMO123456789",
    "state": "PENDING",
    "expireAt": 1703756259307,
    "redirectUrl": "https://3ds.bank.com/authenticate?..."
}
```

---

### **Payment Mode: TOKEN (Saved Card)**

> ⚠️ Requires PCI-DSS compliance. Token is a previously saved/tokenized card. Encrypt `token` and `cvv` using the merchant's PhonePe-issued RSA key (see [Card Data Encryption](#card-data-encryption) above). In **production**, use `https://cards.phonepe.com/apis/pg/payments/v2/pay`. Sandbox uses the standard host.

#### **paymentMode Fields**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | String | **YES** | Must be `"TOKEN"` |
| `authMode` | String | **YES** | Must be `"3DS"` |
| `tokenDetails.encryptedToken` | String | **YES** | RSA+PKCS1v15 encrypted card token, base64-encoded (use `cardEncryptionKey` from onboarding) |
| `tokenDetails.encryptionKeyId` | Long | **YES** | `cardEncryptionKeyIndex` provided by PhonePe during onboarding |
| `tokenDetails.encryptedCvv` | String | NO | RSA+PKCS1v15 encrypted CVV, base64-encoded (if required) |
| `tokenDetails.expiry.month` | String | **YES** | Token expiry month |
| `tokenDetails.expiry.year` | String | **YES** | Token expiry year |
| `tokenDetails.cryptogram` | String | NO | Cryptogram (for network tokens) |
| `tokenDetails.panSuffix` | String | NO | Last 4 digits of the card |
| `tokenDetails.cardHolderName` | String | NO | Cardholder name |
| `merchantUserId` | String | NO | Merchant's user ID |

### **Sample Request (TOKEN)**

```json
{
    "merchantOrderId": "CC-ORD-TOKEN-001",
    "amount": 49900,
    "paymentFlow": {
        "type": "PG",
        "merchantUrls": {
            "redirectUrl": "https://merchant.example.com/payment/callback"
        },
        "paymentMode": {
            "type": "TOKEN",
            "authMode": "3DS",
            "tokenDetails": {
                "encryptedToken": "<encrypt(token, cardEncryptionKey)>",
                "encryptionKeyId": "<cardEncryptionKeyIndex>",
                "encryptedCvv": "<encrypt(cvv, cardEncryptionKey)>",
                "expiry": {
                    "month": "12",
                    "year": "2028"
                },
                "panSuffix": "1234",
                "cardHolderName": "John Doe"
            }
        }
    }
}
```

> ⚠️ Send this request to `https://cards.phonepe.com/apis/pg/payments/v2/pay` in production (not `api.phonepe.com`).

---

### **Error Responses**
|-----------|------------|-------------|-----------|
| 400 | BAD_REQUEST | Invalid payload or missing required field | Validate all fields for the selected payment mode |
| 401 | AUTHORIZATION_FAILED | Token expired or invalid | Call `SKILL_AUTH_GENERATE`, retry once |
| 417 | INVALID_TRANSACTION_ID | `merchantOrderId` already used | Generate a new unique `merchantOrderId` |
| 500 | INTERNAL_SERVER_ERROR | Server error | Retry with exponential backoff (2s, 4s, 8s) |

---

### **Implementation Checklist for AI**

- [ ] Call `SKILL_AUTH_GENERATE` first to get `access_token`
- [ ] Set `paymentFlow.type = "PG"` (not `"PG_CHECKOUT"` — that is Standard Checkout)
- [ ] For `UPI_INTENT`: include `deviceContext.deviceOS`; for iOS + PhonePe app, also include `merchantCallBackScheme`
- [ ] For `NET_BANKING`, `CARD`, `TOKEN`: include `paymentFlow.merchantUrls.redirectUrl`
- [ ] For `CARD` or `TOKEN` in **production**: use `https://cards.phonepe.com/apis/pg/payments/v2/pay` — never `api.phonepe.com`
- [ ] Encrypt `cardNumber`, `cvv`, and `token` using the merchant's **PhonePe-issued RSA public key** (`cardEncryptionKey`) with **PKCS1v15 padding**, output as **base64** — both the PEM key and key index (`cardEncryptionKeyIndex`) are provided during PhonePe onboarding
- [ ] Do NOT rename `metaInfo.udf*` keys — renamed keys cause production errors
- [ ] After initiation, always call `CUSTOM_CHECKOUT_ORDER_STATUS` to verify the final payment state
- [ ] Inform merchant: Custom Checkout requires more effort than Standard Checkout

---

## **Skill: CUSTOM_CHECKOUT_ORDER_STATUS**

**Description:** Retrieves the status of a Custom Checkout payment order.

### **Dependencies**

* **Auth Provider:** [SKILL_AUTH_GENERATE](../SKILL.md#1-authentication-skill-base)

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | GET    | `https://api-preprod.phonepe.com/apis/pg-sandbox/payments/v2/order/{merchantOrderId}/status` |
| Production  | GET    | `https://api.phonepe.com/apis/pg/payments/v2/order/{merchantOrderId}/status` |

### **Query Parameters**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `details` | Boolean | NO | `false` | `true` → return all payment attempt details |

### **Example**

```bash
GET https://api-preprod.phonepe.com/apis/pg-sandbox/payments/v2/order/TX123456/status?details=true
```

### **Response States**

| State | Meaning | Action |
|-------|---------|--------|
| `COMPLETED` | Payment successful | Fulfill order |
| `PENDING` | Payment in progress | Poll every 5-10s until terminal state or `expireAt` |
| `FAILED` | Payment failed | Show error, allow retry with new `merchantOrderId` |

---

## **Skill: CUSTOM_CHECKOUT_TRANSACTION_STATUS**

**Description:** Retrieves the status of a specific payment transaction attempt by `transactionId`.

### **Dependencies**

* **Auth Provider:** [SKILL_AUTH_GENERATE](../SKILL.md#1-authentication-skill-base)

### **Endpoints**

| Environment | Method | URL |
|-------------|--------|-----|
| Sandbox     | GET    | `https://api-preprod.phonepe.com/apis/pg-sandbox/payments/v2/transaction/{transactionId}/status` |
| Production  | GET    | `https://api.phonepe.com/apis/pg/payments/v2/transaction/{transactionId}/status` |

### **Request Headers**

```
Authorization: O-Bearer <access_token>
```

> Use `CUSTOM_CHECKOUT_ORDER_STATUS` for most use cases. Use this endpoint only when tracking a specific transaction attempt ID.
