# Admin Documentation

**Complete admin documentation for Dukanest multi-tenant e-commerce platform**

---

## Table of Contents

1. [Landlord Admin Guide](#landlord-admin-guide)
2. [Tenant Admin Guide](#tenant-admin-guide)
3. [Getting Started](#getting-started)

---

## Landlord Admin Guide

### Overview

Landlord admins manage the entire platform, including:
- Creating and managing tenants (stores)
- Managing pricing plans
- Monitoring platform analytics
- Managing support tickets from tenants

### Accessing the Admin Dashboard

1. **Navigate to:** `https://www.dukanest.com/admin/login`
2. **Enter credentials:**
   - Email address
   - Password
3. **Click "Login"**

### Dashboard Overview

The landlord dashboard shows:
- Total tenants
- Active subscriptions
- Platform revenue
- Recent tenant activity
- System notifications

### Tenant Management

#### Creating a New Tenant

1. **Navigate to:** Tenants → New Tenant
2. **Fill in tenant information:**
   - Store Name
   - Subdomain (e.g., "mystore" for mystore.dukanest.com)
   - Admin Email (for tenant admin account)
   - Admin Password
   - Admin Name
   - Contact Email
   - Pricing Plan (optional)
3. **Click "Create Tenant"**
4. **Tenant is created:**
   - Subdomain is automatically configured
   - Tenant admin account is created
   - Welcome email is sent

#### Viewing Tenants

1. **Navigate to:** Tenants → List
2. **View tenant list:**
   - Store name
   - Subdomain
   - Status (active, expired, suspended)
   - Subscription plan
   - Expiry date
   - Created date

#### Editing Tenant

1. **Click on a tenant** from the list
2. **Update information:**
   - Store name
   - Status
   - Subscription plan
   - Expiry date
3. **Click "Save Changes"**

#### Changing Tenant Subdomain

1. **Go to tenant details**
2. **Click "Change Subdomain"**
3. **Enter new subdomain:**
   - Must be unique
   - Must follow naming rules (lowercase, alphanumeric, hyphens)
4. **Click "Update"**
5. **Old subdomain is removed and new one is added**

#### Suspending a Tenant

1. **Go to tenant details**
2. **Click "Suspend Tenant"**
3. **Confirm suspension:**
   - Tenant store becomes inaccessible
   - Admin can still access dashboard
4. **To reactivate:** Change status back to "active"

#### Deleting a Tenant

1. **Go to tenant details**
2. **Click "Delete Tenant"**
3. **Confirm deletion:**
   - ⚠️ **Warning:** This action cannot be undone
   - Tenant data is soft-deleted
   - Subdomain is released for reuse

### Pricing Plans Management

#### Creating a Pricing Plan

1. **Navigate to:** Pricing Plans → New Plan
2. **Fill in plan details:**
   - Plan Name
   - Price (monthly)
   - Duration (months)
   - Trial Days (optional)
   - Features:
     - Maximum products
     - Maximum orders
     - Storage limit
     - Other features
   - Status (active/inactive)
3. **Click "Create Plan"**

#### Editing Pricing Plan

1. **Go to Pricing Plans → List**
2. **Click on a plan**
3. **Update information**
4. **Click "Save Changes"**

#### Plan Features

Common plan features include:
- **Products:** Maximum number of products
- **Orders:** Maximum number of orders per month
- **Storage:** Maximum storage space (GB)
- **Pages:** Maximum number of pages
- **Blogs:** Maximum number of blog posts
- **Customers:** Maximum number of customers
- **Support:** Support ticket limits

### Subscription Management

#### Viewing Tenant Subscriptions

1. **Navigate to:** Tenants → [Tenant] → Subscription
2. **View subscription details:**
   - Current plan
   - Expiry date
   - Billing history
   - Payment status

#### Upgrading/Downgrading Plan

1. **Go to tenant subscription page**
2. **Click "Change Plan"**
3. **Select new plan**
4. **Confirm change:**
   - Plan is updated immediately
   - Billing is adjusted
   - Tenant is notified

#### Renewing Subscription

1. **Go to tenant subscription page**
2. **Click "Renew Subscription"**
3. **Select renewal period**
4. **Confirm renewal:**
   - Expiry date is extended
   - Invoice is generated

#### Viewing Billing History

1. **Go to tenant subscription page**
2. **Click "Billing History"**
3. **View all invoices and payments:**
   - Invoice date
   - Amount
   - Payment status
   - Download invoice

### Domain Management

#### Adding Custom Domain

1. **Navigate to:** Domains → Add Domain
2. **Enter domain information:**
   - Domain name (e.g., "example.com")
   - Tenant (select tenant)
3. **Click "Add Domain"**
4. **Configure DNS:**
   - Follow DNS configuration instructions
   - Wait for DNS propagation
   - Domain is verified automatically

#### Viewing Domains

1. **Navigate to:** Domains → List
2. **View all domains:**
   - Domain name
   - Tenant
   - Verification status
   - SSL status

#### Removing Domain

1. **Go to domain list**
2. **Click "Remove" next to domain**
3. **Confirm removal:**
   - Domain is removed from Vercel
   - DNS records should be updated manually

### Support Tickets (Landlord)

#### Viewing Tenant Support Tickets

1. **Navigate to:** Support → Tickets
2. **View all tickets from tenants:**
   - Ticket subject
   - Tenant name
   - Status
   - Priority
   - Created date

#### Responding to Tickets

1. **Click on a ticket**
2. **View conversation history**
3. **Type your response**
4. **Click "Send Reply"**
5. **Tenant is notified via email**

### Analytics & Reports

#### Platform Analytics

1. **Navigate to:** Analytics → Overview
2. **View platform metrics:**
   - Total tenants
   - Active subscriptions
   - Platform revenue
   - Growth trends

#### Tenant Analytics

1. **Navigate to:** Tenants → [Tenant] → Analytics
2. **View tenant-specific metrics:**
   - Sales
   - Orders
   - Customers
   - Revenue

### User Management

#### Creating Landlord Users

1. **Navigate to:** Users → New User
2. **Fill in user information:**
   - Name
   - Email
   - Password
   - Role (landlord)
3. **Click "Create User"**

#### Managing Users

1. **Navigate to:** Users → List
2. **View all users:**
   - Name
   - Email
   - Role
   - Last sign in
3. **Edit or delete users as needed**

---

## Tenant Admin Guide

### Overview

Tenant admins manage their individual store, including:
- Products and inventory
- Orders and fulfillment
- Customers
- Store settings and themes
- Content (pages, blogs)

### Accessing the Dashboard

1. **Navigate to:** `https://yoursubdomain.dukanest.com/dashboard`
2. **Enter credentials:**
   - Email address
   - Password
3. **Click "Login"**

### Dashboard Overview

The tenant dashboard shows:
- Total sales
- Recent orders
- Low stock alerts
- Customer growth
- Quick actions

### Product Management

#### Creating a Product

1. **Navigate to:** Products → New Product
2. **Fill in product information:**
   - Product Name
   - Description (rich text editor)
   - Price
   - SKU (auto-generated if not provided)
   - Stock Quantity
   - Category
   - Status (active/inactive/draft)
   - Product Images (upload multiple)
3. **Click "Create Product"**

#### Editing Products

1. **Go to Products → List**
2. **Click on a product**
3. **Update information**
4. **Click "Save Changes"**

#### Managing Inventory

1. **Navigate to:** Inventory → Dashboard
2. **View inventory overview:**
   - Total products
   - Low stock alerts
   - Stock value
3. **Adjust Stock:**
   - Go to product details
   - Click "Adjust Stock"
   - Enter quantity change
   - Add reason/notes
   - Save

#### Bulk Stock Update

1. **Navigate to:** Inventory → Bulk Update
2. **Download template:**
   - Click "Download Template"
   - Fill in CSV with product SKU and quantity
3. **Upload CSV:**
   - Click "Upload CSV"
   - Select file
   - Review changes
   - Confirm update

#### Stock Alerts

1. **Navigate to:** Inventory → Alerts
2. **View low stock items:**
   - Products below threshold
   - Current stock levels
   - Recommended actions

### Order Management

#### Viewing Orders

1. **Navigate to:** Orders → List
2. **View all orders:**
   - Order number
   - Customer name
   - Total amount
   - Status
   - Payment status
   - Date

#### Filtering Orders

Use filters to find specific orders:
- **Status:** Pending, Processing, Shipped, Delivered, Cancelled
- **Payment Status:** Pending, Paid, Failed, Refunded
- **Date Range:** Start and end date
- **Customer:** Search by customer email
- **Order Number:** Search by order number

#### Processing Orders

1. **Click on an order**
2. **View order details:**
   - Customer information
   - Shipping address
   - Billing address
   - Order items
   - Payment information
3. **Update status:**
   - Click "Update Status"
   - Select new status
   - Add tracking number (if shipping)
   - Save

#### Fulfilling Orders

1. **Go to order details**
2. **Click "Mark as Shipped"**
3. **Enter tracking information:**
   - Tracking number
   - Carrier
   - Tracking URL
4. **Save:**
   - Order status updates to "Shipped"
   - Customer receives email notification

#### Cancelling Orders

1. **Go to order details**
2. **Click "Cancel Order"**
3. **Enter cancellation reason**
4. **Confirm cancellation:**
   - Order status updates to "Cancelled"
   - Customer receives email notification
   - Refund is processed (if applicable)

### Customer Management

#### Viewing Customers

1. **Navigate to:** Customers → List
2. **View all customers:**
   - Name
   - Email
   - Total orders
   - Total spent
   - Last order date

#### Customer Details

1. **Click on a customer**
2. **View customer information:**
   - Profile details
   - Order history
   - Addresses
   - Notes

#### Adding Customer Notes

1. **Go to customer details**
2. **Click "Add Note"**
3. **Enter note:**
   - Internal notes (not visible to customer)
   - Or customer-facing notes
4. **Save**

#### Exporting Customers

1. **Navigate to:** Customers → Export
2. **Select format:** CSV or JSON
3. **Click "Export"**
4. **Download file**

### Content Management

#### Pages

1. **Navigate to:** Content → Pages
2. **Create Page:**
   - Click "New Page"
   - Enter title and content
   - Set slug (URL)
   - Add SEO metadata
   - Set status (draft/published)
   - Save
3. **Edit Pages:**
   - Click on a page
   - Update content
   - Save

#### Blogs

1. **Navigate to:** Content → Blogs
2. **Create Blog Post:**
   - Click "New Post"
   - Enter title and content
   - Select category
   - Upload featured image
   - Add excerpt
   - Set SEO metadata
   - Set status (draft/published)
   - Save
3. **Manage Categories:**
   - Go to Content → Blog Categories
   - Create, edit, or delete categories

#### Media Library

1. **Navigate to:** Content → Media
2. **Upload Files:**
   - Click "Upload"
   - Select files
   - Add metadata (title, alt text)
   - Save
3. **Manage Files:**
   - View all uploaded files
   - Search by name or type
   - Delete unused files

### Store Settings

#### General Settings

1. **Navigate to:** Settings → General
2. **Update store information:**
   - Store name
   - Contact email
   - Phone number
   - Address
   - Timezone
   - Currency
3. **Save changes**

#### Store Appearance

1. **Navigate to:** Settings → Appearance
2. **Customize store:**
   - Upload logo
   - Upload favicon
   - Set primary colors
   - Choose fonts
   - Add custom CSS/JS

#### Theme Management

1. **Navigate to:** Themes → Browse
2. **View available themes:**
   - Preview themes
   - See theme features
3. **Install Theme:**
   - Click "Install" on a theme
   - Theme is installed
4. **Activate Theme:**
   - Go to Themes → Current
   - Click "Activate" on installed theme
5. **Customize Theme:**
   - Go to Themes → Current
   - Adjust colors, fonts, layout
   - Add custom CSS/JS
   - Save

### Analytics

#### Sales Analytics

1. **Navigate to:** Analytics → Sales
2. **View sales metrics:**
   - Total revenue
   - Number of orders
   - Average order value
   - Sales trends (charts)

#### Customer Analytics

1. **Navigate to:** Analytics → Customers
2. **View customer metrics:**
   - Total customers
   - New customers
   - Customer growth
   - Customer lifetime value

#### Inventory Analytics

1. **Navigate to:** Analytics → Inventory
2. **View inventory metrics:**
   - Stock levels
   - Low stock alerts
   - Stock value
   - Turnover rates

#### Export Reports

1. **Go to any analytics page**
2. **Click "Export"**
3. **Select format:** CSV, JSON, or PDF
4. **Select date range**
5. **Download report**

### User Management (Staff)

#### Creating Staff Users

1. **Navigate to:** Users → New User
2. **Fill in user information:**
   - Name
   - Email
   - Password
   - Role (tenant_admin or tenant_staff)
3. **Click "Create User"**

#### Managing Staff

1. **Navigate to:** Users → List
2. **View all staff:**
   - Name
   - Email
   - Role
   - Last sign in
3. **Edit or delete users**

**Note:** Staff users have limited permissions compared to tenant admins.

### Support Tickets

#### Viewing Tickets

1. **Navigate to:** Support → Tickets
2. **View all tickets:**
   - Subject
   - Customer
   - Status
   - Priority
   - Created date

#### Responding to Tickets

1. **Click on a ticket**
2. **View conversation history**
3. **Type your response**
4. **Attach files if needed**
5. **Click "Send Reply"**
6. **Customer is notified via email**

#### Managing Tickets

- **Assign Tickets:** Assign to staff members
- **Change Status:** Update ticket status
- **Change Priority:** Adjust priority level
- **Close Tickets:** Mark as resolved/closed

### Subscription Management

#### Viewing Subscription

1. **Navigate to:** Settings → Subscription
2. **View subscription details:**
   - Current plan
   - Features and limits
   - Expiry date
   - Billing history

#### Upgrading Plan

1. **Go to Subscription page**
2. **Click "Upgrade Plan"**
3. **Select new plan**
4. **Confirm upgrade:**
   - Plan is updated
   - Billing is adjusted
   - Limits are updated

#### Renewing Subscription

1. **Go to Subscription page**
2. **Click "Renew Subscription"**
3. **Select renewal period**
4. **Complete payment**
5. **Subscription is renewed**

---

## Getting Started

### For Landlord Admins

1. **Log in to admin dashboard**
2. **Create pricing plans** (if not already created)
3. **Create your first tenant** (test store)
4. **Configure domains** (if needed)
5. **Monitor platform analytics**

### For Tenant Admins

1. **Log in to dashboard**
2. **Complete store setup:**
   - Update store information
   - Upload logo and branding
   - Configure settings
3. **Add products:**
   - Create categories
   - Add products
   - Set up inventory
4. **Configure storefront:**
   - Choose and customize theme
   - Create pages
   - Set up navigation
5. **Test checkout process**
6. **Go live!**

---

## Best Practices

### Product Management
- Use clear, descriptive product names
- Write detailed product descriptions
- Upload high-quality product images
- Set accurate stock quantities
- Use proper categories and tags

### Order Management
- Process orders promptly
- Update order status regularly
- Provide tracking information
- Communicate with customers

### Customer Service
- Respond to support tickets quickly
- Be professional and helpful
- Follow up on issues
- Maintain good communication

### Analytics
- Review analytics regularly
- Identify trends and opportunities
- Use data to make decisions
- Export reports for record-keeping

### Finance (COGS + P&L)
- Set `cost_price` for products and variants to improve profit accuracy.
- Log operating expenses regularly (ads, shipping, software, utilities, etc.).
- Review P&L monthly using:
  - `GET /api/analytics/pnl` (web)
  - `GET /api/v1/mobile/dashboard/analytics/pnl` (mobile)
- If costs are missing, margins will be overstated; prioritize filling cost on top-selling SKUs first.

---

## Related Documentation

- [API Documentation](./API_DOCUMENTATION.md)
- [Architecture Documentation](./ARCHITECTURE.md)
- [Mobile Flutter API Notes](./flutter_apis.md)

---

**Last Updated:** 2024

