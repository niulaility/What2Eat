DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_type AS t
        JOIN pg_catalog.pg_namespace AS n ON n.oid = t.typnamespace
        WHERE n.nspname = 'public'
          AND t.typname = 'user_role'
    ) THEN
        CREATE TYPE public.user_role AS ENUM ('student', 'vendor', 'admin');
    END IF;
END;
$$;

ALTER TABLE public.profiles
    ALTER COLUMN role SET DEFAULT 'student'::public.user_role;

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_role public.user_role;
    v_university_id UUID;
    v_university TEXT;
    v_username TEXT;
BEGIN
    v_role := CASE NEW.raw_user_meta_data->>'role'
        WHEN 'customer' THEN 'student'::public.user_role
        WHEN 'student' THEN 'student'::public.user_role
        WHEN 'vendor' THEN 'vendor'::public.user_role
        WHEN 'admin' THEN 'admin'::public.user_role
        ELSE 'student'::public.user_role
    END;

    v_university := NULLIF(trim(NEW.raw_user_meta_data->>'university'), '');
    IF v_university IS NOT NULL THEN
        SELECT u.id
        INTO v_university_id
        FROM public.universities AS u
        WHERE u.code = v_university
           OR u.id::text = v_university
           OR u.name = v_university
        LIMIT 1;
    END IF;

    v_username := NULLIF(trim(NEW.raw_user_meta_data->>'username'), '');
    IF v_username IS NULL THEN
        v_username := pg_catalog.regexp_replace(
            pg_catalog.split_part(NEW.email, '@', 1),
            '[^A-Za-z0-9_]',
            '_',
            'g'
        );
    END IF;
    IF v_username !~ '^[A-Za-z][A-Za-z0-9_]{2,29}$' THEN
        RAISE EXCEPTION 'Signup username must start with a letter and contain 3 to 30 letters, digits, or underscores.'
            USING ERRCODE = '23514';
    END IF;

    INSERT INTO public.profiles (
        id,
        role,
        username,
        full_name,
        email,
        phone_number,
        avatar_url,
        terms_accepted
    )
    VALUES (
        NEW.id,
        v_role,
        v_username,
        NULLIF(trim(NEW.raw_user_meta_data->>'full_name'), ''),
        NEW.email,
        COALESCE(NULLIF(trim(NEW.raw_user_meta_data->>'phone_number'), ''), ''),
        NULLIF(NEW.raw_user_meta_data->>'avatar_url', ''),
        lower(COALESCE(NEW.raw_user_meta_data->>'terms_accepted', 'false')) = 'true'
    )
    ON CONFLICT (id) DO UPDATE SET
        role = EXCLUDED.role,
        username = EXCLUDED.username,
        full_name = EXCLUDED.full_name,
        email = EXCLUDED.email,
        phone_number = EXCLUDED.phone_number,
        avatar_url = EXCLUDED.avatar_url,
        terms_accepted = EXCLUDED.terms_accepted;

    IF v_role::text = 'student' THEN
        INSERT INTO public.customers (user_id, university_id)
        VALUES (NEW.id, v_university_id)
        ON CONFLICT (user_id) DO UPDATE SET
            university_id = EXCLUDED.university_id;
    END IF;

    RETURN NEW;
END;
$$;
