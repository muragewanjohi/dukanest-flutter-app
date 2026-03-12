# M-Pesa Production Postman Collection

This folder contains Postman collections for testing M-Pesa STK Push (Lipa na M-Pesa Online) in **PRODUCTION** environment.

## ⚠️ IMPORTANT WARNINGS

- **This uses LIVE/PRODUCTION APIs** - Real money will be charged!
- **Use with extreme caution** - Only test with small amounts
- **Ensure you have valid production credentials** from Safaricom Developer Portal
- **Test with your own phone number first**

## Files

1. **M-Pesa Production - STK Push.postman_collection.json** - Main collection with all endpoints
2. **M-Pesa Production Environment.postman_environment.json** - Environment template for variables

## Setup Instructions

### Step 1: Import Collection and Environment

1. Open Postman
2. Click **Import** button
3. Import both files:
   - `M-Pesa Production - STK Push.postman_collection.json`
   - `M-Pesa Production Environment.postman_environment.json`

### Step 2: Configure Environment Variables

1. Select the **"M-Pesa Production"** environment from the dropdown
2. Click the eye icon to view/edit variables
3. Fill in your production credentials:

```
mpesa_consumer_key     = Your production consumer key
mpesa_consumer_secret  = Your production consumer secret
mpesa_shortcode        = Your Till Number (e.g., 9584650)
mpesa_passkey          = Your production passkey
callback_url           = Your callback URL (must be publicly accessible)
```

**Example:**
```
mpesa_consumer_key     = oIIHDX5Vh4eahIguoNu4p2p28x4qp0wgjHIUShv1yuvXOGkm
mpesa_consumer_secret  = MeSTuN8Ox9H7cjjHK9R1Pvri0iRqMSfUxvBER637LFsXtAXYct5HCRBx6OBNSCvr
mpesa_shortcode        = 9584650
mpesa_passkey          = 91660505da7f7432bf5c98a1acb899e208c1ca26fb9e4f820c80a3ddd477ca69
callback_url           = https://yourdomain.com/api/mpesa/subscription/callback
```

### Step 3: Get Your Production Credentials

If you don't have production credentials:

1. Go to https://developer.safaricom.co.ke/
2. Log in to your account
3. Navigate to **My Apps** → Select your app
4. Get:
   - Consumer Key
   - Consumer Secret
   - Short Code (Till Number)
   - Passkey (provided by Safaricom for your Till Number)

## Usage Flow

### 1. Get OAuth Access Token

1. Open the collection: **"M-Pesa Production - STK Push"**
2. Run: **"1. Get OAuth Access Token"**
3. The token will be automatically saved to `mpesa_access_token` variable
4. Token is valid for 1 hour

**Expected Response:**
```json
{
    "access_token": "abc123...",
    "expires_in": "3599"
}
```

### 2. Initiate STK Push

1. Open: **"2. Initiate STK Push (Buy Goods)"**
2. **IMPORTANT:** Update the request body:
   - `PartyA`: Your test phone number (254XXXXXXXXX format)
   - `PhoneNumber`: Your test phone number (254XXXXXXXXX format)
   - `Amount`: Test amount (e.g., "1" for 1 KES)
   - `AccountReference`: Unique reference (auto-generated with timestamp)
3. Click **Send**
4. Check your phone - you should receive an STK push prompt
5. The `CheckoutRequestID` will be automatically saved

**Request Body Example:**
```json
{
    "BusinessShortCode": "9584650",
    "Password": "auto-generated",
    "Timestamp": "auto-generated",
    "TransactionType": "CustomerBuyGoodsOnline",
    "Amount": "1",
    "PartyA": "254712345678",
    "PartyB": "9584650",
    "PhoneNumber": "254712345678",
    "CallBackURL": "https://yourdomain.com/api/mpesa/subscription/callback",
    "AccountReference": "TEST-1738000000",
    "TransactionDesc": "Test Payment"
}
```

**Expected Response:**
```json
{
    "MerchantRequestID": "12345-67890-1",
    "CheckoutRequestID": "ws_CO_27012026101235...",
    "ResponseCode": "0",
    "ResponseDescription": "Success. Request accepted for processing",
    "CustomerMessage": "Success. Request accepted for processing"
}
```

### 3. Query STK Push Status (Optional)

1. Open: **"3. Query STK Push Status"**
2. The `CheckoutRequestID` from step 2 is automatically used
3. Click **Send**
4. Check the response for payment status

**Expected Response (Success):**
```json
{
    "ResponseCode": "0",
    "ResponseDescription": "The service request is processed successfully.",
    "MerchantRequestID": "12345-67890-1",
    "CheckoutRequestID": "ws_CO_27012026101235...",
    "ResultCode": "0",
    "ResultDesc": "The service request is processed successfully."
}
```

**Result Codes:**
- `0` = Payment successful ✅
- `1032` = User cancelled ❌
- `1037` = Timeout ⏱️
- `1` = Failed ❌

## Auto-Generated Fields

The collection automatically generates:
- **Timestamp**: Current date/time in `YYYYMMDDHHmmss` format
- **Password**: Base64 encoded `SHORTCODE + PASSKEY + TIMESTAMP`
- **AccountReference**: `TEST-{timestamp}` for test payments

## Production URLs

All endpoints use production URLs:
- **OAuth**: `https://api.safaricom.co.ke/oauth/v1/generate`
- **STK Push**: `https://api.safaricom.co.ke/mpesa/stkpush/v1/processrequest`
- **STK Query**: `https://api.safaricom.co.ke/mpesa/stkpushquery/v1/query`

## Troubleshooting

### "Invalid credentials"
- Verify your Consumer Key and Consumer Secret are correct
- Ensure you're using **production** credentials, not sandbox

### "Invalid phone number"
- Phone number must be in format: `254XXXXXXXXX` (12 digits starting with 254)
- Remove any spaces, dashes, or special characters

### "STK Push not received"
- Check phone number is correct
- Ensure phone has M-Pesa registered
- Check network connectivity
- Verify Till Number is active

### "Callback not received"
- Ensure callback URL is publicly accessible (not localhost)
- Check your server logs for callback requests
- Verify callback URL returns HTTP 200 status

### "Access token expired"
- Tokens expire after 1 hour
- Run "1. Get OAuth Access Token" again

## Security Notes

- **Never commit** your production credentials to version control
- Use environment variables in Postman (not hardcoded values)
- Rotate credentials if exposed
- Monitor your M-Pesa account for unauthorized transactions

## Support

For issues with:
- **M-Pesa API**: Contact Safaricom Developer Support
- **This Collection**: Check the collection description for details

## References

- [Safaricom Developer Portal](https://developer.safaricom.co.ke/)
- [M-Pesa API Documentation](https://developer.safaricom.co.ke/apis)
- [STK Push Documentation](https://developer.safaricom.co.ke/APIs/LipaNaMpesaOnlineAPI)
