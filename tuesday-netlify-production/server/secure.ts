import {createClient} from '@supabase/supabase-js';
import {createHmac, timingSafeEqual} from 'node:crypto';
import type {HandlerEvent} from '@netlify/functions';

const getEnv=()=>{
 const url=process.env.SUPABASE_URL;
 const key=process.env.SUPABASE_ANON_KEY;
 const secret=process.env.TICKET_SIGNING_SECRET;
 if(!url || !key || !secret || secret.length<32) throw new Error('SERVER_NOT_CONFIGURED');
 return {url,key,secret};
};
export function json(data:unknown,status=200){return {statusCode:status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'},body:JSON.stringify(data)};}
export async function authorized(event:HandlerEvent){
 const env=getEnv();
 const header=event.headers.authorization ?? event.headers.Authorization;
 const jwt=header?.match(/^Bearer (.+)$/i)?.[1];
 if(!jwt) throw new Error('UNAUTHORIZED');
 const client=createClient(env.url,env.key,{global:{headers:{Authorization:`Bearer ${jwt}`}},auth:{autoRefreshToken:false,persistSession:false}});
 const {data,error}=await client.auth.getUser(jwt);
 if(error || !data.user) throw new Error('UNAUTHORIZED');
 return {client,user:data.user,secret:env.secret};
}
export function ticketCode(ticketId:string,secret:string){
 const sig=createHmac('sha256',secret).update(`TUE1:${ticketId}`).digest('hex');
 return `TUE1.${ticketId}.${sig}`;
}
export function verifyTicketCode(code:string,secret:string){
 const m=/^TUE1\.([0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\.([0-9a-f]{64})$/i.exec(code.trim());
 if(!m)return null;
 const expected=createHmac('sha256',secret).update(`TUE1:${m[1]}`).digest();
 const provided=Buffer.from(m[2],'hex');
 return provided.length===expected.length&&timingSafeEqual(provided,expected)?m[1]:null;
}
export function errorResponse(err:unknown){
 const msg=err instanceof Error?err.message:'ERROR';
 if(msg==='UNAUTHORIZED')return json({error:'يرجى تسجيل الدخول أولًا'},401);
 if(msg==='SERVER_NOT_CONFIGURED')return json({error:'لم يتم إعداد خدمة التذاكر على الاستضافة'},503);
 console.error('secure function error',msg);
 return json({error:'تعذر إكمال العملية، حاول مرة أخرى'},500);
}
