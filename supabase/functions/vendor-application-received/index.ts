import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  })[character] ?? character);
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return Response.json({ error: 'Method not allowed' }, {
      status: 405,
      headers: corsHeaders,
    });
  }

  const authorization = request.headers.get('Authorization');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const resendApiKey = Deno.env.get('RESEND_API_KEY');
  const sender = Deno.env.get('RESEND_FROM_EMAIL');
  if (!authorization || !supabaseUrl || !anonKey || !resendApiKey || !sender) {
    return Response.json({ error: 'Email service is not configured.' }, {
      status: 500,
      headers: corsHeaders,
    });
  }

  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const accessToken = authorization.replace(/^Bearer\s+/i, '');
  const { data: userData, error: userError } = await supabase.auth.getUser(accessToken);
  const user = userData.user;
  if (userError || !user) {
    return Response.json({ error: 'Authentication required.' }, {
      status: 401,
      headers: corsHeaders,
    });
  }

  // Resolve the recipient and application from the caller's own RLS-protected
  // rows. The client cannot provide an arbitrary recipient or vendor ID.
  const [{ data: profile, error: profileError }, { data: application, error: applicationError }] =
    await Promise.all([
      supabase.from('profiles').select('email, role').eq('id', user.id).single(),
      supabase
        .from('vendors')
        .select('id, business_name, status, submitted_at')
        .eq('user_id', user.id)
        .single(),
    ]);

  if (profileError || applicationError || !profile?.email || !application) {
    return Response.json({ error: 'Could not find your submitted application.' }, {
      status: 404,
      headers: corsHeaders,
    });
  }
  if (profile.role !== 'vendor' || application.status !== 'pending') {
    return Response.json({ error: 'This vendor application is not pending.' }, {
      status: 409,
      headers: corsHeaders,
    });
  }

  const businessName = escapeHtml(application.business_name);
  const html = `
    <div style="font-family:Arial,sans-serif;color:#253729;line-height:1.6;max-width:600px;margin:auto">
      <h1 style="font-size:24px">We received your vendor application</h1>
      <p>Hello ${escapeHtml(user.user_metadata?.full_name ?? 'there')},</p>
      <p>Your application for <strong>${businessName}</strong> has been submitted successfully and is now being reviewed by a What2Eat administrator.</p>
      <p>You cannot sign in to the vendor dashboard while the application is pending. We will email you again after an administrator reviews your application.</p>
      <p>Thank you,<br>The What2Eat team</p>
    </div>`;

  const resendResponse = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${resendApiKey}`,
      'Content-Type': 'application/json',
      // Retrying registration will not send duplicate acknowledgements.
      'Idempotency-Key': `vendor-application-${application.id}-${new Date(application.submitted_at).getTime()}`,
    },
    body: JSON.stringify({
      from: sender,
      to: [profile.email],
      subject: 'We received your What2Eat vendor application',
      html,
    }),
  });

  if (!resendResponse.ok) {
    console.error('Resend rejected application email with status:', resendResponse.status);
    return Response.json({ error: 'Could not send the application confirmation email.' }, {
      status: 502,
      headers: corsHeaders,
    });
  }

  return Response.json({ sent: true }, { headers: corsHeaders });
});
