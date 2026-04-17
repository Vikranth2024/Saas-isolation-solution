const express = require('express');
const router = express.Router();
const db = require('../db'); // Assuming basic pg pool

/**
 * GET /users
 * Returns users with tenant-isolation and RBAC field filtering.
 * Required: Auth middleware that sets req.user.tenantId and req.user.role
 */
router.get('/', async (req, res) => {
    try {
        const tenantId = req.user.tenantId; // Injected from JWT or session
        const currentUserRole = req.user.role;

        // CRITICAL: Mandatory tenant_id filter to prevent cross-tenant leaks
        const queryText = `
            SELECT id, email, full_name, role, salary, created_at, updated_at
            FROM users
            WHERE tenant_id = $1
            ORDER BY created_at DESC
        `;

        const { rows } = await db.query(queryText, [tenantId]);

        // RBAC: Data Sanitization / Map result before sending to client
        const filteredRows = rows.map(user => {
            const userView = { ...user };

            // Logic: Only 'admin' should see salary and card_last4 in the response.
            // Managers and Users get these fields removed to prevent privilege escalation.
            if (currentUserRole !== 'admin') {
                delete userView.salary; 
                delete userView.card_last4; // Even if joined from billing_details table
                
                // Inline comment: Prevent manager or user from viewing team financial secrets.
                // A senior mistake is forgetting this even with the WHERE clause.
            }

            return userView;
        });

        res.json({
            success: true,
            data: filteredRows
        });

    } catch (err) {
        console.error('Database Error:', err.message);
        res.status(500).json({ error: "Internal server error" });
    }
});

module.exports = router;
