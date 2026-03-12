# API Documentation

**Complete API reference for Dukanest multi-tenant e-commerce platform**

---

## Table of Contents

1. [Authentication](#authentication)
2. [Tenant Management](#tenant-management)
3. [Products](#products)
4. [Orders](#orders)
5. [Customers](#customers)
6. [Cart](#cart)
7. [Checkout](#checkout)
8. [Inventory](#inventory)
9. [Analytics](#analytics)
10. [Content Management](#content-management)
11. [Support Tickets](#support-tickets)
12. [Themes](#themes)
13. [Admin Operations](#admin-operations)

---

## Base URL

- **Local Development:** `http://localhost:3000`
- **Production:** `https://www.dukanest.com` (or tenant subdomain)

---

## Authentication

All authenticated endpoints require a valid session cookie (set via login endpoints).

### Landlord Authentication

#### Register Landlord
```http
POST /api/auth/landlord/register
```

**Request Body:**
```json
{
  "name": "Admin User",
  "email": "admin@example.com",
  "password": "SecurePassword123!"
}
```

**Response:**
```json
{
  "success": true,
  "user": {
    "id": "uuid",
    "email": "admin@example.com",
    "role": "landlord"
  },
  "message": "Registration successful. Please check your email to verify your account."
}
```

#### Login Landlord
```http
POST /api/auth/landlord/login
```

**Request Body:**
```json
{
  "email": "admin@example.com",
  "password": "SecurePassword123!"
}
```

**Response:**
```json
{
  "success": true,
  "user": {
    "id": "uuid",
    "email": "admin@example.com",
    "role": "landlord",
    "name": "Admin User"
  }
}
```

### Tenant Authentication

#### Register Tenant Admin
```http
POST /api/auth/tenant/register
```

**Request Body:**
```json
{
  "email": "admin@tenant.com",
  "password": "SecurePassword123!",
  "name": "Tenant Admin"
}
```

**Note:** Tenant registration is typically done during tenant creation via `/api/tenants/register`.

#### Login Tenant Admin
```http
POST /api/auth/tenant/login
```

**Request Body:**
```json
{
  "email": "admin@tenant.com",
  "password": "SecurePassword123!"
}
```

**Response:**
```json
{
  "success": true,
  "user": {
    "id": "uuid",
    "email": "admin@tenant.com",
    "role": "tenant_admin",
    "tenant_id": "uuid",
    "name": "Tenant Admin"
  },
  "session": {
    "access_token": "token",
    "expires_at": 1234567890
  }
}
```

#### Forgot Password
```http
POST /api/auth/tenant/forgot-password
```

**Request Body:**
```json
{
  "email": "admin@tenant.com"
}
```

**Response:**
```json
{
  "success": true,
  "message": "If an account exists with this email, a password reset link has been sent."
}
```

#### Reset Password
```http
POST /api/auth/tenant/reset-password
```

**Request Body:**
```json
{
  "password": "NewSecurePassword123!",
  "confirmPassword": "NewSecurePassword123!"
}
```

**Note:** This endpoint requires a valid recovery token from the password reset email.

### Customer Authentication

#### Register Customer
```http
POST /api/customers/auth/register
```

**Request Body:**
```json
{
  "email": "customer@example.com",
  "password": "SecurePassword123!",
  "name": "John Doe"
}
```

#### Login Customer
```http
POST /api/customers/auth/login
```

**Request Body:**
```json
{
  "email": "customer@example.com",
  "password": "SecurePassword123!"
}
```

#### Logout
```http
POST /api/auth/logout
```

**Response:**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

## Tenant Management

### Public Tenant Registration
```http
POST /api/tenants/register
```

**Request Body:**
```json
{
  "name": "My Store",
  "subdomain": "mystore",
  "adminEmail": "admin@mystore.com",
  "adminPassword": "SecurePassword123!",
  "adminName": "Store Admin",
  "contactEmail": "contact@mystore.com",
  "planId": "uuid" // Optional
}
```

**Response:**
```json
{
  "success": true,
  "tenant": {
    "id": "uuid",
    "name": "My Store",
    "subdomain": "mystore",
    "status": "active"
  },
  "message": "Tenant created successfully"
}
```

### Get Current Tenant
```http
GET /api/tenant/current
```

**Response:**
```json
{
  "tenant": {
    "id": "uuid",
    "name": "My Store",
    "subdomain": "mystore",
    "custom_domain": null,
    "status": "active"
  }
}
```

### Admin: List Tenants
```http
GET /api/admin/tenants
```

**Authentication:** Landlord only

**Response:**
```json
{
  "tenants": [
    {
      "id": "uuid",
      "name": "My Store",
      "subdomain": "mystore",
      "custom_domain": null,
      "status": "active",
      "created_at": "2024-01-01T00:00:00Z",
      "expire_date": "2025-01-01T00:00:00Z"
    }
  ]
}
```

### Admin: Get Tenant
```http
GET /api/admin/tenants/{id}
```

**Authentication:** Landlord only

### Admin: Update Tenant
```http
PUT /api/admin/tenants/{id}
```

**Request Body:**
```json
{
  "name": "Updated Store Name",
  "status": "active"
}
```

### Admin: Update Subdomain
```http
PUT /api/admin/tenants/{id}/subdomain
```

**Request Body:**
```json
{
  "subdomain": "newsubdomain"
}
```

---

## Products

### List Products
```http
GET /api/products?page=1&limit=20&search=keyword&status=active&category_id=uuid&min_price=10&max_price=100&in_stock=true
```

**Query Parameters:**
- `page` (number): Page number (default: 1)
- `limit` (number): Items per page (default: 20)
- `search` (string): Search keyword
- `status` (string): Filter by status (`active`, `inactive`, `draft`)
- `category_id` (uuid): Filter by category
- `min_price` (number): Minimum price filter
- `max_price` (number): Maximum price filter
- `in_stock` (boolean): Filter by stock availability
- `sort_by` (string): Sort field (`name`, `price`, `created_at`)
- `sort_order` (string): Sort order (`asc`, `desc`)

**Response:**
```json
{
  "products": [
    {
      "id": "uuid",
      "name": "Product Name",
      "description": "Product description",
      "price": 99.99,
      "sku": "SKU-001",
      "stock_quantity": 100,
      "status": "active",
      "category_id": "uuid",
      "images": ["url1", "url2"],
      "created_at": "2024-01-01T00:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "totalPages": 5
  }
}
```

### Get Product
```http
GET /api/products/{id}
```

**Response:**
```json
{
  "product": {
    "id": "uuid",
    "name": "Product Name",
    "description": "Product description",
    "price": 99.99,
    "sku": "SKU-001",
    "stock_quantity": 100,
    "status": "active",
    "category": {
      "id": "uuid",
      "name": "Category Name"
    },
    "variants": [],
    "images": ["url1", "url2"],
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

### Create Product
```http
POST /api/products
```

**Authentication:** Tenant admin/staff

**Request Body:**
```json
{
  "name": "Product Name",
  "description": "Product description",
  "price": 99.99,
  "sku": "SKU-001",
  "stock_quantity": 100,
  "category_id": "uuid",
  "status": "active",
  "images": ["url1", "url2"]
}
```

**Response:**
```json
{
  "product": {
    "id": "uuid",
    "name": "Product Name",
    "price": 99.99,
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

### Update Product
```http
PUT /api/products/{id}
```

**Authentication:** Tenant admin/staff

**Request Body:** (same as create, all fields optional)

### Delete Product
```http
DELETE /api/products/{id}
```

**Authentication:** Tenant admin/staff

### Upload Product Image
```http
POST /api/products/upload
```

**Authentication:** Tenant admin/staff

**Request:** Multipart form data with `file` field

**Response:**
```json
{
  "url": "https://storage.supabase.co/...",
  "publicUrl": "https://storage.supabase.co/..."
}
```

### Product Variants

#### List Variants
```http
GET /api/products/{id}/variants
```

#### Create Variant
```http
POST /api/products/{id}/variants
```

**Request Body:**
```json
{
  "name": "Size: Large",
  "price": 109.99,
  "sku": "SKU-001-L",
  "stock_quantity": 50
}
```

#### Update Variant
```http
PUT /api/products/{id}/variants/{variantId}
```

#### Delete Variant
```http
DELETE /api/products/{id}/variants/{variantId}
```

---

## Orders

### List Orders
```http
GET /api/orders?page=1&limit=20&status=pending&payment_status=paid&start_date=2024-01-01&end_date=2024-12-31
```

**Query Parameters:**
- `page` (number): Page number
- `limit` (number): Items per page
- `search` (string): Search keyword
- `status` (string): Order status (`pending`, `processing`, `shipped`, `delivered`, `cancelled`)
- `payment_status` (string): Payment status (`pending`, `paid`, `failed`, `refunded`)
- `order_number` (string): Filter by order number
- `customer_email` (string): Filter by customer email
- `start_date` (string): Start date (ISO format)
- `end_date` (string): End date (ISO format)
- `sort_by` (string): Sort field
- `sort_order` (string): Sort order

**Authentication:** Tenant admin/staff or customer (own orders)

**Response:**
```json
{
  "orders": [
    {
      "id": "uuid",
      "order_number": "ORD-001",
      "customer_id": "uuid",
      "total_amount": 199.98,
      "status": "pending",
      "payment_status": "paid",
      "items": [
        {
          "product_id": "uuid",
          "product_name": "Product Name",
          "quantity": 2,
          "price": 99.99
        }
      ],
      "created_at": "2024-01-01T00:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 50,
    "totalPages": 3
  }
}
```

### Get Order
```http
GET /api/orders/{id}
```

**Authentication:** Tenant admin/staff or customer (own order)

### Create Order
```http
POST /api/orders
```

**Authentication:** Tenant admin/staff

**Request Body:**
```json
{
  "customer_id": "uuid",
  "items": [
    {
      "product_id": "uuid",
      "quantity": 2,
      "price": 99.99
    }
  ],
  "shipping_address": {
    "name": "John Doe",
    "address": "123 Main St",
    "city": "City",
    "state": "State",
    "zip": "12345",
    "country": "Country"
  },
  "billing_address": { /* same structure */ }
}
```

### Update Order Status
```http
PUT /api/orders/{id}
```

**Authentication:** Tenant admin/staff

**Request Body:**
```json
{
  "status": "shipped",
  "tracking_number": "TRACK123"
}
```

### Cancel Order
```http
POST /api/orders/{id}/cancel
```

**Authentication:** Tenant admin/staff or customer (own order)

**Request Body:**
```json
{
  "reason": "Customer requested cancellation"
}
```

### Track Order
```http
GET /api/orders/track?order_number=ORD-001
```

**Query Parameters:**
- `order_number` (string): Order number

**Response:**
```json
{
  "order": {
    "id": "uuid",
    "order_number": "ORD-001",
    "status": "shipped",
    "tracking_number": "TRACK123",
    "tracking_url": "https://tracking.com/TRACK123"
  }
}
```

---

## Customers

### List Customers
```http
GET /api/customers?page=1&limit=20&search=keyword
```

**Authentication:** Tenant admin/staff

**Query Parameters:**
- `page` (number): Page number
- `limit` (number): Items per page
- `search` (string): Search keyword

**Response:**
```json
{
  "customers": [
    {
      "id": "uuid",
      "email": "customer@example.com",
      "name": "John Doe",
      "phone": "+1234567890",
      "total_orders": 5,
      "total_spent": 499.95,
      "created_at": "2024-01-01T00:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "totalPages": 5
  }
}
```

### Get Customer
```http
GET /api/customers/{id}
```

**Authentication:** Tenant admin/staff or customer (own profile)

### Update Customer
```http
PUT /api/customers/{id}
```

**Authentication:** Tenant admin/staff or customer (own profile)

**Request Body:**
```json
{
  "name": "Updated Name",
  "phone": "+1234567890"
}
```

### Get Customer Profile
```http
GET /api/customers/profile
```

**Authentication:** Customer (own profile)

### Update Customer Profile
```http
PUT /api/customers/profile
```

**Authentication:** Customer (own profile)

### Customer Addresses

#### List Addresses
```http
GET /api/customers/{id}/addresses
```

#### Create Address
```http
POST /api/customers/{id}/addresses
```

**Request Body:**
```json
{
  "type": "shipping", // or "billing"
  "name": "John Doe",
  "address": "123 Main St",
  "city": "City",
  "state": "State",
  "zip": "12345",
  "country": "Country",
  "is_default": true
}
```

#### Update Address
```http
PUT /api/customers/{id}/addresses/{addressId}
```

#### Delete Address
```http
DELETE /api/customers/{id}/addresses/{addressId}
```

### Customer Orders
```http
GET /api/customers/profile/orders
```

**Authentication:** Customer (own orders)

### Customer Wishlist

#### Get Wishlist
```http
GET /api/customers/profile/wishlist
```

**Authentication:** Customer

#### Add to Wishlist
```http
POST /api/customers/profile/wishlist
```

**Request Body:**
```json
{
  "product_id": "uuid"
}
```

#### Remove from Wishlist
```http
DELETE /api/customers/profile/wishlist?product_id=uuid
```

### Export Customers
```http
GET /api/customers/export?format=csv
```

**Authentication:** Tenant admin/staff

**Query Parameters:**
- `format` (string): Export format (`csv`, `json`)

---

## Cart

### Get Cart
```http
GET /api/cart
```

**Response:**
```json
{
  "items": [
    {
      "id": "uuid",
      "product_id": "uuid",
      "product_name": "Product Name",
      "product_image": "url",
      "price": 99.99,
      "quantity": 2,
      "subtotal": 199.98
    }
  ],
  "total": 199.98,
  "item_count": 2
}
```

### Add to Cart
```http
POST /api/cart
```

**Request Body:**
```json
{
  "product_id": "uuid",
  "quantity": 2,
  "variant_id": "uuid" // Optional
}
```

**Response:**
```json
{
  "item": {
    "id": "uuid",
    "product_id": "uuid",
    "quantity": 2,
    "price": 99.99
  },
  "cart": {
    "total": 199.98,
    "item_count": 2
  }
}
```

### Update Cart Item
```http
PUT /api/cart
```

**Request Body:**
```json
{
  "item_id": "uuid",
  "quantity": 3
}
```

### Remove from Cart
```http
DELETE /api/cart?item_id=uuid
```

**Query Parameters:**
- `item_id` (uuid): Cart item ID

### Clear Cart
```http
DELETE /api/cart
```

### Get Cart Count
```http
GET /api/cart/count
```

**Response:**
```json
{
  "count": 5
}
```

### Merge Carts
```http
POST /api/cart/merge
```

**Request Body:**
```json
{
  "guest_cart": [
    {
      "product_id": "uuid",
      "quantity": 1
    }
  ]
}
```

**Note:** Used when a guest user logs in to merge their guest cart with their account cart.

---

## Checkout

### Create Checkout
```http
POST /api/checkout
```

**Authentication:** Optional (guest checkout supported)

**Request Body:**
```json
{
  "items": [
    {
      "product_id": "uuid",
      "quantity": 2,
      "variant_id": "uuid" // Optional
    }
  ],
  "shipping_address": {
    "name": "John Doe",
    "email": "customer@example.com",
    "phone": "+1234567890",
    "address": "123 Main St",
    "city": "City",
    "state": "State",
    "zip": "12345",
    "country": "Country"
  },
  "billing_address": { /* same structure */ },
  "payment_method": "pesapal", // or "paypal"
  "shipping_method": "standard"
}
```

**Response:**
```json
{
  "order": {
    "id": "uuid",
    "order_number": "ORD-001",
    "total_amount": 199.98,
    "status": "pending",
    "payment_status": "pending"
  },
  "payment_url": "https://payment-gateway.com/...", // If payment required
  "message": "Order created successfully"
}
```

---

## Inventory

### List Inventory
```http
GET /api/inventory?page=1&limit=20&low_stock=true
```

**Authentication:** Tenant admin/staff

**Query Parameters:**
- `page` (number): Page number
- `limit` (number): Items per page
- `low_stock` (boolean): Filter low stock items
- `search` (string): Search keyword

### Adjust Stock
```http
POST /api/inventory/adjust
```

**Authentication:** Tenant admin/staff

**Request Body:**
```json
{
  "product_id": "uuid",
  "quantity": -10, // Negative for decrease, positive for increase
  "reason": "Stock adjustment",
  "notes": "Manual adjustment"
}
```

### Bulk Stock Update
```http
POST /api/inventory/bulk
```

**Authentication:** Tenant admin/staff

**Request Body:**
```json
{
  "updates": [
    {
      "product_id": "uuid",
      "quantity": 100
    },
    {
      "product_id": "uuid2",
      "quantity": 50
    }
  ]
}
```

### Bulk Import Stock
```http
POST /api/inventory/bulk/import
```

**Authentication:** Tenant admin/staff

**Request:** Multipart form data with CSV file

### Get Stock Template
```http
GET /api/inventory/bulk/template
```

**Authentication:** Tenant admin/staff

**Response:** CSV file download

### Get Stock Alerts
```http
GET /api/inventory/alerts
```

**Authentication:** Tenant admin/staff

**Response:**
```json
{
  "alerts": [
    {
      "product_id": "uuid",
      "product_name": "Product Name",
      "current_stock": 5,
      "min_stock": 10,
      "status": "low"
    }
  ]
}
```

### Get Inventory History
```http
GET /api/inventory/history?product_id=uuid&page=1&limit=20
```

**Authentication:** Tenant admin/staff

**Query Parameters:**
- `product_id` (uuid): Filter by product
- `page` (number): Page number
- `limit` (number): Items per page

### Inventory Settings
```http
GET /api/inventory/settings
```

**Authentication:** Tenant admin/staff

```http
PUT /api/inventory/settings
```

**Request Body:**
```json
{
  "low_stock_threshold": 10,
  "enable_alerts": true
}
```

---

## Analytics

### Overview Analytics
```http
GET /api/analytics/overview?start_date=2024-01-01&end_date=2024-12-31
```

**Authentication:** Tenant admin/staff

**Query Parameters:**
- `start_date` (string): Start date (ISO format)
- `end_date` (string): End date (ISO format)

**Response:**
```json
{
  "overview": {
    "total_revenue": 10000.00,
    "total_orders": 100,
    "total_customers": 50,
    "average_order_value": 100.00,
    "conversion_rate": 2.5
  },
  "period": {
    "start": "2024-01-01",
    "end": "2024-12-31"
  }
}
```

### Sales Analytics
```http
GET /api/analytics/sales?start_date=2024-01-01&end_date=2024-12-31&group_by=day
```

**Query Parameters:**
- `start_date` (string): Start date
- `end_date` (string): End date
- `group_by` (string): Group by (`day`, `week`, `month`)

### Revenue Analytics
```http
GET /api/analytics/revenue?start_date=2024-01-01&end_date=2024-12-31
```

### Customer Analytics
```http
GET /api/analytics/customers?start_date=2024-01-01&end_date=2024-12-31
```

### Inventory Analytics
```http
GET /api/analytics/inventory
```

### Compare Analytics
```http
GET /api/analytics/compare?period1_start=2024-01-01&period1_end=2024-03-31&period2_start=2024-04-01&period2_end=2024-06-30
```

### Export Analytics
```http
GET /api/analytics/export?format=csv&type=sales&start_date=2024-01-01&end_date=2024-12-31
```

**Query Parameters:**
- `format` (string): Export format (`csv`, `json`, `pdf`)
- `type` (string): Analytics type (`sales`, `revenue`, `customers`, `inventory`)
- `start_date` (string): Start date
- `end_date` (string): End date

---

## Content Management

### Pages

#### List Pages
```http
GET /api/pages?page=1&limit=20&status=published
```

**Query Parameters:**
- `page` (number): Page number
- `limit` (number): Items per page
- `status` (string): Filter by status (`draft`, `published`)

#### Get Page
```http
GET /api/pages/{id}
```

#### Create Page
```http
POST /api/pages
```

**Authentication:** Tenant admin/staff

**Request Body:**
```json
{
  "title": "About Us",
  "slug": "about-us",
  "content": "Page content...",
  "meta_title": "About Us - My Store",
  "meta_description": "Learn about our store",
  "status": "published"
}
```

#### Update Page
```http
PUT /api/pages/{id}
```

#### Delete Page
```http
DELETE /api/pages/{id}
```

### Blogs

#### List Blog Posts
```http
GET /api/blogs?page=1&limit=20&category_id=uuid&status=published
```

#### Get Blog Post
```http
GET /api/blogs/{id}
```

#### Create Blog Post
```http
POST /api/blogs
```

**Authentication:** Tenant admin/staff

**Request Body:**
```json
{
  "title": "Blog Post Title",
  "slug": "blog-post-title",
  "content": "Blog content...",
  "excerpt": "Short excerpt",
  "category_id": "uuid",
  "featured_image": "url",
  "meta_title": "Blog Post Title",
  "meta_description": "Blog description",
  "status": "published"
}
```

#### Update Blog Post
```http
PUT /api/blogs/{id}
```

#### Delete Blog Post
```http
DELETE /api/blogs/{id}
```

### Blog Categories

#### List Categories
```http
GET /api/blogs/categories
```

#### Create Category
```http
POST /api/blogs/categories
```

**Request Body:**
```json
{
  "name": "Technology",
  "slug": "technology",
  "description": "Tech-related posts"
}
```

#### Update Category
```http
PUT /api/blogs/categories/{id}
```

#### Delete Category
```http
DELETE /api/blogs/categories/{id}
```

### Forms

#### List Forms
```http
GET /api/forms
```

**Authentication:** Tenant admin/staff

#### Get Form
```http
GET /api/forms/{id}
```

#### Create Form
```http
POST /api/forms
```

**Request Body:**
```json
{
  "name": "Contact Form",
  "fields": [
    {
      "type": "text",
      "label": "Name",
      "required": true
    },
    {
      "type": "email",
      "label": "Email",
      "required": true
    }
  ]
}
```

#### Submit Form
```http
POST /api/forms/{id}/submit
```

**Request Body:**
```json
{
  "data": {
    "name": "John Doe",
    "email": "john@example.com"
  }
}
```

#### Get Form Submissions
```http
GET /api/forms/{id}/submissions?page=1&limit=20
```

**Authentication:** Tenant admin/staff

### Media

#### List Media
```http
GET /api/media?page=1&limit=20&search=keyword
```

**Query Parameters:**
- `page` (number): Page number
- `limit` (number): Items per page
- `search` (string): Search keyword
- `type` (string): Filter by type (`image`, `video`, `document`)

#### Upload Media
```http
POST /api/media/upload
```

**Authentication:** Tenant admin/staff

**Request:** Multipart form data with `file` field

**Response:**
```json
{
  "id": "uuid",
  "url": "https://storage.supabase.co/...",
  "publicUrl": "https://storage.supabase.co/...",
  "filename": "image.jpg",
  "size": 1024000,
  "type": "image/jpeg"
}
```

#### Get Media
```http
GET /api/media/{id}
```

#### Delete Media
```http
DELETE /api/media/{id}
```

**Authentication:** Tenant admin/staff

---

## Support Tickets

### List Tickets
```http
GET /api/support/tickets?page=1&limit=20&status=open&priority=high
```

**Query Parameters:**
- `page` (number): Page number
- `limit` (number): Items per page
- `status` (string): Filter by status (`open`, `in_progress`, `resolved`, `closed`)
- `priority` (string): Filter by priority (`low`, `medium`, `high`, `urgent`)
- `department_id` (uuid): Filter by department

**Authentication:** Tenant admin/staff or customer (own tickets)

### Get Ticket
```http
GET /api/support/tickets/{id}
```

**Authentication:** Tenant admin/staff or customer (own ticket)

### Create Ticket
```http
POST /api/support/tickets
```

**Request Body:**
```json
{
  "subject": "Issue with order",
  "description": "I have an issue with my order",
  "department_id": "uuid",
  "priority": "high"
}
```

### Update Ticket
```http
PUT /api/support/tickets/{id}
```

**Authentication:** Tenant admin/staff

**Request Body:**
```json
{
  "status": "in_progress",
  "priority": "high",
  "assigned_to": "uuid"
}
```

### Ticket Messages

#### Get Messages
```http
GET /api/support/tickets/{id}/messages
```

#### Send Message
```http
POST /api/support/tickets/{id}/messages
```

**Request Body:**
```json
{
  "message": "This is my response",
  "attachments": ["url1", "url2"] // Optional
}
```

### Support Departments
```http
GET /api/support/departments
```

**Response:**
```json
{
  "departments": [
    {
      "id": "uuid",
      "name": "Sales",
      "description": "Sales inquiries"
    }
  ]
}
```

### Upload Attachment
```http
POST /api/support/upload
```

**Request:** Multipart form data with `file` field

### Admin: List All Tickets
```http
GET /api/admin/support/tickets
```

**Authentication:** Landlord only

### Admin: Get Ticket
```http
GET /api/admin/support/tickets/{id}
```

**Authentication:** Landlord only

---

## Themes

### List Themes
```http
GET /api/themes
```

**Response:**
```json
{
  "themes": [
    {
      "id": "uuid",
      "name": "Modern",
      "description": "Modern theme",
      "preview_image": "url",
      "is_installed": true,
      "is_active": false
    }
  ]
}
```

### Get Theme
```http
GET /api/themes/{id}
```

### Get Current Theme
```http
GET /api/themes/current
```

**Response:**
```json
{
  "theme": {
    "id": "uuid",
    "name": "Modern",
    "settings": {
      "primary_color": "#000000",
      "font_family": "Arial"
    }
  }
}
```

### Install Theme
```http
POST /api/themes/install
```

**Authentication:** Tenant admin

**Request Body:**
```json
{
  "theme_id": "uuid"
}
```

### Update Theme Settings
```http
PUT /api/themes/current
```

**Authentication:** Tenant admin

**Request Body:**
```json
{
  "settings": {
    "primary_color": "#000000",
    "font_family": "Arial",
    "custom_css": "body { ... }",
    "custom_js": "console.log('...');"
  }
}
```

### Upload Branding
```http
POST /api/themes/upload-branding
```

**Authentication:** Tenant admin

**Request:** Multipart form data with `logo` or `favicon` field

### Export Theme
```http
GET /api/themes/export
```

**Authentication:** Tenant admin

**Response:** JSON file download

### Import Theme
```http
POST /api/themes/import
```

**Authentication:** Tenant admin

**Request:** Multipart form data with JSON file

### Get Demo Content
```http
GET /api/themes/{id}/demo-content
```

**Response:**
```json
{
  "products": [...],
  "categories": [...],
  "pages": [...]
}
```

---

## Admin Operations

### Price Plans

#### List Price Plans
```http
GET /api/admin/price-plans
```

**Authentication:** Landlord only

#### Get Price Plan
```http
GET /api/admin/price-plans/{id}
```

#### Create Price Plan
```http
POST /api/admin/price-plans
```

**Request Body:**
```json
{
  "name": "Basic Plan",
  "price": 29.99,
  "duration_months": 1,
  "trial_days": 7,
  "features": {
    "products": 100,
    "orders": 1000,
    "storage": "10GB"
  },
  "status": "active"
}
```

#### Update Price Plan
```http
PUT /api/admin/price-plans/{id}
```

#### Delete Price Plan
```http
DELETE /api/admin/price-plans/{id}
```

### Public Pricing
```http
GET /api/pricing
```

**No authentication required**

**Response:**
```json
{
  "plans": [
    {
      "id": "uuid",
      "name": "Basic Plan",
      "price": 29.99,
      "duration_months": 1,
      "trial_days": 7,
      "features": {...}
    }
  ]
}
```

### User Management

#### List Users
```http
GET /api/admin/users
```

**Authentication:** Tenant admin

**Response:**
```json
{
  "users": [
    {
      "id": "uuid",
      "email": "staff@tenant.com",
      "name": "Staff User",
      "role": "tenant_staff",
      "last_sign_in": "2024-01-01T00:00:00Z"
    }
  ]
}
```

#### Get User
```http
GET /api/admin/users/{id}
```

#### Create User
```http
POST /api/admin/users
```

**Request Body:**
```json
{
  "email": "staff@tenant.com",
  "password": "SecurePassword123!",
  "name": "Staff User",
  "role": "tenant_staff"
}
```

#### Update User
```http
PUT /api/admin/users/{id}
```

#### Delete User
```http
DELETE /api/admin/users/{id}
```

### Domain Management

#### List Domains
```http
GET /api/admin/domains?domain=example.com
```

**Authentication:** Landlord only

#### Add Domain
```http
POST /api/admin/domains
```

**Request Body:**
```json
{
  "domain": "example.com",
  "tenant_id": "uuid"
}
```

#### Remove Domain
```http
DELETE /api/admin/domains?domain=example.com
```

### Subscription Management

#### Get Tenant Subscription
```http
GET /api/admin/tenants/{id}/subscription
```

**Authentication:** Landlord only

#### Update Subscription
```http
PUT /api/admin/tenants/{id}/subscription
```

**Request Body:**
```json
{
  "plan_id": "uuid",
  "expire_date": "2025-01-01T00:00:00Z"
}
```

#### Get Billing History
```http
GET /api/admin/tenants/{id}/billing
```

#### Activate Subscription
```http
POST /api/dashboard/subscription/activate
```

**Authentication:** Tenant admin

**Request Body:**
```json
{
  "plan_id": "uuid"
}
```

### Analytics Aggregation
```http
GET /api/admin/analytics/aggregate
```

**Authentication:** Cron job (requires `CRON_SECRET_TOKEN`)

**Headers:**
```
Authorization: Bearer {CRON_SECRET_TOKEN}
```

### Data Cleanup
```http
GET /api/admin/cleanup
```

**Authentication:** Cron job (requires `CRON_SECRET_TOKEN`)

### Subscription Expiry Checker
```http
GET /api/admin/subscriptions/expiry-checker
```

**Authentication:** Cron job

### Payment Reminders
```http
GET /api/admin/subscriptions/payment-reminders
```

**Authentication:** Cron job

---

## Error Responses

All endpoints may return the following error responses:

### 400 Bad Request
```json
{
  "error": "Validation failed",
  "message": "Please check your input and try again",
  "details": [
    {
      "field": "email",
      "message": "Invalid email address"
    }
  ]
}
```

### 401 Unauthorized
```json
{
  "error": "Unauthorized",
  "message": "Authentication required"
}
```

### 403 Forbidden
```json
{
  "error": "Access denied",
  "message": "You don't have permission to access this resource"
}
```

### 404 Not Found
```json
{
  "error": "Not found",
  "message": "Resource not found"
}
```

### 409 Conflict
```json
{
  "error": "Conflict",
  "message": "Resource already exists"
}
```

### 500 Internal Server Error
```json
{
  "error": "Internal server error",
  "message": "An unexpected error occurred"
}
```

---

## Rate Limiting

API endpoints are rate-limited to prevent abuse:
- **Public endpoints:** 100 requests per minute per IP
- **Authenticated endpoints:** 1000 requests per minute per user
- **Admin endpoints:** 5000 requests per minute per user

Rate limit headers are included in responses:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1234567890
```

---

## Pagination

List endpoints support pagination with the following query parameters:
- `page` (number): Page number (default: 1)
- `limit` (number): Items per page (default: 20, max: 100)

Response includes pagination metadata:
```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "totalPages": 5,
    "hasNext": true,
    "hasPrev": false
  }
}
```

---

## Date Formats

All dates are in ISO 8601 format:
- `2024-01-01T00:00:00Z`
- `2024-01-01T12:30:45.123Z`

Query parameters accept:
- ISO format: `2024-01-01T00:00:00Z`
- Date only: `2024-01-01` (converted to start of day UTC)

---

## Related Documentation

- [Postman Collection Guide](./POSTMAN_COLLECTION_GUIDE.md)
- [Architecture Documentation](./ARCHITECTURE.md)
- [Security Documentation](./SECURITY.md)

---

**Last Updated:** 2024  
**API Version:** 1.0

