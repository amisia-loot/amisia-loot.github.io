// Attendance from Warcraft Logs for the guild ledger's Attendance tab.
// Editors only. Needs the secrets WCL_CLIENT_ID and WCL_CLIENT_SECRET (a Warcraft Logs API client).
import { createClient } from 'npm:@supabase/supabase-js@2';

const GUILD = { name: 'Amisia', serverSlug: 'thunderstrike', serverRegion: 'EU' };
// TBC Anniversary logs live on the Fresh site; Classic is tried when the guild is not there.
const HOSTS = ['fresh.warcraftlogs.com', 'classic.warcraftlogs.com'];
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });

let token: string | null = null, tokenUntil = 0;
async function wclToken(): Promise<string> {
  if (token && Date.now() < tokenUntil) return token;
  const id = Deno.env.get('WCL_CLIENT_ID'), secret = Deno.env.get('WCL_CLIENT_SECRET');
  if (!id || !secret) throw new Error('missing_secrets');
  const res = await fetch('https://www.warcraftlogs.com/oauth/token', {
    method: 'POST',
    headers: { Authorization: 'Basic ' + btoa(id + ':' + secret), 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'grant_type=client_credentials',
  });
  if (res.status === 401 || res.status === 400) throw new Error('bad_secrets');
  if (!res.ok) throw new Error('token_' + res.status);
  const d = await res.json();
  token = d.access_token;
  tokenUntil = Date.now() + Math.max(60, (Number(d.expires_in) || 3600) - 300) * 1000;
  return token!;
}

const QUERY = `query($name: String!, $server: String!, $region: String!, $page: Int!) {
  guildData { guild(name: $name, serverSlug: $server, serverRegion: $region) {
    name
    attendance(limit: 25, page: $page) { has_more_pages data { code startTime zone { name } players { name type presence } } }
  } }
}`;

// The guild on one Warcraft Logs site, or null when that site does not know it.
async function guildPage(host: string, page: number) {
  const res = await fetch('https://' + host + '/api/v2/client', {
    method: 'POST',
    headers: { Authorization: 'Bearer ' + await wclToken(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: QUERY, variables: { name: GUILD.name, server: GUILD.serverSlug, region: GUILD.serverRegion, page } }),
  });
  if (res.status === 429) throw new Error('rate_limited');
  if (!res.ok) throw new Error('wcl_' + res.status);
  const d = await res.json();
  const guild = d?.data?.guildData?.guild ?? null;
  if (!guild && d?.errors?.length && !/guild/i.test(String(d.errors[0].message))) throw new Error('wcl_query: ' + d.errors[0].message);
  return guild;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);

  // the caller must be a ledger editor
  let key = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  try { key = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}').default ?? key; } catch { /* legacy key only */ }
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, key, {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    auth: { persistSession: false },
  });
  const { data: editor, error } = await sb.rpc('is_editor');
  if (error || editor !== true) return json({ error: 'not_editor' }, 403);

  let body: { pages?: number } = {};
  try { body = await req.json(); } catch { /* no body */ }
  const pages = Math.min(Math.max(Math.floor(Number(body.pages) || 2), 1), 8);

  try {
    let host = '', guild = null;
    for (const h of HOSTS) { guild = await guildPage(h, 1); if (guild) { host = h; break; } }
    if (!guild) return json({ error: 'guild_not_found' }, 404);
    const reports = [...(guild.attendance?.data ?? [])];
    let more = !!guild.attendance?.has_more_pages, page = 1;
    while (more && page < pages) {
      page++;
      const g = await guildPage(host, page);
      reports.push(...(g?.attendance?.data ?? []));
      more = !!g?.attendance?.has_more_pages;
    }
    return json({
      host, guild: guild.name, more,
      reports: reports.filter((r) => r && r.code).map((r) => ({
        code: r.code, startTime: r.startTime, zone: r.zone?.name ?? '',
        players: (r.players ?? []).filter((p) => p && p.name).map((p) => ({ name: p.name, cls: p.type ?? '', presence: p.presence ?? 1 })),
      })),
    });
  } catch (e) {
    const msg = String((e as Error)?.message ?? e);
    return json({ error: msg }, msg === 'missing_secrets' || msg === 'bad_secrets' ? 503 : 502);
  }
});
