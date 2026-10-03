import { database } from './audit';
import type { ChatGPTUser } from '../app/chatgpt-auth';
export type Access={owner:string;ownerEmail:string;email:string;role:string;userId:string};
export async function access(user:ChatGPTUser):Promise<Access|null>{
 const db=database();const email=user.email.toLowerCase().trim();
 // The initial release is owner-private. Initialise once without reassigning existing records.
 let ws=await db.prepare('SELECT owner,email FROM audit_workspace WHERE id=?').bind('main').first<{owner:string;email:string}>();
 if(!ws){const existing=await db.prepare('SELECT owner FROM audit_cases LIMIT 1').first<{owner:string}>();if(existing&&existing.owner!==user.userId)return null;await db.prepare('INSERT OR IGNORE INTO audit_workspace (id,owner,email) VALUES (?,?,?)').bind('main',user.userId,email).run();ws=await db.prepare('SELECT owner,email FROM audit_workspace WHERE id=?').bind('main').first<{owner:string;email:string}>();}
 if(!ws)return null;
 if(ws.owner===user.userId)return {owner:ws.owner,ownerEmail:ws.email,email:ws.email,userId:user.userId,role:'Owner'};
 // Bind an invited member's first successful sign-in to a stable Site user ID.
 let member=await db.prepare('SELECT email,role,user_id FROM audit_members WHERE user_id=? AND active=?').bind(user.userId,'yes').first<{email:string;role:string;user_id:string|null}>();
 if(!member){await db.prepare('UPDATE audit_members SET user_id=? WHERE email=? AND active=? AND user_id IS NULL AND NOT EXISTS (SELECT 1 FROM audit_members WHERE user_id=?)').bind(user.userId,email,'yes',user.userId).run();member=await db.prepare('SELECT email,role,user_id FROM audit_members WHERE user_id=? AND active=?').bind(user.userId,'yes').first<{email:string;role:string;user_id:string|null}>();}
 return member?{owner:ws.owner,ownerEmail:ws.email,email:member.email,userId:user.userId,role:member.role}:null;
}
export function canWrite(a:Access){return ['Owner','Auditor'].includes(a.role)}
export function canReview(a:Access){return ['Owner','Reviewer'].includes(a.role)}
