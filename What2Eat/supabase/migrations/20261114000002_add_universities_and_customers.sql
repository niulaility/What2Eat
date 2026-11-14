-- ==============================================================================
-- Migration 02: Add Universities Management, Customer Profiles & Vendor Universities
-- Applies on top of 20261114000001
-- ==============================================================================

-- 1. HELPER FUNCTION: is_admin()
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- 2. CREATE TABLE: universities
-- Managed by Admins (Add, Edit, Activate/Deactivate)
-- Read by Students & Vendors (Only active ones selectable)
CREATE TABLE IF NOT EXISTS public.universities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL UNIQUE,
    city TEXT,
    state TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Drop logo_url or updated_at if they were created earlier
ALTER TABLE public.universities DROP COLUMN IF EXISTS logo_url;
ALTER TABLE public.universities DROP COLUMN IF EXISTS updated_at;

CREATE INDEX IF NOT EXISTS idx_universities_code ON public.universities(code);
CREATE INDEX IF NOT EXISTS idx_universities_is_active ON public.universities(is_active);

-- Seed initial universities from current Flutter UI
INSERT INTO public.universities (code, name, state, is_active)
VALUES
    ('utm', 'Universiti Teknologi Malaysia', 'Johor', true),
    ('um', 'Universiti Malaya', 'Kuala Lumpur', true),
    ('upm', 'Universiti Putra Malaysia', 'Selangor', true),
    ('ukm', 'Universiti Kebangsaan Malaysia', 'Selangor', true),
    ('usm', 'Universiti Sains Malaysia', 'Penang', true),
    ('uitm', 'Universiti Teknologi MARA', 'Selangor', true)
ON CONFLICT (code) DO NOTHING;

-- 3. LINK profiles TO universities
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'profiles' 
          AND column_name = 'university_id'
    ) THEN
        ALTER TABLE public.profiles 
        ADD COLUMN university_id UUID REFERENCES public.universities(id) ON DELETE SET NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_profiles_university_id ON public.profiles(university_id);

-- 4. CREATE TABLE: customers (Student / Customer Specific Profile)
-- Stores student affiliation to active university
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    university_id UUID REFERENCES public.universities(id) ON DELETE SET NULL
);

-- Drop unneeded columns if present
ALTER TABLE public.customers DROP COLUMN IF EXISTS matric_number;
ALTER TABLE public.customers DROP COLUMN IF EXISTS campus_residence;
ALTER TABLE public.customers DROP COLUMN IF EXISTS created_at;
ALTER TABLE public.customers DROP COLUMN IF EXISTS updated_at;

CREATE INDEX IF NOT EXISTS idx_customers_user_id ON public.customers(user_id);
CREATE INDEX IF NOT EXISTS idx_customers_university_id ON public.customers(university_id);

-- 5. CREATE TABLE: vendor_universities (Junction Table)
-- Vendors select one or multiple active universities they serve
CREATE TABLE IF NOT EXISTS public.vendor_universities (
    vendor_id UUID NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
    university_id UUID NOT NULL REFERENCES public.universities(id) ON DELETE CASCADE,
    PRIMARY KEY (vendor_id, university_id)
);

CREATE INDEX IF NOT EXISTS idx_vendor_universities_vendor ON public.vendor_universities(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_universities_uni ON public.vendor_universities(university_id);

-- 6. CLEAN UP VENDORS TIMESTAMPS
-- submitted_at and reviewed_at remain the true lifecycle timestamps
ALTER TABLE public.vendors DROP COLUMN IF EXISTS created_at;
ALTER TABLE public.vendors DROP COLUMN IF EXISTS updated_at;
DROP TRIGGER IF EXISTS trigger_vendors_updated_at ON public.vendors;

-- 7. UPDATE AUTOMATIC USER SYNC TRIGGER
-- Automatically creates public.profiles and public.customers on student sign-up
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER AS $$
DECLARE
    v_role user_role;
    v_uni_id UUID;
    v_uni_code TEXT;
BEGIN
    v_role := COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'student');
    v_uni_code := NEW.raw_user_meta_data->>'university';
    
    -- Look up university_id if university code or ID was passed
    IF v_uni_code IS NOT NULL THEN
        SELECT id INTO v_uni_id 
        FROM public.universities 
        WHERE code = v_uni_code OR id::text = v_uni_code OR name = v_uni_code
        LIMIT 1;
    END IF;

    -- 1. Insert Base Profile
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
        COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
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

    -- 2. If student/customer, automatically create student profile
    IF v_role = 'student' THEN
        INSERT INTO public.customers (
            user_id,
            university_id
        )
        VALUES (
            NEW.id,
            v_uni_id
        )
        ON CONFLICT (user_id) DO UPDATE SET
            university_id = EXCLUDED.university_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.universities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_universities ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- UNIVERSITIES POLICIES
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public can view active universities; Admins can view all" ON public.universities;
CREATE POLICY "Public can view active universities; Admins can view all"
    ON public.universities
    FOR SELECT
    USING (is_active = true OR public.is_admin());

DROP POLICY IF EXISTS "Only admins can add universities" ON public.universities;
CREATE POLICY "Only admins can add universities"
    ON public.universities
    FOR INSERT
    TO authenticated
    WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Only admins can update universities" ON public.universities;
CREATE POLICY "Only admins can update universities"
    ON public.universities
    FOR UPDATE
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Only admins can delete universities" ON public.universities;
CREATE POLICY "Only admins can delete universities"
    ON public.universities
    FOR DELETE
    TO authenticated
    USING (public.is_admin());

-- ------------------------------------------------------------------------------
-- CUSTOMERS POLICIES (Student Profile)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Customers can view their own customer profile" ON public.customers;
CREATE POLICY "Customers can view their own customer profile"
    ON public.customers
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id OR public.is_admin());

DROP POLICY IF EXISTS "Customers can insert their own customer profile" ON public.customers;
CREATE POLICY "Customers can insert their own customer profile"
    ON public.customers
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Customers can update their own customer profile" ON public.customers;
CREATE POLICY "Customers can update their own customer profile"
    ON public.customers
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id OR public.is_admin())
    WITH CHECK (auth.uid() = user_id OR public.is_admin());

-- ------------------------------------------------------------------------------
-- VENDOR UNIVERSITIES POLICIES
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Vendor universities are viewable by authenticated users" ON public.vendor_universities;
CREATE POLICY "Vendor universities are viewable by authenticated users"
    ON public.vendor_universities
    FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Vendors can link active universities to their kitchen" ON public.vendor_universities;
CREATE POLICY "Vendors can link active universities to their kitchen"
    ON public.vendor_universities
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.vendors
            WHERE vendors.id = vendor_universities.vendor_id
              AND vendors.user_id = auth.uid()
        )
        AND
        EXISTS (
            SELECT 1 FROM public.universities
            WHERE universities.id = vendor_universities.university_id
              AND universities.is_active = true
        )
    );

DROP POLICY IF EXISTS "Vendors can remove universities from their kitchen" ON public.vendor_universities;
CREATE POLICY "Vendors can remove universities from their kitchen"
    ON public.vendor_universities
    FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.vendors
            WHERE vendors.id = vendor_universities.vendor_id
              AND vendors.user_id = auth.uid()
        )
    );
