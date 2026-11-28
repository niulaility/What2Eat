import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, { status, headers: corsHeaders });
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    console.error('Vendor signup function is missing Supabase server secrets.');
    return json({ error: 'Vendor registration is not configured.' }, 500);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return json({ error: 'Invalid request body.' }, 400);
  }

  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  const password = typeof body.password === 'string' ? body.password : '';
  const username = typeof body.username === 'string' ? body.username.trim() : '';
  const fullName = typeof body.full_name === 'string' ? body.full_name.trim() : '';
  const phoneNumber = typeof body.phone_number === 'string' ? body.phone_number.trim() : '';
  const termsAccepted = body.terms_accepted === true;

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
    return json({ error: 'Enter a valid email address.' }, 400);
  }
  if (password.length < 8 || password.length > 128 ||
      !/[A-Za-z]/.test(password) || !/[0-9]/.test(password) || password.trim() !== password) {
    return json({ error: 'Password must be 8–128 characters and contain a letter and a number.' }, 400);
  }
  if (!/^[A-Za-z][A-Za-z0-9_]{2,29}$/.test(username)) {
    return json({ error: 'Enter a valid username.' }, 400);
  }
  if (fullName.length < 2 || fullName.length > 100 || phoneNumber.length < 8 || phoneNumber.length > 30) {
    return json({ error: 'Enter a valid name and phone number.' }, 400);
  }
  if (!termsAccepted) return json({ error: 'Accept the terms to register.' }, 400);

  const server = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { error } = await server.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      role: 'vendor',
      username,
      full_name: fullName,
      phone_number: phoneNumber,
      terms_accepted: true,
    },
  });

  if (error) {
    const errorCode = error.code?.toLowerCase() ?? '';
    const alreadyExists =
      ['user_already_exists', 'email_exists'].includes(errorCode) ||
      /already\s+(?:been\s+)?registered|already exists/i.test(error.message);
    if (alreadyExists) {
      // Avoid revealing whether an email belongs to an existing account. The
      // app will verify the password through the normal sign-in endpoint.
      return json({ ready_to_sign_in: true });
    }
    console.error('Could not create vendor account:', error.status, errorCode);
    return json({ error: 'Could not create the vendor account.' }, error.status >= 400 && error.status < 600 ? error.status : 400);
  }

  return json({ ready_to_sign_in: true, created: true });
});
