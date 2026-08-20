# Incident Log

Real debugging incidents encountered while building the Order Management & Billing System, along with root cause and fix.

---

### Incident 1: Duplicate trigger caused ORA-04098 on every order change

**Symptom:** Every INSERT/UPDATE/DELETE on `walmart_orders` started failing with `ORA-04098: trigger 'GOPI.WALMART_LOGS' is invalid and failed re-validation`, even though the newly written audit trigger appeared to compile and work correctly.

**Root cause:** The first trigger attempt (named `walmart_logs`, the same name as the table itself) had syntax errors — including missing semicolons — and never reached a `VALID` state. A `CREATE OR REPLACE` with errors still creates the object in the schema, just marked `INVALID`; it doesn't fail outright or leave nothing behind. When the corrected version was written, it was saved under a different name (`walmart_logs_trg`) instead of replacing the broken one. Oracle fires every trigger defined on a table for a given DML event — not just the working one — so the invalid `walmart_logs` trigger kept trying to fire alongside the correct one, throwing `ORA-04098` on every operation.

**Fix:** Identified the duplicate via:
```sql
SELECT trigger_name, status FROM user_triggers WHERE table_name = 'WALMART_ORDERS';
```
then dropped the broken trigger: `DROP TRIGGER walmart_logs;`. Only the valid, corrected trigger remained afterward, and normal DML resumed working.

**Lesson:** Multiple triggers on one table is normal and often necessary — the bug wasn't having two triggers, it was leaving an invalid one behind instead of cleaning it up when it was superseded. After any `CREATE OR REPLACE`, check `user_errors` immediately for compile issues, and explicitly drop any broken/abandoned attempt before moving on to a renamed or corrected version.

---

### Incident 2: Batch job silently skipped a stale order due to uncommitted test data

**Symptom:** Backdated a test order's `order_date` to simulate a stale `PENDING` order, then ran `batch_cancel_stale_orders`. The procedure completed with no error ("PL/SQL procedure successfully completed"), but the order's status remained `PENDING` instead of flipping to `CANCELLED`.

**Root cause:** The `UPDATE` that backdated `order_date` was never followed by a `COMMIT`. In Oracle, changes made in a transaction are only visible within that same active transaction until `COMMIT` is issued — any other query only sees the last committed state of the data. Since the backdated date was never committed, the batch job's `SELECT` (`WHERE order_status = 'PENDING' AND order_date` more than 1 day old) still saw the original, non-stale `order_date` and correctly found nothing to act on. No exception was raised because nothing was actually wrong from the database's point of view — the query simply found zero matching rows.

**Fix:** Re-ran the `UPDATE`, issued `COMMIT` immediately afterward, then ran `batch_cancel_stale_orders` again. The order was correctly picked up and cancelled, confirming the procedure's logic was correct all along — the issue was purely test-data visibility, not application logic.

**Lesson:** Any INSERT, UPDATE, or DELETE needs an explicit `COMMIT` before its effects are reliably visible to subsequent queries or procedure calls that depend on it, even within the same working session if the transaction context has reset in between. Worth adopting a habit of committing immediately after any data-changing statement during testing, before running whatever depends on it next.

---

### Incident 3: FK constraint creation failed due to Oracle identifier length limit

**Symptom:** Generated DDL from the ER diagram tool included multiple `ALTER TABLE ... ADD CONSTRAINT` statements for foreign keys, several of which failed with `FK name length exceeds maximum allowed length (30)` during generation — e.g. `walmart_orderitems_walmart_orders_fk` (37 characters).

**Root cause:** Oracle (targeting 11g in this project) enforces a 30-character limit on all object identifiers, including constraint names. The auto-generated naming convention concatenated both table names plus `_fk` for every foreign key, which stayed under the limit for short table-name pairs but exceeded it once table names carried a shared prefix repeated on both sides of the join.

**Fix:** Manually shortened each foreign key constraint name to fit within 30 characters, using a consistent, briefer pattern (e.g. `walmart_orderitems_fk2`, `walmart_orders_fk1`) instead of the auto-generated full concatenation. Verified the fix by regenerating the DDL and confirming the tool's own error summary reported zero errors, then re-ran it against the local Oracle instance to confirm it executed cleanly.

**Lesson:** Auto-generated names from modeling tools aren't guaranteed to respect database-specific limits, especially as schema naming conventions grow. Worth checking generated DDL for identifier length issues before treating a tool's "no visible error" output as final — the tool's own summary report (`errors: 0`) is the reliable confirmation, not just a visual scan of the script.
