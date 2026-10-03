import { database } from './audit';
import type { ChatGPTUser } from '../app/chatgpt-auth';
export type Access={owner:string;ownerEmail:string;email:string;role:string};
export async function access(user:ChatGPTUser):Promise<Access|null>{
 const db=database();const email=user.email.toLowerCase().trim();
 // The initial release is owner-private. Initialise once without reassigning existing records.
 let ws=await db.prepare('SELECT owner,email FROM audit_workspace WHERE id=?').bind('main').first<{owner:string;email:string}>();
 if(!ws){const existing=await db.prepare('SELECT owner FROM audit_cases LIMIT 1').first<{owner:string}>();if(existing&&existing.owner!==user.userId)return null;await db.prepare('INSERT OR IGNORE INTO audit_workspace (id,owner,email) VALUES (?,?,?)').bind('main',user.userId,email).run();ws=await db.prepare('SELECT owner,email FROM audit_workspace WHERE id=?').bind('main').first<{owner:string;email:string}>();}
 if(!ws)return null;
 if(ws.owner===user.userId)return {owner:ws.owner,ownerEmail:ws.email,email,role:'Owner'};
 const member=await db.prepare('SELECT role FROM audit_members WHERE email=? AND active=?').bind(email,'yes').first<{role:string}>();return member?{owner:ws.owner,ownerEmail:ws.email,email,role:member.role}:null;
}
export function canWrite(a:Access){return ['Owner','Auditor'].includes(a.role)}
export function canReview(a:Access){return ['Owner','Reviewer'].includes(a.role)}
