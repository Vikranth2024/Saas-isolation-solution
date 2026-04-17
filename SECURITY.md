# CorpFlow SaaS Security Documentation (Post-Refactor)

**Senior Architect Review:** This document outlines the security controls implemented to solve the multi-tenant data leak risks in the original schema.

---

### **1. Case-Specific Sensitive Fields Table**

| Field Name | Table | Allowed Roles | Consequence of Over-exposure |
| :--- | :--- | :--- | :--- |
| `salary` | `users` | `admin` | **GDPR Violation.** Exposing employee salaries to colleagues or managers leads to internal conflict, lawsuits, and privacy breaches. |
| `card_last4` | `billing_details` | `admin` | **Financial Intelligence Leak.** While only 4 digits, this identifies which corporate card is being used; managers shouldn't track CEO/Company Owner payment methods. |
| `full_name` | `users` | `admin`, `manager`, `user` | **Low Risk.** Public record within the organization, but must still be restricted to the same `tenant_id`. |
| `email` | `users` | `admin`, `manager`, `user` | **Privacy Risk.** If exposed across tenants, helps attackers build phishing lists for specific target companies. |

---

### **2. Index Design Rationale**

| Index Header | Query Being Optimized | Scale at which unindexed becomes problematic |
| :--- | :--- | :--- |
| `idx_users_tenant_id` | `SELECT * FROM users WHERE tenant_id = $1` | **> 10k total records across all tenants.** Sequential scans will start to increase latency beyond 100ms. |
| `idx_users_email_tenant` | `SELECT * FROM users WHERE email = $1 AND tenant_id = $2` | **Login Route.** Without this, every login attempt triggers a full table scan. At 1m users, this crashes the DB server during morning peak hours. |
| `idx_projects_tenant_id` | `SELECT * FROM projects WHERE tenant_id = $1` | **Main Dashboard View.** A dashboard with 10 tables each lacking a `tenant_id` index will fail to load for enterprise customers with large datasets. |

---

### **3. Cross-Tenant Risk Review**

#### **Vector A: The Unqualified ID Exploit (IDOR)**
*   **Original Schema Permitted:** `GET /users/12345` would return a user even if the requester was from a different company, because the schema lacked a `tenant_id` association.
*   **New Prevention:** The new schema *and* the Node.js route enforce a `WHERE tenant_id = $1 AND id = $2` constraint. The server *only* looks in the tenant's own bucket. If the ID exists in another tenant, the DB returns "Not Found."

#### **Vector B: Account Hijacking via Email Collision**
*   **Original Schema Permitted:** An attacker could sign up for "Company B" using the email of the CEO of "Company A." If the developer didn't check for tenant-aware uniqueness, the CEO's account could be overwritten or the attacker could "ghost" into the wrong tenant.
*   **New Prevention:** The `UNIQUE(email, tenant_id)` constraint ensures that an email can exist in multiple companies independently, but cannot be duplicated within one organization. This allows for clean identity separation even in a shared table.

#### **Vector C: Global Search Information Disclosure**
*   **Original Schema Permitted:** A global `SELECT * FROM users WHERE full_name LIKE '%...%'` would leak names of every user at every company on the platform to anyone with an API key.
*   **New Prevention:** Every single queryΓÇöincluding search and paginationΓÇöis now forced through the `idx_users_tenant_id` index. The database treats the `tenant_id` as the primary filtering vector, ensuring that no data from other tenants ever enters the application's memory space.
