-- CorpFlow - PostgreSQL Multi-tenant SaaS Schema
-- Author: senior_architect_db_security

-- 1. Tenant Registry
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. User Table with Multi-tenant Isolation and RBAC
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    -- Strictly defined roles for application logic
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'manager', 'user')),
    -- Sensitive field: restrict at application layer
    salary NUMERIC(12, 2),
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    -- EMAIL+TENANT must be unique, allowing the same user to exist in multiple organizations
    UNIQUE(email, tenant_id)
);

-- 3. Projects Table
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    status VARCHAR(50) DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Billing Details Table
CREATE TABLE billing_details (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    -- Sensitive field: restricted to admin roles
    card_last4 VARCHAR(4) NOT NULL,
    card_type VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

--------------------------------------------------------------------------------
-- Index Design Strategy: "The Multi-tenant Performance Baseline"
--------------------------------------------------------------------------------

-- Composite index: Mandatory for cross-tenant isolation in every SELECT query
CREATE INDEX idx_users_tenant_id ON users(tenant_id);
CREATE INDEX idx_projects_tenant_id ON projects(tenant_id);
CREATE INDEX idx_billing_tenant_id ON billing_details(tenant_id);

-- Search Index: Optimize user lookups within a specific tenant
CREATE INDEX idx_users_email_tenant ON users(email, tenant_id);

-- Performance Index: Optimize sorting and pagination by creation date
CREATE INDEX idx_projects_created_at ON projects(created_at DESC);

-- COMMENT EXPLANATIONS
COMMENT ON COLUMN users.salary IS 'RESTRICTION: [ADMIN ONLY] - Manager and User roles should never see this in API responses.';
COMMENT ON COLUMN billing_details.card_last4 IS 'RESTRICTION: [ADMIN ONLY] - Billing data fragments must be scoped to organization owners.';
