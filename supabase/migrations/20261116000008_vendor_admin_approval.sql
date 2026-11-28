-- Vendor applications remain pending until an administrator reviews them.
ALTER TABLE public.vendors
    ALTER COLUMN is_active SET DEFAULT false;

UPDATE public.vendors
SET is_active = false
WHERE status <> 'approved'::public.vendor_status;

-- Remove broad policies from earlier versions, including names used by the
-- dashboard when the schema was edited manually.
DROP POLICY IF EXISTS "Approved vendors are viewable by everyone" ON public.vendors;
DROP POLICY IF EXISTS "Vendors can insert their own application" ON public.vendors;
DROP POLICY IF EXISTS "Vendors can update their own business information" ON public.vendors;
DROP POLICY IF EXISTS "Vendors can update their own application" ON public.vendors;
DROP POLICY IF EXISTS "Admins can update vendor applications" ON public.vendors;
DROP POLICY IF EXISTS "Vendors and admins can view vendor applications" ON public.vendors;
DROP POLICY IF EXISTS "Users can submit their own pending vendor application" ON public.vendors;
DROP POLICY IF EXISTS "Vendors can edit their own pending application" ON public.vendors;

CREATE POLICY "Vendors and admins can view vendor applications"
    ON public.vendors FOR SELECT TO authenticated
    USING (
        auth.uid() = user_id
        OR public.is_admin()
        OR status = 'approved'::public.vendor_status
    );

CREATE POLICY "Users can submit their own pending vendor application"
    ON public.vendors FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = user_id
        AND status = 'pending'::public.vendor_status
        AND is_active = false
        AND reviewed_at IS NULL
        AND rejection_reason IS NULL
        AND EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.role::text = 'vendor'
        )
    );

-- Owners may correct application details while it is pending, but cannot
-- approve, reject, activate, or mark it reviewed themselves.
CREATE POLICY "Vendors can edit their own pending application"
    ON public.vendors FOR UPDATE TO authenticated
    USING (
        auth.uid() = user_id
        AND status = 'pending'::public.vendor_status
    )
    WITH CHECK (
        auth.uid() = user_id
        AND status = 'pending'::public.vendor_status
        AND is_active = false
        AND reviewed_at IS NULL
        AND rejection_reason IS NULL
    );

GRANT SELECT, INSERT, UPDATE ON public.vendors TO authenticated;

-- The only status transition is this administrator-only RPC.
CREATE OR REPLACE FUNCTION public.review_vendor_application(
    p_vendor_id uuid,
    p_decision text,
    p_rejection_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_decision public.vendor_status;
    v_reason text := NULLIF(pg_catalog.btrim(p_rejection_reason), '');
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only administrators can review vendor applications'
            USING ERRCODE = '42501';
    END IF;

    IF p_decision NOT IN ('approved', 'rejected') THEN
        RAISE EXCEPTION 'Decision must be approved or rejected'
            USING ERRCODE = '22023';
    END IF;

    IF p_decision = 'rejected' AND v_reason IS NULL THEN
        RAISE EXCEPTION 'A reason is required when rejecting an application'
            USING ERRCODE = '22023';
    END IF;

    v_decision := p_decision::public.vendor_status;

    UPDATE public.vendors
    SET status = v_decision,
        is_active = (v_decision = 'approved'::public.vendor_status),
        rejection_reason = CASE WHEN v_decision = 'rejected'::public.vendor_status
                                THEN v_reason ELSE NULL END,
        reviewed_at = pg_catalog.now()
    WHERE id = p_vendor_id
      AND status = 'pending'::public.vendor_status;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vendor application does not exist or is no longer pending'
            USING ERRCODE = 'P0002';
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.review_vendor_application(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.review_vendor_application(uuid, text, text) TO authenticated;

-- Custom Access Token Hook: pending and rejected vendors cannot obtain new
-- access tokens or refresh tokens. A vendor with no application row is allowed
-- through so the app can sign in immediately after server-side account creation
-- and finish saving the application.
CREATE OR REPLACE FUNCTION public.enforce_vendor_approval_for_auth(input_event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid := NULLIF(input_event->'claims'->>'sub', '')::uuid;
    v_role text;
    v_status public.vendor_status;
    v_is_active boolean;
BEGIN
    SELECT p.role::text INTO v_role
    FROM public.profiles p
    WHERE p.id = v_user_id;

    IF v_role = 'vendor' THEN
        SELECT v.status, v.is_active
        INTO v_status, v_is_active
        FROM public.vendors v
        WHERE v.user_id = v_user_id;

        IF FOUND AND v_status = 'rejected'::public.vendor_status THEN
            RETURN pg_catalog.jsonb_build_object(
                'error', pg_catalog.jsonb_build_object(
                    'http_code', 403,
                    'message', 'Your vendor application was rejected. Please contact What2Eat for assistance.'
                )
            );
        END IF;

        IF FOUND AND (v_status <> 'approved'::public.vendor_status OR NOT v_is_active) THEN
            RETURN pg_catalog.jsonb_build_object(
                'error', pg_catalog.jsonb_build_object(
                    'http_code', 403,
                    'message', 'Your vendor application is awaiting administrator approval.'
                )
            );
        END IF;
    END IF;

    RETURN input_event;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_vendor_approval_for_auth(jsonb) FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.enforce_vendor_approval_for_auth(jsonb) TO supabase_auth_admin;

DROP POLICY IF EXISTS "Admins can view vendor application files" ON storage.objects;
CREATE POLICY "Admins can view vendor application files"
    ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'vendor-documents' AND public.is_admin());
