-- Profile module only. NOT applied automatically to any hosted project.
-- Review against the demo project's actual migrations 018-023 before applying.
-- Reuses profiles, customers, universities and avatars; no records/files deleted.
BEGIN;

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
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile public.profiles%ROWTYPE;
  v_university_id uuid;
  v_name text := btrim(coalesce(p_full_name, ''));
  v_username text := btrim(coalesce(p_username, ''));
  v_phone text := regexp_replace(btrim(coalesce(p_phone_number, '')), '[[:space:]()-]', '', 'g');
  v_email text;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Your profile is unavailable.' USING ERRCODE = '42501';
  END IF;
  IF p_expected_updated_at IS DISTINCT FROM v_profile.updated_at THEN
    RAISE EXCEPTION 'Your profile changed elsewhere. Reload before saving.' USING ERRCODE = '40001';
  END IF;
  IF char_length(v_name) NOT BETWEEN 2 AND 100 THEN
    RAISE EXCEPTION 'Full name must contain 2-100 characters.' USING ERRCODE = '22023';
  END IF;
  IF v_username !~ '^[A-Za-z][A-Za-z0-9_]{2,29}$' THEN
    RAISE EXCEPTION 'Invalid username.' USING ERRCODE = '22023';
  END IF;
  IF v_phone <> '' AND (v_phone !~ '^\+?[0-9]{8,15}$' OR replace(v_phone, '+', '') ~ '^([0-9])\1+$') THEN
    RAISE EXCEPTION 'Invalid phone number.' USING ERRCODE = '22023';
  END IF;

  IF v_profile.role::text = 'student' THEN
    SELECT university_id INTO v_university_id FROM public.customers WHERE user_id = v_user_id;
    IF p_university_id IS DISTINCT FROM v_university_id AND p_university_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.universities WHERE id = p_university_id AND is_active = true
    ) THEN
      RAISE EXCEPTION 'Choose an active university.' USING ERRCODE = '22023';
    END IF;
    v_university_id := p_university_id;
  ELSIF p_university_id IS NOT NULL THEN
    RAISE EXCEPTION 'Only students can change their personal university.' USING ERRCODE = '42501';
  END IF;

  -- Existing references may be retained. A changed reference must point to an
  -- existing image in this user's folder; arbitrary URLs are never accepted.
  IF p_avatar_path IS DISTINCT FROM v_profile.avatar_url AND p_avatar_path IS NOT NULL THEN
    IF char_length(p_avatar_path) > 512 OR p_avatar_path !~ (
      '^' || v_user_id::text || '/profile/[a-f0-9]{32}\.(jpg|png)$'
    ) OR NOT EXISTS (
      SELECT 1 FROM storage.objects WHERE bucket_id = 'avatars' AND name = p_avatar_path
    ) THEN
      RAISE EXCEPTION 'Invalid personal avatar.' USING ERRCODE = '22023';
    END IF;
  END IF;

  -- No client-supplied role, email, terms, business fields, or user ID.
  UPDATE public.profiles SET full_name = v_name, username = v_username,
    phone_number = v_phone, avatar_url = p_avatar_path,
    university_id = CASE WHEN role::text = 'student' THEN v_university_id ELSE university_id END
  WHERE id = v_user_id RETURNING * INTO v_profile;

  IF v_profile.role::text = 'student' THEN
    INSERT INTO public.customers (user_id, university_id) VALUES (v_user_id, v_university_id)
    ON CONFLICT (user_id) DO UPDATE SET university_id = excluded.university_id;
  END IF;
  SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;
  RETURN jsonb_build_object(
    'id', v_profile.id, 'role', v_profile.role, 'full_name', v_profile.full_name,
    'username', v_profile.username, 'email', v_email,
    'phone_number', v_profile.phone_number, 'avatar_url', v_profile.avatar_url,
    'university_id', v_university_id, 'updated_at', v_profile.updated_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.update_my_personal_profile(text,text,text,uuid,text,timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_my_personal_profile(text,text,text,uuid,text,timestamptz) TO authenticated;
-- Preserve migration 010's protection of profile roles and sign-in email.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.profiles FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.profiles TO authenticated;

-- Ordinary users can only read their own private personal profile.
DROP POLICY IF EXISTS "Profiles are viewable by authenticated users" ON public.profiles;
CREATE POLICY "Own personal profile or administrator read" ON public.profiles
  FOR SELECT TO authenticated USING (id = auth.uid() OR public.is_admin());

-- Make the existing avatar bucket private without deleting or replacing it.
UPDATE storage.buckets SET public = false, file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png']::text[] WHERE id = 'avatars';
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'avatars') THEN
    RAISE EXCEPTION 'Existing avatars bucket is required; review the baseline schema.';
  END IF;
END $$;
DROP POLICY IF EXISTS "Avatars are publicly accessible" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
CREATE POLICY "Read own private avatar" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY "Insert own personal avatar" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'avatars' AND name ~ (
    '^' || auth.uid()::text || '/profile/[a-f0-9]{32}\.(jpg|png)$'
  ));
-- Replacement uses a new random object path; removal only unlinks the profile.
-- No UPDATE/DELETE policies or broad storage grants are introduced.
COMMIT;
