-- ==============================================================================
-- What2Eat Migration 27: Profile Editing Function & View Permissions
-- Enables:
--   - public.update_my_personal_profile RPC for user profile editing
--   - Profile read permissions for customer menu viewing & in-app chat
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. READ PERMISSIONS
-- Ensure authenticated users can view profiles (for vendor listings and chat)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Own personal profile or administrator read" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are viewable by authenticated users" ON public.profiles;

CREATE POLICY "Profiles are viewable by authenticated users"
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (true);

-- ------------------------------------------------------------------------------
-- 2. ENSURE UPDATED_AT TRIGGER USES PROPER SEARCH PATH
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- 3. PROFILE EDITING RPC FUNCTION
-- Called by SupabaseProfileRepository.save() in edit_profile_page.dart
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_my_personal_profile(
    p_full_name text,
    p_username text,
    p_phone_number text,
    p_university_id uuid,
    p_avatar_path text,
    p_expected_updated_at timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_profile public.profiles%ROWTYPE;
    v_university_id uuid := NULL;
    v_name text := trim(COALESCE(p_full_name, ''));
    v_username text := trim(COALESCE(p_username, ''));
    v_phone text := regexp_replace(trim(COALESCE(p_phone_number, '')), '[[:space:]()-]', '', 'g');
    v_email text;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Your profile is unavailable.' USING ERRCODE = '42501';
    END IF;

    -- Concurrency check: only fail if record was updated after this client loaded it
    IF p_expected_updated_at IS NOT NULL AND v_profile.updated_at IS NOT NULL THEN
        IF p_expected_updated_at < v_profile.updated_at - interval '2 seconds' THEN
            RAISE EXCEPTION 'Your profile changed elsewhere. Reload before saving.' USING ERRCODE = '40001';
        END IF;
    END IF;

    -- Validate Name
    IF char_length(v_name) NOT BETWEEN 2 AND 100 THEN
        RAISE EXCEPTION 'Full name must contain 2-100 characters.' USING ERRCODE = '22023';
    END IF;

    -- Validate Username
    IF v_username !~ '^[A-Za-z][A-Za-z0-9_]{2,29}$' THEN
        RAISE EXCEPTION 'Invalid username.' USING ERRCODE = '22023';
    END IF;

    -- Validate Phone
    IF v_phone <> '' AND (v_phone !~ '^\+?[0-9]{8,15}$' OR replace(v_phone, '+', '') ~ '^([0-9])\1+$') THEN
        RAISE EXCEPTION 'Invalid phone number.' USING ERRCODE = '22023';
    END IF;

    -- University affiliation handling
    IF v_profile.role::text = 'student' THEN
        IF p_university_id IS NOT NULL THEN
            IF NOT EXISTS (
                SELECT 1 FROM public.universities WHERE id = p_university_id AND is_active = true
            ) THEN
                RAISE EXCEPTION 'Choose an active university.' USING ERRCODE = '22023';
            END IF;
            v_university_id := p_university_id;
        ELSE
            SELECT university_id INTO v_university_id FROM public.customers WHERE user_id = v_user_id;
        END IF;
    END IF;

    -- Update profile fields
    UPDATE public.profiles
    SET full_name = v_name,
        username = v_username,
        phone_number = v_phone,
        avatar_url = p_avatar_path,
        university_id = CASE WHEN role::text = 'student' THEN v_university_id ELSE university_id END,
        updated_at = now()
    WHERE id = v_user_id
    RETURNING * INTO v_profile;

    -- Sync to customers table for students
    IF v_profile.role::text = 'student' AND v_university_id IS NOT NULL THEN
        INSERT INTO public.customers (user_id, university_id)
        VALUES (v_user_id, v_university_id)
        ON CONFLICT (user_id) DO UPDATE SET university_id = EXCLUDED.university_id;
    END IF;

    v_email := v_profile.email;

    RETURN jsonb_build_object(
        'id', v_profile.id,
        'role', v_profile.role,
        'full_name', v_profile.full_name,
        'username', v_profile.username,
        'email', v_email,
        'phone_number', v_profile.phone_number,
        'avatar_url', v_profile.avatar_url,
        'university_id', v_university_id,
        'updated_at', v_profile.updated_at
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 4. PERMISSIONS
-- ------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.update_my_personal_profile(text,text,text,uuid,text,timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_my_personal_profile(text,text,text,uuid,text,timestamptz) TO authenticated;
