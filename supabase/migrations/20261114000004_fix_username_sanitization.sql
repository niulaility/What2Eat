-- Migration 4: Fix handle_new_auth_user trigger to sanitize auto-generated usernames
-- Problem: email prefixes like "admin.what2eat" contain dots which fail the
--          username_format_check constraint (^[A-Za-z][A-Za-z0-9_]{2,29}$)
-- Fix: strip invalid characters from auto-generated usernames using regexp_replace

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER AS $$
DECLARE
    v_role user_role;
    v_uni_id UUID;
    v_uni_code TEXT;
    v_username TEXT;
BEGIN
    v_role := COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'student');
    v_uni_code := NEW.raw_user_meta_data->>'university';

    IF v_uni_code IS NOT NULL THEN
        SELECT id INTO v_uni_id 
        FROM public.universities 
        WHERE code = v_uni_code OR id::text = v_uni_code OR name = v_uni_code
        LIMIT 1;
    END IF;

    -- Sanitize username: replace invalid chars with underscore
    v_username := COALESCE(
        NEW.raw_user_meta_data->>'username',
        regexp_replace(split_part(NEW.email, '@', 1), '[^A-Za-z0-9_]', '_', 'g')
    );
    -- If it still doesn't start with a letter, prepend 'u_'
    IF v_username !~ '^[A-Za-z]' THEN
        v_username := 'u_' || v_username;
    END IF;

    INSERT INTO public.profiles (
        id, role, username, full_name, email,
        phone_number, avatar_url, terms_accepted
    )
    VALUES (
        NEW.id,
        v_role,
        v_username,
        NEW.raw_user_meta_data->>'full_name',
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'phone_number', ''),
        NEW.raw_user_meta_data->>'avatar_url',
        COALESCE((NEW.raw_user_meta_data->>'terms_accepted')::boolean, false)
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone_number = EXCLUDED.phone_number,
        avatar_url = EXCLUDED.avatar_url;

    IF v_role = 'student' THEN
        INSERT INTO public.customers (user_id, university_id)
        VALUES (NEW.id, v_uni_id)
        ON CONFLICT (user_id) DO UPDATE SET university_id = EXCLUDED.university_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
