import type {Handler} from '@netlify/functions';
import {authorized,errorResponse,json,ticketCode} from '../../server/secure';
export const handler:Handler=async(event)=>{
 if(event.httpMethod!=='GET')return json({error:'METHOD_NOT_ALLOWED'},405);
 try{
  const {client,user,secret}=await authorized(event);
  const id=event.queryStringParameters?.ticket_id;
  if(!id||!/^[0-9a-f-]{36}$/i.test(id))return json({error:'INVALID_TICKET'},400);
  const {data,error}=await client.from('tickets').select('id,state,bookings!inner(user_id,state,events!inner(status))').eq('id',id).single();
  if(error||!data)return json({error:'التذكرة غير موجودة أو لا تملك صلاحية الوصول إليها'},404);
  const booking=data.bookings as unknown as {user_id:string;state:string;events:{status:string}};
  if(booking.user_id!==user.id||booking.state!=='approved'||booking.events?.status==='cancelled'||data.state==='revoked')return json({error:'التذكرة غير صالحة'},403);
  return json({code:ticketCode(id,secret),state:data.state});
 }catch(e){return errorResponse(e);}
};
