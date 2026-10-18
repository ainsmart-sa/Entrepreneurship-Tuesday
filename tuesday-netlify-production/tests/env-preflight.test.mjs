import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
const sample={...process.env,NETLIFY:'true',VITE_SUPABASE_URL:'https://example.supabase.co',VITE_SUPABASE_ANON_KEY:'sb_publishable_ci_public_fixture',TICKET_SIGNING_SECRET:'ci_fixture_generated_for_testing_only_123456789'};
function run(env){return spawnSync(process.execPath,['scripts/verify-env.mjs'],{cwd:process.cwd(),encoding:'utf8',env});}
test('Production preflight passes with public VITE config plus ticket secret',()=>{const r=run(sample);assert.equal(r.status,0,r.stderr);});
test('Build fails without signed ticket secret',()=>{const r=run({...sample,TICKET_SIGNING_SECRET:''});assert.notEqual(r.status,0);assert.match(r.stderr,/TICKET_SIGNING_SECRET/);});
test('Build fails when Supabase public project URL is absent',()=>{const r=run({...sample,VITE_SUPABASE_URL:''});assert.notEqual(r.status,0);assert.match(r.stderr,/VITE_SUPABASE_URL/);});
test('Browser variable must never contain a Supabase secret key',()=>{const r=run({...sample,VITE_SUPABASE_ANON_KEY:'sb_secret_not_safe'});assert.notEqual(r.status,0);assert.match(r.stderr,/secret keys/);});
test('Disallow mismatched optional legacy aliases',()=>{const r=run({...sample,SUPABASE_URL:'https://different.supabase.co'});assert.notEqual(r.status,0);assert.match(r.stderr,/does not match/);});
