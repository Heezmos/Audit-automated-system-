import { sqliteTable, text } from 'drizzle-orm/sqlite-core';
export const cases = sqliteTable('audit_cases', { id: text('id').primaryKey(), owner: text('owner').notNull(), data: text('data').notNull(), updated: text('updated').notNull() });
export const files = sqliteTable('audit_evidence', { id: text('id').primaryKey(), owner: text('owner').notNull(), auditId: text('audit_id').notNull(), name: text('name').notNull(), type: text('type').notNull(), hash: text('hash').notNull(), created: text('created').notNull() });
export const events = sqliteTable('audit_events', { id: text('id').primaryKey(), owner: text('owner').notNull(), auditId: text('audit_id').notNull(), description: text('description').notNull(), created: text('created').notNull() });
export const workspace = sqliteTable('audit_workspace', { id:text('id').primaryKey(), owner:text('owner').notNull(), email:text('email').notNull() });
export const members = sqliteTable('audit_members', { email:text('email').primaryKey(), name:text('name').notNull(), role:text('role').notNull(), active:text('active').notNull(), created:text('created').notNull() });
export const checks = sqliteTable('audit_checks', { id:text('id').primaryKey(), owner:text('owner').notNull(), auditId:text('audit_id').notNull(), data:text('data').notNull(), created:text('created').notNull() });
