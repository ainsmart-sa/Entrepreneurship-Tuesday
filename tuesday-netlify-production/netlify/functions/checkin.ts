import type {Handler} from '@netlify/functions';
import {authorized,errorResponse,json,verifyTicketCode} from '../../server/secure';
export const handler:Handler=async(event)=>{
 if(event.httpMethod!=='POST')return json({error:'METHOD_NOT_ALLOWED'},405);
 if((event.body??'').length>4096)return json({error:'PAYLOAD_TOO_LARGE'},413);
 try{
  const {client,user,secret}=await authorized(event);
  // Role lookup is server-side. Atomic check_in_ticket also checks role in PostgreSQL.
  const {data:staff}=await client.from('staff_members').select('role,active').eq('user_id',user.id).maybeSingle();
  if(!staff?.active||!['owner','admin','reviewer','checkin'].includes(staff.role))return json({error:'ليس لديك صلاحية تسجيل الحضور'},403);
  let body:{code?:string}={};
  try{body=JSON.parse(event.body??'{}') as {code?:string};}catch{return json({error:'INVALID_JSON'},400);}
  if(!body.code||body.code.length>200)return json({error:'INVALID_CODE'},400);
  const id=verifyTicketCode(body.code,secret);
  if(!id)return json({ok:false,reason:'INVALID_CODE'},200);
  const {data,error}=await client.rpc('check_in_ticket',{p_ticket:id});
  if(error){console.error('checkin RPC',error.code);return json({error:error.message==='FORBIDDEN'?'ليس لديك صلاحية تسجيل الحضور':'فشلت عملية تسجيل الحضور'},403);}
  return json(data);
 }catch(e){return errorResponse(e);}
};
