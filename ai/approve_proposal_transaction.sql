-- ProJobFlo Reliability Sprint Phase 2
-- Atomic, idempotent customer proposal approval.
--
-- Deploy in Supabase SQL Editor before relying on atomic approval from approve.html.
-- This function is intentionally limited to approval by signature token.

-- Deployment gate: these indexes make token lookup fast and enforce the
-- one-token/one-signature assumptions the RPC depends on.
create unique index if not exists quotes_signature_token_unique_idx
  on public.quotes (signature_token)
  where signature_token is not null;

create unique index if not exists proposal_signatures_quote_id_unique_idx
  on public.proposal_signatures (quote_id);

create or replace function public.approve_proposal_transaction(
  p_signature_token text,
  p_customer_name text,
  p_signature_image text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_quote public.quotes%rowtype;
  v_signed_at timestamptz := now();
  v_signature_token text := nullif(trim(p_signature_token), '');
  v_customer_name text := nullif(trim(p_customer_name), '');
  v_signature_image text := nullif(trim(p_signature_image), '');
  v_quote_data jsonb;
  v_timeline jsonb;
  v_activity jsonb;
  v_has_accepted_activity boolean := false;
  v_signature_count integer := 0;
begin
  if v_signature_token is null then
    return jsonb_build_object(
      'ok', false,
      'status', 'missing_token',
      'message', 'Missing proposal token.'
    );
  end if;

  if length(v_signature_token) > 512 then
    return jsonb_build_object(
      'ok', false,
      'status', 'invalid_token',
      'message', 'Proposal token is invalid.'
    );
  end if;

  if v_customer_name is null then
    return jsonb_build_object(
      'ok', false,
      'status', 'missing_customer_name',
      'message', 'Please enter your printed name.'
    );
  end if;

  if length(v_customer_name) > 200 then
    return jsonb_build_object(
      'ok', false,
      'status', 'invalid_customer_name',
      'message', 'Printed name is too long.'
    );
  end if;

  if v_signature_image is null then
    return jsonb_build_object(
      'ok', false,
      'status', 'missing_signature',
      'message', 'Please sign before approving.'
    );
  end if;

  if length(v_signature_image) > 2000000 or v_signature_image not like 'data:image/%;base64,%' then
    return jsonb_build_object(
      'ok', false,
      'status', 'invalid_signature',
      'message', 'Signature image format is invalid.'
    );
  end if;

  select *
    into v_quote
    from public.quotes
   where signature_token = v_signature_token
   for update;

  if not found then
    return jsonb_build_object(
      'ok', false,
      'status', 'not_found',
      'message', 'Proposal not found or link is invalid.'
    );
  end if;

  v_quote_data := coalesce(v_quote.quote_data::jsonb, '{}'::jsonb);

  if v_quote.signature_status = 'Signed'
    or v_quote.status = 'Sold'
    or v_quote_data->>'signature_status' = 'Signed'
    or v_quote_data->>'status' = 'Sold'
  then
    return jsonb_build_object(
      'ok', true,
      'status', 'already_signed',
      'message', 'Proposal has already been accepted.',
      'signed_at', v_quote.signed_at,
      'quote', to_jsonb(v_quote)
    );
  end if;

  if v_quote.expires_at is not null and v_quote.expires_at < now() then
    return jsonb_build_object(
      'ok', false,
      'status', 'expired',
      'message', 'This proposal has expired. Please contact the contractor for updated pricing.'
    );
  end if;

  v_timeline := coalesce(v_quote_data->'jobActivityTimeline', '[]'::jsonb);
  if jsonb_typeof(v_timeline) <> 'array' then
    v_timeline := '[]'::jsonb;
  end if;

  select exists (
    select 1
      from jsonb_array_elements(v_timeline) as activity
     where activity->>'activityType' = 'Quote Accepted'
  ) into v_has_accepted_activity;

  if not v_has_accepted_activity then
    v_activity := jsonb_build_object(
      'id', gen_random_uuid()::text,
      'timestamp', v_signed_at,
      'activityType', 'Quote Accepted',
      'description', 'Proposal accepted by ' || v_customer_name || '.',
      'author', '',
      'customerId', coalesce(v_quote.customer_id::text, ''),
      'quoteId', v_quote.id::text,
      'jobId', ''
    );
    v_timeline := v_timeline || jsonb_build_array(v_activity);
  end if;

  v_quote_data := v_quote_data || jsonb_build_object(
    'status', 'Sold',
    'signature_status', 'Signed',
    'signed_at', v_signed_at,
    'acceptedAt', v_signed_at,
    'signed_customer_name', v_customer_name,
    'jobActivityTimeline', v_timeline
  );

  insert into public.proposal_signatures (
    quote_id,
    user_id,
    customer_name,
    signature_image
  ) values (
    v_quote.id,
    v_quote.user_id,
    v_customer_name,
    v_signature_image
  )
  on conflict (quote_id) do nothing;

  get diagnostics v_signature_count = row_count;

  if v_signature_count <> 1 then
    return jsonb_build_object(
      'ok', false,
      'status', 'signature_conflict',
      'message', 'This proposal already has a stored signature. Please refresh the page.'
    );
  end if;

  update public.quotes
     set signature_status = 'Signed',
         status = 'Sold',
         signed_at = v_signed_at,
         signed_customer_name = v_customer_name,
         signature_image = v_signature_image,
         quote_data = v_quote_data
   where id = v_quote.id
   returning * into v_quote;

  return jsonb_build_object(
    'ok', true,
    'status', 'signed',
    'message', 'Proposal accepted successfully.',
    'signed_at', v_signed_at,
    'quote', to_jsonb(v_quote)
  );
end;
$$;

revoke all on function public.approve_proposal_transaction(text, text, text) from public;
grant execute on function public.approve_proposal_transaction(text, text, text) to anon;
grant execute on function public.approve_proposal_transaction(text, text, text) to authenticated;
