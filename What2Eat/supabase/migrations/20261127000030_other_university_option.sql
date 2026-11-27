-- ==============================================================================
-- What2Eat Migration 30: "Other university" as a regular university
-- Supports:
--   - Students and vendors choosing "Other university" like any campus
--   - Students on "Other university" discovering vendors that serve it
--   - Vendors editing their served universities after approval (atomic RPC)
-- ==============================================================================

-- 1. The "Other university" directory entry. The app lists code 'other' last.
INSERT INTO public.universities (code, name, is_active)
VALUES ('other', 'Other university', true)
ON CONFLICT (code) DO UPDATE SET is_active = true;

-- 2. Students saved with no university were "Other / not listed": link them.
UPDATE public.customers
SET university_id = (SELECT id FROM public.universities WHERE code = 'other')
WHERE university_id IS NULL;

UPDATE public.profiles
SET university_id = (SELECT id FROM public.universities WHERE code = 'other')
WHERE role = 'student' AND university_id IS NULL;

-- 3. Vendor self-service: replace served universities in one transaction.
-- Approved vendors cannot UPDATE public.vendors, and doing add/remove from the
-- client is not atomic, so this SECURITY DEFINER function changes only the
-- caller's own vendor_universities rows.
CREATE OR REPLACE FUNCTION public.update_my_served_universities(
    p_university_ids uuid[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_vendor_id uuid;
    v_ids uuid[] := COALESCE(p_university_ids, '{}'::uuid[]);
BEGIN
    SELECT v.id INTO v_vendor_id
    FROM public.vendors v
    WHERE v.user_id = auth.uid();

    IF v_vendor_id IS NULL THEN
        RAISE EXCEPTION 'Your vendor business record could not be found.'
            USING ERRCODE = '42501';
    END IF;

    IF pg_catalog.cardinality(v_ids) = 0 THEN
        RAISE EXCEPTION 'Select at least one university.'
            USING ERRCODE = '22023';
    END IF;

    -- Each university must be active, or already linked (so a vendor can keep
    -- a campus that was deactivated later).
    IF EXISTS (
        SELECT 1
        FROM pg_catalog.unnest(v_ids) AS x(id)
        WHERE NOT EXISTS (
                SELECT 1 FROM public.universities u
                WHERE u.id = x.id AND u.is_active
            )
          AND NOT EXISTS (
                SELECT 1 FROM public.vendor_universities vu
                WHERE vu.vendor_id = v_vendor_id AND vu.university_id = x.id
            )
    ) THEN
        RAISE EXCEPTION 'Choose active universities only.'
            USING ERRCODE = '22023';
    END IF;

    DELETE FROM public.vendor_universities
    WHERE vendor_id = v_vendor_id
      AND university_id <> ALL (v_ids);

    INSERT INTO public.vendor_universities (vendor_id, university_id)
    SELECT DISTINCT v_vendor_id, x.id
    FROM pg_catalog.unnest(v_ids) AS x(id)
    ON CONFLICT (vendor_id, university_id) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.update_my_served_universities(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_my_served_universities(uuid[]) TO authenticated;
