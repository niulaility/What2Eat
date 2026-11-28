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
    return Response.json({ error: 'Method not allowed.' }, {
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
  const { data: authData, error: authError } = await supabase.auth.getUser(accessToken);
  if (authError || !authData.user) {
    return Response.json({ error: 'Authentication required.' }, {
      status: 401,
      headers: corsHeaders,
    });
  }

  const { data: reviewer, error: reviewerError } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', authData.user.id)
    .single();
  if (reviewerError || reviewer?.role !== 'admin') {
    return Response.json({ error: 'Only administrators can send review notices.' }, {
      status: 403,
      headers: corsHeaders,
    });
  }

  let body: { vendor_id?: unknown };
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: 'Invalid request body.' }, {
      status: 400,
      headers: corsHeaders,
    });
  }
  if (typeof body.vendor_id !== 'string') {
    return Response.json({ error: 'Vendor application ID is required.' }, {
      status: 400,
      headers: corsHeaders,
    });
  }

  const { data: application, error: applicationError } = await supabase
    .from('vendors')
    .select('id, user_id, business_name, status, rejection_reason, reviewed_at')
    .eq('id', body.vendor_id)
    .single();
  if (applicationError || !application ||
      !['approved', 'rejected'].includes(application.status) ||
      !application.reviewed_at) {
    return Response.json({ error: 'Reviewed application was not found.' }, {
      status: 404,
      headers: corsHeaders,
    });
  }

  const { data: vendorProfile, error: vendorProfileError } = await supabase
    .from('profiles')
    .select('email, full_name')
    .eq('id', application.user_id)
    .single();
  if (vendorProfileError || !vendorProfile?.email) {
    return Response.json({ error: 'Vendor email address was not found.' }, {
      status: 404,
      headers: corsHeaders,
    });
  }

  const approved = application.status === 'approved';
  const name = escapeHtml(vendorProfile.full_name || 'there');
  const business = escapeHtml(application.business_name);
  const decisionText = approved
    ? `<p>Your application for <strong>${business}</strong> has been approved. Your vendor account is active, and you can now sign in to the What2Eat vendor dashboard.</p>`
    : `<p>Your application for <strong>${business}</strong> was not approved.</p><p><strong>Reason:</strong> ${escapeHtml(application.rejection_reason || 'Please contact What2Eat for more information.')}</p>`;
  const resendResponse = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${resendApiKey}`,
      'Content-Type': 'application/json',
      'Idempotency-Key': `vendor-review-${application.id}-${application.status}-${new Date(application.reviewed_at).getTime()}`,
    },
    body: JSON.stringify({
      from: sender,
      to: [vendorProfile.email],
      subject: approved
        ? 'Your What2Eat vendor application was approved'
        : 'An update about your What2Eat vendor application',
      html: `<div style="font-family:Arial,sans-serif;color:#253729;line-height:1.6;max-width:600px;margin:auto"><h1 style="font-size:24px">Vendor application update</h1><p>Hello ${name},</p>${decisionText}<p>Thank you,<br>The What2Eat team</p></div>`,
    }),
  });

  if (!resendResponse.ok) {
    console.error('Resend rejected vendor review email with status:', resendResponse.status);
    return Response.json({ error: 'Could not send the review decision email.' }, {
      status: 502,
      headers: corsHeaders,
    });
  }

  return Response.json({ sent: true }, { headers: corsHeaders });
});
