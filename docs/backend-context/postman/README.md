# DukaNest Postman Collection

**Complete API testing collection for DukaNest multi-tenant ecommerce platform**

---

## 📦 Files

- **`StoreFlow_API_Collection.json`** — Main Postman collection (import this file)
- **`StoreFlow_Environment.json`** — Environment variables for different environments
- **`README.md`** — This file

---

## 🚀 Quick Start

### 1. Import Collection

1. Open Postman
2. Click **Import** button
3. Select `StoreFlow_API_Collection.json`
4. Click **Import**

### 2. Import Environment

1. Click **Import** button
2. Select `StoreFlow_Environment.json`
3. Click **Import**
4. Select the **DukaNest Environment** from the environment dropdown (top right)

### 3. Configure Environment Variables

Update these variables in the environment:

- **`base_url`** - Your API base URL (default: `http://localhost:3000`)
- **`test_domain`** - Test domain for domain management (default: `test.example.com`)
- **`tenant_id`** - Current tenant ID (auto-set by some requests)
- **`tenant_subdomain`** - Tenant subdomain (default: `teststore`)
- **`auth_token`** - Authentication token (auto-set after login)
- **`mobile_access_token`** - Mobile bearer token (auto-set by Mobile Login)
- **`mobile_refresh_token`** - Mobile refresh token (auto-set by Mobile Login/Refresh)
- **`mobile_temp_access_token`** - Temporary token returned when login requires MFA
- **`mobile_temp_refresh_token`** - Temporary refresh token returned when login requires MFA
- **`mobile_requires_mfa`** - Indicates whether MFA verify step is pending
- **`mobile_email`** - Mobile API login email
- **`mobile_password`** - Mobile API login password
- **`mobile_user_id`** - Mobile user ID (auto-set by Mobile Login)
- **`mobile_user_email`** - Mobile user email (auto-set by Mobile Login)
- **`mobile_mfa_code`** - OTP code for MFA verify (set manually while testing)
- **`plan_id`** - Price plan ID (auto-set by Get Price Plans request)
- **`cron_secret_token`** - Secret token for cron endpoints (set manually)
- **`product_id`** - Product ID (auto-set by product requests)
- **`variant_id`** - Product variant ID (auto-set by variant requests)
- **`category_id`** - Category ID (auto-set by category requests)
- **`product_image_url`** - Product image URL (auto-set by upload request)
- **`onboarding_business_type`** - Business type for onboarding starter pack tests (e.g., `Pets`)
- **`onboarding_selling`** - Niche/free-text selling value (e.g., `Ornamental Fish`)
- **`onboarding_theme_slug`** - Theme slug for onboarding starter pack generation (e.g., `grocery`)
- **`starter_pack_job_id`** - Async starter-pack job ID (auto-set by Create Job request)
- **`starter_pack_image_url`** - Generated image URL used by Save Assets request
- **`mobile_device_id`** - Stable device id for register-device / notification preferences (default: `postman-device-1`)
- **`mobile_push_token`** - FCM/APNs registration token for **Mobile Register Device**
- **`mobile_mpesa_checkout_request_id`** - Set automatically by **Mobile M-Pesa Initiate** for **Mobile M-Pesa Status**

---

## 📋 Collection Structure

### Tenant Management
- **Get Current Tenant** - Get tenant info from hostname/headers

### Admin Tenant Management (Day 14)
- **List Tenants** - List all tenants (landlord only)
- **Get Tenant** - Get tenant details by ID
- **Create Tenant** - Create new tenant with admin user
- **Update Tenant** - Update tenant settings
- **Delete Tenant** - Soft delete tenant
- **Change Subdomain** - Change tenant subdomain
- **Update Subscription** - Upgrade/downgrade/renew subscription
- **Get Billing History** - View tenant billing history
- **Get Price Plans** - List available price plans
- **Subscription Expiry Checker** - Check for expired subscriptions (cron)

### Products (Day 15)
- **List Products** - List products with search, filtering, and pagination
- **Get Product** - Get product details by ID
- **Create Product** - Create new product
- **Update Product** - Update product
- **Delete Product** - Delete product
- **Upload Product Image** - Upload image to Supabase Storage
- **List Product Variants** - List all variants for a product
- **Create Product Variant** - Create new variant
- **Update Product Variant** - Update variant
- **Delete Product Variant** - Delete variant

### Categories (Day 15)
- **List Categories** - List categories with optional filtering
- **Get Category** - Get category details by ID
- **Create Category** - Create new category
- **Update Category** - Update category
- **Delete Category** - Delete category

### Mobile API (Phase 0)
- **Mobile Login** - Get mobile access and refresh tokens
- **Mobile Refresh Token** - Refresh mobile access token
- **Mobile Forgot Password** - Supabase password reset email (`/api/v1/mobile/auth/forgot-password`)
- **Mobile MFA Status** - Check whether MFA is required/enabled
- **Mobile MFA Send Code** - Send OTP code to mobile user email
- **Mobile MFA Verify** - Verify OTP code
- **Mobile Logout** - Revoke/close mobile session and clear tokens
- **Mobile Dashboard Overview** - Metrics + recent orders
- **Mobile Dashboard Products** - Mobile product list with filters/pagination
- **Mobile Dashboard Orders** - Mobile order list with filters/pagination
- **Mobile Dashboard Customers** - Mobile customer list with filters/pagination
- **Mobile Dashboard Inventory** - Mobile inventory list with stock metrics
- **Mobile Dashboard Settings** - Core store settings for mobile app
- **Mobile Dashboard Sales** - Sales/promotions list with pagination
- **Mobile Dashboard Analytics** - Revenue/trends/top products (`days` query)
- **Mobile Media Upload** - Multipart image upload (`file` field)
- **Mobile M-Pesa Initiate** / **Mobile M-Pesa Status** - STK push + poll (`checkoutRequestId`)
- **Mobile Notifications List** - Derived in-app notifications feed
- **Mobile Register Device** - Upsert push token + device metadata
- **Mobile Notification Preferences (GET/PUT)** - Per-device notification toggles
- **Onboarding Selling Exists** - Precheck if `selling` niche already exists
- **Onboarding Starter Pack (Sync)** - Build starter-pack payload + precheck decision
- **Onboarding Starter Pack Create Job** - Create async generation job for Flutter
- **Onboarding Starter Pack Job Status** - Poll async starter-pack job
- **Onboarding Starter Pack Save Assets** - Persist generated image URLs/metadata

### Domain Management (Day 11)
- **Add Custom Domain** - Add a custom domain to tenant
- **Get Domain Info** - Get domain information and verification status
- **Remove Domain** - Remove a custom domain

### Products (Day 10 Example)
- **Get Products** - List all products for tenant
- **Create Product** - Create a new product

---

## 🧪 Testing

### Running Tests

Each request includes automated tests that verify:
- Status codes
- Response structure
- Data validation

### Manual Testing

1. **Set Environment Variables:**
   - Update `base_url` if not using localhost
   - Set `test_domain` to your test domain

2. **Run Requests:**
   - Click on any request
   - Click **Send**
   - Check **Test Results** tab for automated tests

3. **Check Response:**
   - View response in **Body** tab
   - Check **Headers** for additional info

### Mobile MFA Test Order (Phase 0)

For tenant accounts that require MFA, run requests in this order:

1. **Mobile Login**
   - Expected: `requiresMfa: true`
   - Auto-sets `mobile_user_id`, `mobile_temp_access_token`, `mobile_temp_refresh_token`
2. **Mobile MFA Status**
   - Confirms MFA requirement/enabled flags for the user
3. **Mobile MFA Send Code**
   - Sends OTP to the login email
4. **Mobile MFA Verify**
   - Uses `mobile_mfa_code` + temp session to finalize auth
   - Auto-promotes to `mobile_access_token` / `mobile_refresh_token`
5. **Mobile Dashboard Overview** (or any protected mobile dashboard endpoint)
   - Confirms bearer token works end-to-end

### Onboarding Starter Pack Test Order (Gemini + Nano Banana)

Use this sequence for niche onboarding tests (Flutter-compatible flow):

1. **Onboarding Selling Exists**
   - Endpoint: `POST /api/onboarding/selling-exists`
   - Purpose: check if `selling` already exists and avoid unnecessary generation.
2. **Onboarding Starter Pack Create Job**
   - Endpoint: `POST /api/onboarding/starter-pack-jobs`
   - Purpose: create async job for starter-pack generation (recommended mobile flow).
   - Auto-sets `starter_pack_job_id`.
3. **Onboarding Starter Pack Job Status**
   - Endpoint: `GET /api/onboarding/starter-pack-jobs/{{starter_pack_job_id}}`
   - Purpose: poll until status is `success` or `failed`.
4. **(External step) Generate images from `nanoBanana.jobs`**
   - Use returned prompts with your Nano Banana service.
   - Upload resulting images to your storage and capture final URLs.
5. **Onboarding Starter Pack Save Assets**
   - Endpoint: `POST /api/onboarding/starter-pack-jobs/{{starter_pack_job_id}}/save-assets`
   - Purpose: persist generated image URLs/metadata to job result and optionally tenant profile.

Optional:
- **Onboarding Starter Pack (Sync)** can be used for quick contract tests or dry runs without async job polling.

---

## 🔄 Updating Collection

### After Each Development Day

When new API endpoints are added, update the collection:

1. **Add New Request:**
   ```json
   {
     "name": "New Endpoint Name",
     "request": {
       "method": "GET|POST|PUT|DELETE",
       "url": "{{base_url}}/api/endpoint",
       "header": [...],
       "body": {...}
     },
     "event": [{
       "listen": "test",
       "script": {
         "exec": [
           "pm.test(\"Status code is 200\", function () {",
           "    pm.response.to.have.status(200);",
           "});"
         ]
       }
     }]
   }
   ```

2. **Add to Appropriate Folder:**
   - Create new folder if needed
   - Add request to relevant folder

3. **Add Tests:**
   - Include automated tests for each request
   - Test status codes, response structure, data validation

4. **Update Documentation:**
   - Add description mentioning which day it was added
   - Include required/optional parameters
   - Document expected responses

### Example: Adding New Endpoint

**Step 1:** Open Postman collection

**Step 2:** Right-click on folder → **Add Request**

**Step 3:** Configure request:
- Method: `POST`
- URL: `{{base_url}}/api/new-endpoint`
- Headers: Add required headers
- Body: Add request body (if needed)

**Step 4:** Add tests in **Tests** tab:
```javascript
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});

pm.test("Response has expected data", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property('data');
});
```

**Step 5:** Add description:
- Mention which day it was added
- Document parameters
- Document expected response

**Step 6:** Export updated collection:
- Click **...** (three dots) → **Export**
- Save as `StoreFlow_API_Collection.json`
- Replace existing file

---

## 📝 Day-by-Day Updates

### Day 10: Tenant Resolution System ✅
- ✅ Get Current Tenant (`/api/tenant/current`)
- ✅ Products Example (`/api/products`)

### Day 11: Vercel Domain Management ✅
- ✅ Add Custom Domain (`POST /api/admin/domains`)
- ✅ Get Domain Info (`GET /api/admin/domains`)
- ✅ Remove Domain (`DELETE /api/admin/domains`)

### Day 12: Supabase Authentication ✅
- ✅ Landlord Register
- ✅ Landlord Login
- ✅ Tenant Login
- ✅ Get Current User
- ✅ Logout
- ✅ Refresh Token
- ✅ User Management (List, Create, Update, Delete)

### Day 13-14: Tenant Management ✅
- ✅ Create Tenant (`POST /api/admin/tenants`)
- ✅ List Tenants (`GET /api/admin/tenants`)
- ✅ Get Tenant (`GET /api/admin/tenants/[id]`)
- ✅ Update Tenant (`PUT /api/admin/tenants/[id]`)
- ✅ Delete Tenant (`DELETE /api/admin/tenants/[id]`)
- ✅ Change Subdomain (`PUT /api/admin/tenants/[id]/subdomain`)
- ✅ Update Subscription (`PUT /api/admin/tenants/[id]/subscription`)
- ✅ Get Billing History (`GET /api/admin/tenants/[id]/billing`)
- ✅ Get Price Plans (`GET /api/admin/price-plans`)
- ✅ Subscription Expiry Checker (`GET /api/admin/subscriptions/expiry-checker`)

### Day 15: Product Management ✅
- ✅ List Products (`GET /api/products`) - With search, filtering, pagination
- ✅ Get Product (`GET /api/products/[id]`)
- ✅ Create Product (`POST /api/products`)
- ✅ Update Product (`PUT /api/products/[id]`)
- ✅ Delete Product (`DELETE /api/products/[id]`)
- ✅ Upload Product Image (`POST /api/products/upload`)
- ✅ List Product Variants (`GET /api/products/[id]/variants`)
- ✅ Create Product Variant (`POST /api/products/[id]/variants`)
- ✅ Update Product Variant (`PUT /api/products/[id]/variants/[variantId]`)
- ✅ Delete Product Variant (`DELETE /api/products/[id]/variants/[variantId]`)
- ✅ List Categories (`GET /api/categories`)
- ✅ Get Category (`GET /api/categories/[id]`)
- ✅ Create Category (`POST /api/categories`)
- ✅ Update Category (`PUT /api/categories/[id]`)
- ✅ Delete Category (`DELETE /api/categories/[id]`)

---

## 🔐 Authentication

- **Web-style routes** (`/api/*` outside mobile): use `auth_token` from tenant/landlord login where applicable; the collection prerequest script sends `Authorization: Bearer` when `auth_token` or `mobile_access_token` is set.
- **Mobile routes** (`/api/v1/mobile/*`): run **Mobile Login** (or **Mobile MFA Verify** after MFA). Tokens are stored in `mobile_access_token` / `mobile_refresh_token` and mirrored to `auth_token` for shared headers.
- **Forgot password** does not require a bearer token (collection may still attach one if present; harmless).

---

## 🌍 Multiple Environments

### Local Development
```json
{
  "base_url": "http://localhost:3000",
  "test_domain": "test.localhost"
}
```

### Staging
```json
{
  "base_url": "https://staging.storeflow.com",
  "test_domain": "test.staging.storeflow.com"
}
```

### Production
```json
{
  "base_url": "https://api.storeflow.com",
  "test_domain": "test.storeflow.com"
}
```

**Create separate environments in Postman for each.**

---

## 🐛 Troubleshooting

### Issue: "Cannot connect to server"
**Solution:** 
- Check if dev server is running (`npm run dev`)
- Verify `base_url` is correct

### Issue: "404 Not Found"
**Solution:**
- Check API route exists
- Verify URL path is correct
- Check middleware configuration

### Issue: "401 Unauthorized"
**Solution:**
- Authentication not implemented yet (Day 12)
- For now, ensure tenant context is set via middleware

### Issue: "500 Internal Server Error"
**Solution:**
- Check server logs
- Verify environment variables are set
- Check database connection

---

## 📚 Resources

- [Postman Documentation](https://learning.postman.com/docs/)
- [Writing Tests in Postman](https://learning.postman.com/docs/writing-scripts/test-scripts/)
- [Environment Variables](https://learning.postman.com/docs/sending-requests/managing-environments/)

---

## ✅ Testing Checklist

After each day, verify:

- [ ] New endpoints added to collection
- [ ] Tests written for each endpoint
- [ ] Documentation updated
- [ ] Environment variables set correctly
- [ ] All tests passing
- [ ] Collection exported and saved

---

## 📝 Notes

- **Collection:** `StoreFlow_API_Collection.json` — keep in sync when adding or changing API routes.
- **Last documentation pass:** March 2026 (mobile dashboard extensions + onboarding starter-pack requests).

---

**Happy Testing! 🚀**

