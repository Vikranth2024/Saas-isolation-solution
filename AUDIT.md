# CorpFlow Schema Security & Architecture Audit

**Auditor:** senior_architect_db_security  
**Date:** March 18, 2026  
**Subject:** Pre-refactor analysis of CorpFlow monolith schema.

---

### **Overview**
The current schema is a "Single Point of Failure" waiting to happen. It treats multi-tenant data as one large bucket without logical or physical isolation. This architecture is reminiscent of the 2014-era startup design that leads to catastrophic data leaks once the first large enterprise customer joins.

### **Critical Findings**

#### 1. Missing `tenant_id` on Business Entities
*   **Location:** `users`, `projects`, `billing_details` tables.
*   **Problem:** There is no identifier linking records to a specific customer (tenant). All records coexist in the same flat table space.
*   **Consequence:** A simple `SELECT * FROM users` returns every user from every company using the platform. Without this, cross-tenant data leaks are not a possibility; they are the default behavior.

#### 2. Absence of Composite Foreign Key Indexes
*   **Location:** Every table (FK relationships).
*   **Problem:** No indexes exist on the columns used to join tables or filter by owner.
*   **Consequence:** As the platform grows, simple dashboard queries will degrade from milliseconds to seconds, eventually timing out the application. At 100k+ users, a sequential scan on a non-indexed column will spike CPU to 100% and take down the primary node.

#### 3. "SELECT *" and Sensitive Data Exposure
*   **Location:** `routes/users.js`, `routes/projects.js`.
*   **Problem:** API routes perform unqualified selects and return entire row objects directly to the client.
*   **Consequence:** Fields like `salary`, `social_security_number`, and `card_last4` are sent to the frontend even when the logged-in user doesn't have the permissions to see them. A "User" role seeing a "CEO"'s salary is a GDPR violation and a terminal event for the product's reputation.

#### 4. Unconstrained User Roles
*   **Location:** `users.role` column.
*   **Problem:** The `role` column is a simple `VARCHAR` with no `CHECK` constraint or `ENUM` type.
*   **Consequence:** Garbage data like 'super-admin', 'boss', or 'null' can be inserted, breaking the RBAC logic in the backend. Worse, it relies solely on application-level strings which is prone to typos (e.g., 'manger' vs 'manager').

#### 5. Non-Unique Identity Across Tenants
*   **Location:** `users.email` column.
*   **Problem:** Missing a `UNIQUE(email, tenant_id)` constraint.
*   **Consequence:** In a SaaS environment, the same user might belong to multiple tenants. Without a tenant-aware unique constraint, a user cannot join a second organization with the same email, or worse, their identity might collide with a user from a completely different company.

#### 6. Plaintext Storage of Sensitive Financial Data
*   **Location:** `billing_details` table.
*   **Problem:** Credit card fragments and billing info are stored alongside general application data without specific access controls.
*   **Consequence:** Any developer with read-access to the database can see billing internals. In the event of an SQL injection, the attacker exfiltrates cleartext financial data rather than encrypted blobs.

#### 7. Missing Created/Updated Metadata
*   **Location:** All tables.
*   **Problem:** No `created_at` or `updated_at` timestamps.
*   **Consequence:** Impossible to perform forensic audits after a security incident. When was this user created? We don't know. When was this project modified? No record exists. This makes debugging "who changed what" a nightmare.

#### 8. Global Scope in Search Queries
*   **Location:** `GET /users/search` (implied).
*   **Problem:** Search queries do not append a mandatory tenant filter in the `WHERE` clause.
*   **Consequence:** A user searching for "John" will see every "John" across all customers of CorpFlow, not just their colleagues. This is the "3am data leak" I've seen take down companies.
