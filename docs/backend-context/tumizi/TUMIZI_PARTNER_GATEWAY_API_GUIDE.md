# Tumizi Partner Gateway API Guide

## Purpose

This guide is the current partner-facing contract for Tumizi integrations like DukaNest.

It now supports two distinct operating modes:

1. Merchant mode
   DukaNest onboards merchant customers into Tumizi, collects customer payments for them, withdraws funds for them, and refunds those payments when needed.
2. Partner-self mode
   DukaNest itself has a Tumizi organisation and wallet, can receive payments into that wallet, withdraw from it, and refund those payments.

This separation is intentional. Merchant traffic and partner-owned traffic now use different endpoints so identity, balances, audit history, and webhooks stay clean.

---

## Base URL

```http
{{base_url}}/api/partner/v1
```

Examples:

- `https://your-tumizi-domain.com/api/partner/v1`
- `http://127.0.0.1:8000/api/partner/v1`

---

## Authentication

Every request needs:

```http
Authorization: Bearer <partner_api_key>
Accept: application/json
Content-Type: application/json
```

Recommended:

```http
X-Correlation-Id: dukanest-run-001
```

Tumizi returns:

- `X-Request-Id`
- `X-Correlation-Id`

Use them when tracing a request or webhook.

---

## Integration App Setup In Tumizi

Before using partner-self APIs, the integration app itself must be mapped to a Tumizi organisation and wallet.

Required platform setup:

1. Open `Platform > Integrations`.
2. Create or edit the DukaNest integration app.
3. Set:
   - `System`
   - `Environment`
   - `Tumizi organisation`
   - `Tumizi wallet`
4. Issue an API key with the right scopes.
5. Add a partner-level webhook endpoint.

Merchant onboarding does not need the partner app wallet. Partner-self APIs do.

---

## Scopes

Use the smallest scope set you need. For DukaNest sandbox work, the practical full scope set is:

- `merchants:create`
- `merchants:read`
- `merchants:update`
- `merchants:delete`
- `wallets:read`
- `customer_payments:create`
- `customer_payments:read`
- `withdrawals:create`
- `withdrawals:read`
- `partner_wallet:read`
- `partner_payments:create`
- `partner_payments:read`
- `partner_withdrawals:create`
- `partner_withdrawals:read`
- `refunds:create`
- `refunds:read`
- `webhooks:receive`

Endpoint-to-scope map:

| Endpoint | Scope |
|---|---|
| `POST /merchants` | `merchants:create` |
| `GET /merchants` | `merchants:read` |
| `GET /merchants/{merchantExternalId}` | `merchants:read` |
| `PUT /merchants/{merchantExternalId}` | `merchants:update` |
| `POST /merchants/{merchantExternalId}/activate` | `merchants:update` |
| `DELETE /merchants/{merchantExternalId}` | `merchants:delete` |
| `GET /merchants/{merchantExternalId}/wallet` | `wallets:read` |
| `POST /customer-payments` | `customer_payments:create` |
| `GET /customer-payments/{externalReference}` | `customer_payments:read` |
| `POST /withdrawals` | `withdrawals:create` |
| `GET /withdrawals/{externalReference}` | `withdrawals:read` |
| `POST /refunds` | `refunds:create` |
| `GET /refunds/{externalReference}` | `refunds:read` |
| `GET /me/wallet` | `partner_wallet:read` |
| `POST /me/customer-payments` | `partner_payments:create` |
| `GET /me/customer-payments/{externalReference}` | `partner_payments:read` |
| `POST /me/withdrawals` | `partner_withdrawals:create` |
| `GET /me/withdrawals/{externalReference}` | `partner_withdrawals:read` |
| `POST /me/refunds` | `refunds:create` |
| `GET /me/refunds/{externalReference}` | `refunds:read` |

---

## General Rules

### Merchant external ID

- `merchant_external_id` is partner-defined.
- It must remain stable.
- It is immutable after merchant creation.

### Wallet account numbers

- Partner-created merchant wallet references are uppercase alphanumeric.
- Letters and digits only.
- No spaces.
- No special characters.
- Tumizi normalizes supplied values to uppercase.
- Example valid values:
  - `DUKANEST001`
  - `SHOP42`
  - `BLUEWAVESTORE1`

### Idempotency

- Merchant create, partner payment create, withdrawal create, and refund create all reuse the existing record when the same partner sends the same `external_reference` again.
- Always generate a unique `external_reference` per business event.

### Refund behavior

- Refunds are reference-based.
- The client sends `payment_reference`.
- Tumizi loads the original successful customer payment.
- Tumizi auto-fills:
  - amount
  - currency
  - refund destination phone number
- Current refund flow is full-refund only.
- Tumizi blocks multiple active/full refunds against the same payment reference.

### Error shape

```json
{
  "success": false,
  "code": "validation_error",
  "message": "The request payload is invalid.",
  "errors": {
    "field": [
      "Message"
    ]
  },
  "request_id": "req_xxx"
}
```

Common codes:

- `authentication_failed`
- `insufficient_scope`
- `merchant_not_found`
- `customer_payment_not_found`
- `withdrawal_not_found`
- `refund_not_found`
- `partner_wallet_not_configured`
- `validation_error`

---

## Merchant APIs

### 1. Create merchant

```http
POST /merchants
```

Creates:

- Tumizi organisation
- owner/root user
- merchant wallet
- merchant mapping
- optional merchant-scoped webhooks

Example body:

```json
{
  "merchant_external_id": "dukanest-store-001",
  "merchant": {
    "name": "DukaNest Demo Store",
    "email": "finance@dukanest-store.test",
    "phone": "254700123123",
    "country": "Kenya",
    "domain": "dukanest-store.test",
    "description": "Sandbox merchant"
  },
  "owner": {
    "name": "DukaNest Owner",
    "email": "owner@dukanest-store.test"
  },
  "wallet": {
    "name": "Main Wallet",
    "account_number": "DUKANEST001",
    "currency": "KES"
  },
  "webhooks": [
    {
      "name": "Merchant callback",
      "callback_url": "https://dukanest-store.test/api/tumizi/callback",
      "events": [
        "partner.customer_payment.updated",
        "partner.withdrawal.updated",
        "partner.refund.updated"
      ]
    }
  ]
}
```

### 2. List merchants

```http
GET /merchants?search=dukanest&status=active&per_page=20
```

Supported query params:

- `search`
- `status`
- `per_page`

### 3. Get merchant

```http
GET /merchants/{merchantExternalId}
```

Returns merchant status, owner, organisation, wallet, and merchant-scoped webhooks.

### 4. Update merchant

```http
PUT /merchants/{merchantExternalId}
```

Supports updates for:

- `merchant`
- `owner`
- `wallet`
- `webhooks`
- top-level `status`
- nested `merchant.status`

Example:

```json
{
  "merchant": {
    "status": "active",
    "name": "DukaNest Demo Store Updated"
  },
  "wallet": {
    "account_number": "DUKANEST002"
  }
}
```

### 5. Activate merchant

```http
POST /merchants/{merchantExternalId}/activate
```

Use this when you want an explicit reactivation call instead of updating status in `PUT`.

### 6. Deactivate merchant

```http
DELETE /merchants/{merchantExternalId}
```

Important:

- only the merchant mapping is deactivated
- the linked organisation remains active
- the linked wallet remains active
- existing webhooks remain active

### 7. Get merchant wallet

```http
GET /merchants/{merchantExternalId}/wallet
```

---

## Merchant Customer Payments

### Create customer payment

```http
POST /customer-payments
```

Example:

```json
{
  "merchant_external_id": "dukanest-store-001",
  "external_reference": "dukanest-payment-1001",
  "source": {
    "wallet_account_number": "DUKANEST001"
  },
  "payer": {
    "phone_number": "254700000001",
    "name": "Jane Customer",
    "email": "jane@example.com"
  },
  "amount": 1500,
  "currency": "KES",
  "account_reference": "INV1001",
  "description": "Invoice 1001"
}
```

Result:

- Tumizi initiates STK push
- status becomes `initiated` if Safaricom accepts the request
- webhook event `partner.customer_payment.updated` is dispatched

### Get customer payment

```http
GET /customer-payments/{externalReference}
```

Response includes:

- `scope`
- `merchant_external_id`
- `status`
- `checkout_request_id`
- `mpesa_receipt_number`

---

## Merchant Withdrawals

### Create withdrawal

```http
POST /withdrawals
```

Example:

```json
{
  "merchant_external_id": "dukanest-store-001",
  "external_reference": "dukanest-withdrawal-1001",
  "source": {
    "wallet_account_number": "DUKANEST001"
  },
  "destination": {
    "type": "mpesa",
    "phone_number": "254700000111"
  },
  "payee": {
    "name": "Merchant Cashout"
  },
  "amount": 1800,
  "description": "Merchant cashout"
}
```

Behavior:

- Tumizi creates an internal payout record
- internal human approval is bypassed
- partner-facing flow is direct

### Get withdrawal

```http
GET /withdrawals/{externalReference}
```

Response includes:

- `scope`
- `merchant_external_id`
- `payout_request_id`
- `payout_request_number`
- `status`
- destination details

---

## Partner-Self APIs

Use these when DukaNest itself is the wallet owner in Tumizi.

### 1. Get partner wallet

```http
GET /me/wallet
```

If the integration app has no active organisation and wallet configured, Tumizi returns `partner_wallet_not_configured`.

### 2. Create partner-owned customer payment

```http
POST /me/customer-payments
```

Example:

```json
{
  "external_reference": "dukanest-self-payment-1001",
  "source": {
    "wallet_account_number": "DUKANESTOPS1"
  },
  "payer": {
    "phone_number": "254700000222",
    "name": "Platform Buyer",
    "email": "buyer@example.com"
  },
  "amount": 2300,
  "currency": "KES",
  "account_reference": "DN1001",
  "description": "Platform fee payment"
}
```

### 3. Get partner-owned customer payment

```http
GET /me/customer-payments/{externalReference}
```

### 4. Create partner-owned withdrawal

```http
POST /me/withdrawals
```

Example:

```json
{
  "external_reference": "dukanest-self-withdrawal-1001",
  "source": {
    "wallet_account_number": "DUKANESTOPS1"
  },
  "destination": {
    "type": "mpesa",
    "phone_number": "254700000333"
  },
  "payee": {
    "name": "DukaNest Ops"
  },
  "amount": 1500,
  "description": "Platform cashout"
}
```

### 5. Get partner-owned withdrawal

```http
GET /me/withdrawals/{externalReference}
```

---

## Refund APIs

Refunds are built from the original customer payment reference.

### Merchant refund

```http
POST /refunds
```

Example:

```json
{
  "merchant_external_id": "dukanest-store-001",
  "external_reference": "dukanest-refund-1001",
  "payment_reference": "dukanest-payment-1001",
  "reason": "Customer order cancelled"
}
```

Tumizi automatically uses:

- the original payment amount
- the original payment currency
- the original payer phone number

### Get merchant refund

```http
GET /refunds/{externalReference}
```

### Partner-self refund

```http
POST /me/refunds
```

Example:

```json
{
  "external_reference": "dukanest-self-refund-1001",
  "payment_reference": "dukanest-self-payment-1001",
  "reason": "Platform charge reversed"
}
```

### Get partner-self refund

```http
GET /me/refunds/{externalReference}
```

Refund response fields:

- `scope`
- `payment_reference`
- `recipient_phone`
- `amount`
- `currency`
- `payout_request_id`
- `payout_request_number`
- `status`

---

## Webhooks

Current webhook events:

- `partner.customer_payment.updated`
- `partner.withdrawal.updated`
- `partner.refund.updated`

Webhook scope rules:

- partner-level endpoints receive partner-owned events and merchant events
- merchant-scoped endpoints receive only events for that merchant mapping

---

## Recommended DukaNest Sandbox Test Order

1. Configure the DukaNest integration app in Tumizi with:
   - partner organisation
   - partner wallet
2. Issue an API key with the full sandbox scope set.
3. Add one partner-level webhook endpoint.
4. Create a merchant with `POST /merchants`.
5. Confirm the merchant wallet with `GET /merchants/{merchantExternalId}/wallet`.
6. Run a merchant customer payment.
7. Poll the merchant payment status.
8. Run a merchant withdrawal.
9. Run a merchant refund using the merchant payment reference.
10. Run a partner-self customer payment.
11. Run a partner-self withdrawal.
12. Run a partner-self refund using the partner payment reference.

---

## Production Notes

- Keep `external_reference` unique per event.
- Keep `merchant_external_id` stable forever.
- Treat refunds as full-reference refunds unless Tumizi later adds partial refund support.
- Do not use legacy payout-request endpoints as the main DukaNest gateway contract.
- Use the `scope` field in responses to distinguish merchant and partner-owned records.
