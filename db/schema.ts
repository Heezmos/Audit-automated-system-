import { sqliteTable, text } from 'drizzle-orm/sqlite-core';
export const cases = sqliteTable('audit_cases', { id: text('id').primaryKey(), owner: text('owner').notNull(), data: text('data').notNull(), updated: text('updated').notNull() });
export const files = sqliteTable('audit_evidence', { id: text('id').primaryKey(), owner: text('owner').notNull(), auditId: text('audit_id').notNull(), name: text('name').notNull(), type: text('type').notNull(), hash: text('hash').notNull(), created: text('created').notNull() });
export const events = sqliteTable('audit_events', { id: text('id').primaryKey(), owner: text('owner').notNull(), auditId: text('audit_id').notNull(), description: text('description').notNull(), created: text('created').notNull() });
