-- ==============================================================================
-- What2Eat Migration 24: Clean User Profile Editing & Public Avatars
-- Allows:
--   - Students, Vendors, and Admins to edit their own profile information
--   - Safe avatar uploads with public reading for smooth Flutter image loading
--   - Protection of sensitive fields (role, email, is_active) from unauthorized tampering
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. DROP RESTRICTIVE POLICIES & OBSOLETE FUNCTIONS
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.update_my_personal_profile;
DROP POLICY IF EXISTS "Own personal profile or administrator read" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are viewable by authenticated users" ON public.profiles;
DROP POLICY IF EXISTS "Users can update only their own profile" ON public.profiles;

-- ------------------------------------------------------------------------------
-- 2. PROFILE READ ACCESS (Required for menus, chat, and vendor listings)
-- ------------------------------------------------------------------------------
CREATE POLICY "Profiles are viewable by authenticated users"
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (true);

-- ------------------------------------------------------------------------------
-- 3. PROFILE UPDATE ACCESS (Self-editing)
-- ------------------------------------------------------------------------------
GRANT UPDATE(full_name, phone_number, avatar_url, university_id) 
    ON public.profiles TO authenticated;

CREATE POLICY "Users can update only their own profile"
    ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- ------------------------------------------------------------------------------
-- 4. SECURITY TRIGGER: Protect Immutable/Privileged Fields
-- Prevents users from escalating their role to admin, changing email directly,
-- or bypassing suspension flags (is_active)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_sensitive_profile_fields()
RETURNS TRIGGER AS $$
BEGIN
    -- If not an administrator, prevent changes to sensitive account fields
    IF NOT public.is_admin() THEN
        NEW.id := OLD.id;
        NEW.role := OLD.role;
        NEW.email := OLD.email;
        IF OLD.is_active IS NOT NULL THEN
            NEW.is_active := OLD.is_active;
        END IF;
        NEW.created_at := OLD.created_at;
    END IF;
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_protect_profile_fields ON public.profiles;
CREATE TRIGGER trigger_protect_profile_fields
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.protect_sensitive_profile_fields();

-- ------------------------------------------------------------------------------
-- 5. AVATARS STORAGE BUCKET CONFIGURATION
-- Keep bucket public so user and vendor pictures display instantly in Flutter
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,
    5242880, -- 5 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

DROP POLICY IF EXISTS "Read own private avatar" ON storage.objects;
DROP POLICY IF EXISTS "Insert own personal avatar" ON storage.objects;
DROP POLICY IF EXISTS "Avatars are publicly accessible" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;

CREATE POLICY "Avatars are publicly accessible"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');

CREATE POLICY "Users can upload their own avatar"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "Users can update their own avatar"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
