// Prevent incomplete Tuesday Netlify deployments. Never print secret values.
const required=['VITE_SUPABASE_URL','VITE_SUPABASE_ANON_KEY','SUPABASE_URL','SUPABASE_ANON_KEY','TICKET_SIGNING_SECRET'];
const errors=required.filter(name=>!process.env[name]?.trim()).map(name=>`Missing ${name}`);
const pub=process.env.VITE_SUPABASE_ANON_KEY?.trim();
const serverPub=process.env.SUPABASE_ANON_KEY?.trim();
const url=process.env.VITE_SUPABASE_URL?.trim();
const serverUrl=process.env.SUPABASE_URL?.trim();
if(pub?.startsWith('sb_secret_')) errors.push('Never expose secret keys in VITE_SUPABASE_ANON_KEY');
if(pub && !pub.startsWith('sb_publishable_') && pub.split('.').length!==3) errors.push('Invalid publishable key shape');
if(url){
  try{const parsed=new URL(url);if(parsed.protocol!=='https:'||!parsed.hostname.endsWith('.supabase.co')) errors.push('Invalid Supabase project URL');}
  catch{errors.push('Invalid Supabase URL');}
}
if(url && serverUrl && url.replace(/\/$/,'')!==serverUrl.replace(/\/$/,'')) errors.push('SUPABASE_URL does not match VITE_SUPABASE_URL');
if(pub && serverPub && pub!==serverPub) errors.push('SUPABASE_ANON_KEY does not match VITE_SUPABASE_ANON_KEY');
if(process.env.TICKET_SIGNING_SECRET && process.env.TICKET_SIGNING_SECRET.length<32) errors.push('TICKET_SIGNING_SECRET must contain at least 32 characters');
if(errors.length){
  const production=process.env.NETLIFY==='true'||process.env.DEPLOY_REQUIRE_CONFIG==='1';
  if(production){console.error('Tuesday deployment configuration incomplete:');errors.forEach(x=>console.error('- '+x));process.exit(1);}
  console.warn('Tuesday local preview: missing production config ('+errors.length+' issue(s))');
}else console.log('Tuesday configuration names and formats validated (not a live connection test).');
