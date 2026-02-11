---
name: phonepe-pg-skill
description: Assist in integrating with PhonePe PG APIs for one time and recurring payments
metadata:
  author: PhonePe
  version: "1.0.0"
---

## When to Apply
Reference these guidelines when:
- Implementing PhonePe PG API integrations in any project
- Debugging issues with calling PhonePe PG APIs
- Initiating new Payment via PhonePe PG
- Initiating autoPay integration via PhonePe PG

# **Payment Gateway Integration Skills**

## **1. Authentication Skill (Base)**

**ID:** SKILL_AUTH_GENERATE

**Description:** Every request made to PhonePe PG APIs require auth token `O-Bearer` which needs to be fetched from ``/v1/oauth/token`` API using the credentials provided by PhonePe PG. every token can be cached and reused until it expires.

#### **logical instruction:** "If current_time >= expires_at - 60 seconds, trigger a new token request.

#### **Environment HTTP Method API**

* Sandbox POST [https://api-preprod.phonepe.com/apis/pg-sandbox/v1/oauth/token](https://api-preprod.phonepe.com/apis/pg-sandbox/v1/oauth/token)  
* Production POST [https://api.phonepe.com/apis/identity-manager/v1/oauth/token](https://api.phonepe.com/apis/identity-manager/v1/oauth/token)
  #### Note: In addition to the Host differences between PROD and SANDBOX, the API paths also vary. Ensure these changes are handled appropriately when switching between the two environments.    

#### **sample request to fetch token**

```
curl --location 'https://api-preprod.phonepe.com/apis/pg-sandbox/v1/oauth/token' \
--header 'Content-Type: application/x-www-form-urlencoded' \
--data-urlencode 'client_id=CLIENT_ID' \
--data-urlencode 'client_version=CLIENT_VERSION' \
--data-urlencode 'client_secret=CLIENT_SECRET' \
--data-urlencode 'grant_type=client_credentials'
```

  #### **sample response**

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

---

## **2. Refund Skill**

**ID:** SKILL_PAYMENT_REFUND

**Description:** Processes a full or partial refund for a successful transaction.

* **Prerequisite:** Call SKILL_AUTH_GENERATE.  
* **API Call:**  
  1. **Endpoint:**   
     Sandbox - POST - [https://api-preprod.phonepe.com/apis/pg-sandbox/payments/v2/refund](https://api-preprod.phonepe.com/apis/pg-sandbox/payments/v2/refund)   
     Production - POST - [https://api.phonepe.com/apis/pg/payments/v2/refund](https://api.phonepe.com/apis/pg/payments/v2/refund)
  2. **Headers:** * Authorization: O-Bearer {{SKILL_AUTH_GENERATE.output.access_token}}  
     * Content-Type: application/json

**Inputs:** merchantRefundId, originalMerchantOrderId, amount  
Sample Request

```json
{
    "merchantRefundId": "Refund-id-12345",
    "originalMerchantOrderId": "Order-12345",
    "amount": 1234
}
```

* **Logic:**  
  1. Prepare a JSON payload mapping user inputs to the PG’s refund schema.  
  2. Include `access_token` in the Authorization Header.  
     Request Headers  
     **Content-Type**: application/json  
     **Authorization**: O-Bearer <`access_token`>  
  3. Handle response codes:  
     * 200/201: Return accepted successfully.  
     * 400/402: Return specific error
     * 401/403: Missing or expired auth token. Refresh the token.
     * 500: Server Unable to process the Request Try again later Or Reach out to PhonePe PG Support for more details

Output: sample response

```json
{
    "refundId": "OMRxxxxx",
    "amount": 1234,
    "state": "PENDING"
}
```

