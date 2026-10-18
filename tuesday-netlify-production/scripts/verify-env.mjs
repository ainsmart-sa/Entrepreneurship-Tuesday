/**
 * Validate production config. Never log actual API keys or ticket secrets.
 * VITE_ Supabase URL/key are PUBLIC and can be used by Netlify Functions.
 * TICKET_SIGNING_SECRET is PRIVATE and must be configured separately.
 */
const required=['VITE_SUPABASE_URL','VITE_SUPABASE_ANON_KEY','TICKET_SIGNING_SECRET'];
const errors=required.filter(name=>!process.env[name]?.trim()).map(name=>`Missing ${name}`);
const url=process.env.VITE_SUPABASE_URL?.trim();
const serverUrl=process.env.SUPABASE_URL?.trim();
const pub=process.env.VITE_SUPABASE_ANON_KEY?.trim();
const serverPub=process.env.SUPABASE_ANON_KEY?.trim();
if(url){
 try{const parsed=new URL(url);if(parsed.protocol!=='https:'||!/^[a-z0-9-]+\.supabase\.co$/.test(parsed.hostname))errors.push('Invalid Supabase HTTPS project URL');}
 catch{errors.push('Invalid VITE_SUPABASE_URL');}
}
if(url&&serverUrl&&url.replace(/\/$/,'')!==serverUrl.replace(/\/$/,''))errors.push('SUPABASE_URL does not match VITE_SUPABASE_URL');
if(pub&&(pub.startsWith('sb_secret_')||(pub.startsWith('sb_')&&!pub.startsWith('sb_publishable_'))))errors.push('Supabase secret keys are forbidden in VITE_ variables');
else if(pub&&!pub.startsWith('sb_publishable_')&&pub.split('.').length!==3)errors.push('Invalid public Supabase key shape');
if(pub&&serverPub&&pub!==serverPub)errors.push('SUPABASE_ANON_KEY does not match VITE_SUPABASE_ANON_KEY');
const secret=process.env.TICKET_SIGNING_SECRET??'';
if(secret&&(secret.length<32||/^(CHANGE_ME|YOUR_|REPLACE_|EXAMPLE|TEST_)/i.test(secret)))errors.push('TICKET_SIGNING_SECRET must be a strong random secret, 32+ characters');
if(errors.length){
 const prod=process.env.NETLIFY==='true'||process.env.DEPLOY_REQUIRE_CONFIG==='1';
 if(prod){console.error('Tuesday production configuration error:');errors.forEach(x=>console.error('- '+x));process.exit(1);}
 console.warn('Tuesday local preview: production configuration incomplete.');
}else console.log('Tuesday environment preflight passed (live connection still untested).');
