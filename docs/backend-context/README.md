# DukaNest Technical Documentation

**Complete technical documentation for the DukaNest multi-tenant ecommerce platform**

---

## 📚 Core Documentation

### 🏗️ **Architecture & Design**
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Complete system architecture and design patterns
- **[SECURITY.md](./SECURITY.md)** - Row-Level Security (RLS) implementation guide
- **[PRISMA_EXPLANATION.md](./PRISMA_EXPLANATION.md)** - Prisma ORM integration guide

### 🔌 **API & Integration**
- **[API_DOCUMENTATION.md](./API_DOCUMENTATION.md)** - Complete API reference and endpoints
- **[API_MULTI_STORE_CHANGES.md](./API_MULTI_STORE_CHANGES.md)** - Mobile store context, pagination, and registration contract
- **[MOBILE_PROJECT_CONTEXT.md](./MOBILE_PROJECT_CONTEXT.md)** - Flutter shop-owner MVP and `/api/v1/mobile/*` overview
- **[FLUTTER_TENANT_WEB_PARITY_CHECKLIST.md](./FLUTTER_TENANT_WEB_PARITY_CHECKLIST.md)** - QA checklist: tenant mobile vs web dashboard parity
- **[GOOGLE_SIGNIN_TEST_TO_PRODUCTION_CHECKLIST.md](./GOOGLE_SIGNIN_TEST_TO_PRODUCTION_CHECKLIST.md)** - Release checklist for Google Sign-In (includes OAuth consent switch to Production)

### 🚀 **Deployment & Operations**
- **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** - Production deployment and hosting
- **[TROUBLESHOOTING_GUIDE.md](./TROUBLESHOOTING_GUIDE.md)** - Common issues and solutions

### 👥 **Administration**
- **[ADMIN_DOCUMENTATION.md](./ADMIN_DOCUMENTATION.md)** - Admin panel usage and management
- **[TENANT_GUIDE.md](./TENANT_GUIDE.md)** - Tenant-facing guide: dashboard features and storefront (share with store owners)
- **[CANVA_BRANDING_GUIDE.md](./CANVA_BRANDING_GUIDE.md)** - Brand details for Canva (name, colors, fonts, logo, tagline)

---

## 📁 **Project Structure**

```
dukanest/
├── docs/                          # 📚 Technical documentation
│   ├── README.md                  # This index
│   ├── ARCHITECTURE.md            # System architecture
│   ├── SECURITY.md                # Security implementation
│   ├── API_DOCUMENTATION.md       # API reference
│   ├── DEPLOYMENT_GUIDE.md        # Deployment guide
│   ├── TROUBLESHOOTING_GUIDE.md   # Troubleshooting
│   ├── ADMIN_DOCUMENTATION.md     # Admin documentation
│   └── PRISMA_EXPLANATION.md      # Database layer
├── src/                           # Application source code
├── supabase/                      # Database migrations
└── [other files]
```

---

## 🎯 **Quick Start**

### For Developers
1. **[Development Setup](../DEVELOPMENT.md)** - Complete development environment setup
2. **[System Architecture](./ARCHITECTURE.md)** - Understand the platform design
3. **[API Reference](./API_DOCUMENTATION.md)** - Integrate with the platform

### For Administrators
1. **[Admin Documentation](./ADMIN_DOCUMENTATION.md)** - Platform management
2. **[Deployment Guide](./DEPLOYMENT_GUIDE.md)** - Production setup

### For DevOps
1. **[Security Implementation](./SECURITY.md)** - Security architecture
2. **[Troubleshooting Guide](./TROUBLESHOOTING_GUIDE.md)** - Issue resolution

---

## 🔗 **Related Documentation**

- **[Project Overview](../README.md)** - High-level project information
- **[Development Guide](../DEVELOPMENT.md)** - Development environment setup
- **[Migration Roadmap](../../docs/NODEJS_MIGRATION_UPDATED.md)** - Platform migration guide
- **[Environment Setup](../../docs/ENV_SETUP_GUIDE.md)** - Configuration guide

---

## 📋 **Documentation Standards**

### ✅ **Best Practices Applied:**
- **Focused Scope:** Each document serves a specific purpose
- **Progressive Disclosure:** Start broad, dive deep when needed
- **Practical Examples:** Include working code and configurations
- **Security First:** Security considerations throughout
- **Maintainable:** Clear structure with regular updates

### 📝 **Maintenance:**
- Review quarterly for accuracy
- Update with latest best practices
- Keep content current with platform evolution
- Remove outdated information promptly

---

**🚀 Ready to work with DukaNest? Start with the [Development Setup](../DEVELOPMENT.md) or explore the [System Architecture](./ARCHITECTURE.md).**

**Last Updated:** January 2026

