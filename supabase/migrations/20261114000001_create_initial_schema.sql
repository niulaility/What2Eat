-- ==============================================================================
-- What2Eat - Initial Database Schema Migration
-- Includes: Authentication, Profiles, Universities, Customers, Vendors & Documents
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. ENUMS & TYPES
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('student', 'vendor', 'admin');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'vendor_status') THEN
        CREATE TYPE vendor_status AS ENUM ('pending', 'approved', 'rejected');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'vendor_doc_type') THEN
        CREATE TYPE vendor_doc_type AS ENUM (
            'ic_front',
            'ic_back',
            'selfie',
            'ssm',
            'kkm',
            'typhoid',
            'kitchen'
        );
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'verification_status') THEN
        CREATE TYPE verification_status AS ENUM ('pending', 'verified', 'rejected');
    END IF;
END $$;

-- 3. REUSABLE TRIGGER FUNCTION: update_updated_at_column
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- 4. TABLE: universities
-- Managed by Admins:
--   - Add new universities
--   - Edit details
--   - Activate/deactivate (is_active)
-- Read by Students & Vendors (only active ones selectable)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.universities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL UNIQUE,
    city TEXT,
    state TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_universities_code ON public.universities(code);
CREATE INDEX IF NOT EXISTS idx_universities_is_active ON public.universities(is_active);

-- Seed the initial universities from current Flutter UI
INSERT INTO public.universities (code, name, state, is_active)
VALUES
    ('utm', 'Universiti Teknologi Malaysia', 'Johor', true),
    ('um', 'Universiti Malaya', 'Kuala Lumpur', true),
    ('upm', 'Universiti Putra Malaysia', 'Selangor', true),
    ('ukm', 'Universiti Kebangsaan Malaysia', 'Selangor', true),
    ('usm', 'Universiti Sains Malaysia', 'Penang', true),
    ('uitm', 'Universiti Teknologi MARA', 'Selangor', true)
ON CONFLICT (code) DO NOTHING;

-- ==============================================================================
-- 5. TABLE: profiles (Central Base User Account)
-- Single source of truth for user lifecycle (created_at, updated_at).
-- Maps to:
--   - auth_page.dart (Sign in & Registration)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role user_role NOT NULL DEFAULT 'student',
    username TEXT NOT NULL UNIQUE,
    full_name TEXT,
    email TEXT NOT NULL UNIQUE,
    phone_number TEXT NOT NULL,
    avatar_url TEXT,
    terms_accepted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT username_length_check CHECK (char_length(username) >= 3 AND char_length(username) <= 30),
    CONSTRAINT username_format_check CHECK (username ~ '^[A-Za-z][A-Za-z0-9_]{2,29}$')
);

-- Profiles indexes
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);

-- Profiles updated_at trigger (Only profiles needs this)
DROP TRIGGER IF EXISTS trigger_profiles_updated_at ON public.profiles;
CREATE TRIGGER trigger_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- ==============================================================================
-- 6. TABLE: customers (Student / Customer Specific Profile)
-- Maps to:
--   - auth_page.dart (Customer Registration)
-- Holds student's university affiliation.
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    university_id UUID REFERENCES public.universities(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_customers_user_id ON public.customers(user_id);
CREATE INDEX IF NOT EXISTS idx_customers_university_id ON public.customers(university_id);

-- ==============================================================================
-- 7. TABLE: vendors (Vendor Specific Profile)
-- Maps to:
--   - vendor_registration_page.dart (Step 2: Business Information)
--   - vendor_application_pending_page.dart (Status review)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.vendors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    business_name TEXT NOT NULL,
    business_description TEXT NOT NULL,
    business_contact_number TEXT NOT NULL,
    business_address TEXT NOT NULL,
    logo_url TEXT,
    status vendor_status NOT NULL DEFAULT 'pending',
    rejection_reason TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    reviewed_at TIMESTAMPTZ,

    CONSTRAINT business_name_min_length CHECK (char_length(trim(business_name)) >= 2),
    CONSTRAINT business_desc_min_length CHECK (char_length(trim(business_description)) >= 20),
    CONSTRAINT business_addr_min_length CHECK (char_length(trim(business_address)) >= 10)
);

-- Vendors indexes
CREATE INDEX IF NOT EXISTS idx_vendors_user_id ON public.vendors(user_id);
CREATE INDEX IF NOT EXISTS idx_vendors_status ON public.vendors(status);

-- ==============================================================================
-- 8. TABLE: vendor_universities (Junction Table)
-- Vendors select one or multiple active universities they serve
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.vendor_universities (
    vendor_id UUID NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
    university_id UUID NOT NULL REFERENCES public.universities(id) ON DELETE CASCADE,
    PRIMARY KEY (vendor_id, university_id)
);

CREATE INDEX IF NOT EXISTS idx_vendor_universities_vendor ON public.vendor_universities(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_universities_uni ON public.vendor_universities(university_id);

-- ==============================================================================
-- 9. TABLE: vendor_documents
-- Maps to:
--   - vendor_registration_page.dart (Step 3: Document Verification)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.vendor_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
    document_type vendor_doc_type NOT NULL,
    file_url TEXT NOT NULL,
    verification_status verification_status NOT NULL DEFAULT 'pending',
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Documents index
CREATE INDEX IF NOT EXISTS idx_vendor_documents_vendor ON public.vendor_documents(vendor_id);

-- ==============================================================================
-- 10. AUTOMATIC USER SYNC TRIGGER
-- Automatically creates public.profiles entry whenever a user signs up.
-- Also auto-creates a public.customers row if role is student/customer.
-- ==============================================================================
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

    -- 1. Insert Base Profile (lifecycle timestamps handled here)
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
    ON CONFLICT (id) DO NOTHING;

    -- 2. If student/customer, automatically create student customer profile
    IF v_role = 'student' THEN
        INSERT INTO public.customers (
            user_id,
            university_id
        )
        VALUES (
            NEW.id,
            v_uni_id
        )
        ON CONFLICT (user_id) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_auth_user();

-- ==============================================================================
-- 11. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

-- Enable RLS on all tables
ALTER TABLE public.universities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_universities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_documents ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- HELPER FUNCTION: Check if current user is admin
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ------------------------------------------------------------------------------
-- UNIVERSITIES POLICIES
-- ------------------------------------------------------------------------------
CREATE POLICY "Public can view active universities; Admins can view all"
    ON public.universities
    FOR SELECT
    USING (is_active = true OR public.is_admin());

CREATE POLICY "Only admins can add universities"
    ON public.universities
    FOR INSERT
    TO authenticated
    WITH CHECK (public.is_admin());

CREATE POLICY "Only admins can update universities"
    ON public.universities
    FOR UPDATE
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

CREATE POLICY "Only admins can delete universities"
    ON public.universities
    FOR DELETE
    TO authenticated
    USING (public.is_admin());

-- ------------------------------------------------------------------------------
-- PROFILES POLICIES
-- ------------------------------------------------------------------------------
CREATE POLICY "Profiles are viewable by authenticated users"
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Users can insert their own profile"
    ON public.profiles
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update only their own profile"
    ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- ------------------------------------------------------------------------------
-- CUSTOMERS POLICIES (Student Profile)
-- ------------------------------------------------------------------------------
CREATE POLICY "Customers can view their own customer profile"
    ON public.customers
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "Customers can insert their own customer profile"
    ON public.customers
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Customers can update their own customer profile"
    ON public.customers
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id OR public.is_admin())
    WITH CHECK (auth.uid() = user_id OR public.is_admin());

-- ------------------------------------------------------------------------------
-- VENDORS POLICIES
-- ------------------------------------------------------------------------------
CREATE POLICY "Approved vendors are viewable by everyone"
    ON public.vendors
    FOR SELECT
    TO authenticated
    USING (status = 'approved' OR auth.uid() = user_id OR public.is_admin());

CREATE POLICY "Vendors can insert their own application"
    ON public.vendors
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Vendors can update their own business information"
    ON public.vendors
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id OR public.is_admin())
    WITH CHECK (auth.uid() = user_id OR public.is_admin());

-- ------------------------------------------------------------------------------
-- VENDOR UNIVERSITIES POLICIES
-- ------------------------------------------------------------------------------
CREATE POLICY "Vendor universities are viewable by authenticated users"
    ON public.vendor_universities
    FOR SELECT
    TO authenticated
    USING (true);

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

-- ------------------------------------------------------------------------------
-- VENDOR DOCUMENTS POLICIES (STRICT PRIVACY)
-- ------------------------------------------------------------------------------
CREATE POLICY "Vendors and admins can view their own documents"
    ON public.vendor_documents
    FOR SELECT
    TO authenticated
    USING (
        public.is_admin()
        OR
        EXISTS (
            SELECT 1 FROM public.vendors
            WHERE vendors.id = vendor_documents.vendor_id
              AND vendors.user_id = auth.uid()
        )
    );

CREATE POLICY "Vendors can insert their own documents"
    ON public.vendor_documents
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.vendors
            WHERE vendors.id = vendor_documents.vendor_id
              AND vendors.user_id = auth.uid()
        )
    );

-- ==============================================================================
-- 12. STORAGE BUCKETS SETUP (Public & Private)
-- ==============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('avatars', 'avatars', true),
    ('vendor-logos', 'vendor-logos', true),
    ('vendor-documents', 'vendor-documents', false)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: Public read for avatars & logos
CREATE POLICY "Avatars are publicly accessible"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');

CREATE POLICY "Vendor logos are publicly accessible"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'vendor-logos');

-- Storage RLS: Upload access for authenticated users to avatars & logos
CREATE POLICY "Users can upload their own avatar"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Vendors can upload logos"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'vendor-logos');

-- Storage RLS: Strict private access for sensitive vendor verification documents
CREATE POLICY "Vendors can upload their own verification documents"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'vendor-documents' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Vendors can read their own verification documents"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'vendor-documents' AND auth.uid()::text = (storage.foldername(name))[1]);
