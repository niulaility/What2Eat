-- ==============================================================================
-- What2Eat - Seed Data for Local Development & Testing
-- Creates 3 Test Accounts: Admin, Student (Customer), and Food Vendor
-- All using @gmail.com emails
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ==============================================================================
-- 2. CREATE ADMIN ACCOUNT
-- Email:    admin.what2eat@gmail.com
-- Password: Admin123!
-- ==============================================================================
INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'admin.what2eat@gmail.com',
    crypt('Admin123!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{
        "role": "admin",
        "username": "admin_w2e",
        "full_name": "System Administrator",
        "phone_number": "0123456789",
        "terms_accepted": true
    }',
    now(),
    now()
);

-- ==============================================================================
-- 3. CREATE CUSTOMER (STUDENT) ACCOUNT
-- Email:    student.ali.w2e@gmail.com
-- Password: Student123!
-- University: Universiti Teknologi Malaysia (UTM)
-- ==============================================================================
INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'student.ali.w2e@gmail.com',
    crypt('Student123!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{
        "role": "student",
        "username": "student_ali",
        "full_name": "Ali Bin Ahmad",
        "phone_number": "0112345678",
        "university": "utm",
        "terms_accepted": true
    }',
    now(),
    now()
);

-- ==============================================================================
-- 4. CREATE VENDOR ACCOUNT
-- Email:    mamasiti.kitchen@gmail.com
-- Password: Vendor123!
-- Kitchen:  Mama Siti Kitchen (Approved)
-- ==============================================================================
WITH new_vendor_auth AS (
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at
    ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        gen_random_uuid(),
        'authenticated',
        'authenticated',
        'mamasiti.kitchen@gmail.com',
        crypt('Vendor123!', gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}',
        '{
            "role": "vendor",
            "username": "makcik_siti",
            "full_name": "Siti Aminah",
            "phone_number": "0198765432",
            "terms_accepted": true
        }',
        now(),
        now()
    )
    RETURNING id
)
-- Create matching vendor business profile
INSERT INTO public.vendors (
    user_id,
    business_name,
    business_description,
    business_contact_number,
    business_address,
    status
)
SELECT 
    id,
    'Mama Siti Kitchen',
    'Authentic homemade Malay dishes and packed lunch delivery for campus students.',
    '0198765432',
    'No. 12, Jalan Universiti, 81300 Skudai, Johor',
    'approved'
FROM new_vendor_auth;

-- Link vendor to active universities served (UTM and UM)
INSERT INTO public.vendor_universities (vendor_id, university_id)
SELECT v.id, u.id
FROM public.vendors v
CROSS JOIN public.universities u
WHERE v.user_id = (SELECT id FROM auth.users WHERE email = 'mamasiti.kitchen@gmail.com')
  AND u.code IN ('utm', 'um')
ON CONFLICT (vendor_id, university_id) DO NOTHING;

-- Add sample verification documents for vendor
INSERT INTO public.vendor_documents (vendor_id, document_type, file_url, verification_status)
SELECT 
    v.id,
    doc.type::vendor_doc_type,
    doc.url,
    'verified'::verification_status
FROM public.vendors v
CROSS JOIN (
    VALUES 
        ('ic_front', 'sample-docs/ic_front.jpg'),
        ('typhoid', 'sample-docs/typhoid_cert.pdf'),
        ('kitchen', 'sample-docs/kitchen_photo1.jpg')
) AS doc(type, url)
WHERE v.user_id = (SELECT id FROM auth.users WHERE email = 'mamasiti.kitchen@gmail.com');
