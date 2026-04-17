# CorpFlow Schema Implementation - Evaluator Notes

**Evaluator:** senior_architect_db_security  
**Subject:** Rubric Criteria for Milestone 03

---

### **1. Tenant_ID Isolation (40%)**

*   **What a full-marks submission looks like:**
    *   Every table (except `tenants`) has a `tenant_id NOT NULL` column.
    *   All queries in the Node.js routes include `WHERE tenant_id = $1`.
    *   The `tenantId` is sourced from a secure server-side context (like `req.user.tenantId`), not passed as a query parameter from the client.
*   **What a common partial-credit mistake looks like:**
    *   Adding `tenant_id` to the `users` table but forgetting it on the `projects` or `billing_details` tables.
    *   Passing the `tenant_id` as a URI parameter `(GET /users?tenant_id=123)` which allows any user to change the ID in the URL to see another company's data.
*   **Code Diff Check:** Look at the `INSERT` and `UPDATE` queries. A real understanding ensures the `tenant_id` is automatically appended to all writes, not just reads.

---

### **2. RBAC Implementation (30%)**

*   **What a full-marks submission looks like:**
    *   A restricted `role` column exists with a database `CHECK (role IN (...))`.
    *   The API route (specifically `GET /users`) explicitly filters or deletes sensitive fields like `salary` based on the logged-in user's role before sending the response.
*   **What a common partial-credit mistake looks like:**
    *   Implementing roles in the application logic but allowing `SELECT *` to return every field to the client. The student expects the "Frontend" to hide the salary. This is a massive security failure.
*   **Code Diff Check:** Search for `delete user.salary` or a explicit `SELECT id, email, ...` whitelist. A surface-level fix will still return the `salary` field, even if it's empty.

---

### **3. Index Design (15%)**

*   **What a full-marks submission looks like:**
    *   Composite indexes on `(tenant_id, other_field)`.
    *   Foreign keys have dedicated indexes to prevent deadlock and performance degradation during cascading deletes.
*   **What a common partial-credit mistake looks like:**
    *   Adding a single index on `id` (which is already done by `PRIMARY KEY`) but ignoring the `tenant_id` which is the most frequent filter.
*   **Code Diff Check:** Check for `CREATE INDEX idx_... ON table(tenant_id)`. If this is missing, the schema is not "enterprise-ready."

---

### **4. SECURITY.md (15%)**

*   **What a full-marks submission looks like:**
    *   A document that explains *why* these changes were made.
    *   A specific identification of cross-tenant attack vectors (IDOR, Data Leakage).
*   **What a common partial-credit mistake looks like:**
    *   A one-sentence document saying "We added security." or just listing the tables without explaining the risk.
*   **Code Diff Check:** Does the document mention the word "Leak" or "Isolation"? A deep fix addresses the *business risk* of a data leak, not just the technical task.
