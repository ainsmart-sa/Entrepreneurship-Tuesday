import {createContext,useContext,useEffect,useMemo,useState,type ReactNode} from 'react';
import type {User} from '@supabase/supabase-js';
import {db,type Profile,type Role} from './lib';
interface AuthState {user:User|null;profile:Profile|null;role:Role;loading:boolean;refresh:()=>Promise<void>;signOut:()=>Promise<void>}
const AuthContext=createContext<AuthState>({user:null,profile:null,role:null,loading:true,refresh:async()=>{},signOut:async()=>{}});
export const useAuth=()=>useContext(AuthContext);
export function AuthProvider({children}:{children:ReactNode}){
 const [user,setUser]=useState<User|null>(null);const [profile,setProfile]=useState<Profile|null>(null);const [role,setRole]=useState<Role>(null);const [loading,setLoading]=useState(true);
 async function load(u:User|null){
  setUser(u);if(!u||!db){setProfile(null);setRole(null);return;}
  const [p,s]=await Promise.all([db.from('profiles').select('id,full_name,email,phone').eq('id',u.id).maybeSingle(),db.from('staff_members').select('role,active').eq('user_id',u.id).maybeSingle()]);
  setProfile((p.data as Profile|null)??null);setRole(s.data?.active?(s.data.role as Role):null);
 }
 useEffect(()=>{let live=true;if(!db){setLoading(false);return;}
  db.auth.getUser().then(({data})=>load(data.user)).catch(()=>load(null)).finally(()=>{if(live)setLoading(false)});
  const {data:{subscription}}=db.auth.onAuthStateChange((_event,session)=>{setTimeout(()=>{if(live)void load(session?.user??null);},0)});
  return()=>{live=false;subscription.unsubscribe()};
 },[]);
 const value=useMemo(()=>({user,profile,role,loading,refresh:async()=>{if(db){const {data}=await db.auth.getUser();await load(data.user);}},signOut:async()=>{await db?.auth.signOut();await load(null)}}),[user,profile,role,loading]);
 return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
