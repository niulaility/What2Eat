-- ==============================================================================
-- W2E-32: Administrators must be able to read submitted vendor documents.
--
-- The hosted project had drifted to an owner-only SELECT policy
-- ("Vendors can view their own documents"), so the admin review screen saw
-- every application with zero documents. Replace any existing SELECT policy
-- with the intended owner-or-administrator rule. Safe to re-run.
-- ==============================================================================

DROP POLICY IF EXISTS "Vendors can view their own documents" ON public.vendor_documents;
DROP POLICY IF EXISTS "Vendors and admins can view their own documents" ON public.vendor_documents;

CREATE POLICY "Vendors and admins can view their own documents"
    ON public.vendor_documents
    FOR SELECT
    TO authenticated
    USING (
        public.is_admin()
        OR EXISTS (
            SELECT 1 FROM public.vendors
            WHERE vendors.id = vendor_documents.vendor_id
              AND vendors.user_id = auth.uid()
        )
    );
