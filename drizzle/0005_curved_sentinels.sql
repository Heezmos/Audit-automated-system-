CREATE TABLE `audit_versions` (
	`id` text PRIMARY KEY NOT NULL,
	`owner` text NOT NULL,
	`audit_id` text NOT NULL,
	`data` text NOT NULL,
	`created` text NOT NULL
);
--> statement-breakpoint
ALTER TABLE `audit_events` ADD `actor_id` text;--> statement-breakpoint
ALTER TABLE `audit_events` ADD `actor_name` text;--> statement-breakpoint
ALTER TABLE `audit_events` ADD `actor_email` text;--> statement-breakpoint
ALTER TABLE `audit_events` ADD `before_data` text;--> statement-breakpoint
ALTER TABLE `audit_events` ADD `after_data` text;--> statement-breakpoint
ALTER TABLE `audit_evidence` ADD `uploaded_by_id` text;--> statement-breakpoint
ALTER TABLE `audit_evidence` ADD `uploaded_by_name` text;--> statement-breakpoint
ALTER TABLE `audit_evidence` ADD `uploaded_by_email` text;--> statement-breakpoint
ALTER TABLE `audit_evidence` ADD `upload_status` text DEFAULT 'available' NOT NULL;
--> statement-breakpoint
CREATE INDEX audit_events_history ON audit_events(owner,created,id);
--> statement-breakpoint
CREATE TRIGGER audit_cases_no_delete BEFORE DELETE ON audit_cases BEGIN SELECT RAISE(ABORT,'Permanent audit records cannot be deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_evidence_no_delete BEFORE DELETE ON audit_evidence BEGIN SELECT RAISE(ABORT,'Permanent audit records cannot be deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_events_no_delete BEFORE DELETE ON audit_events BEGIN SELECT RAISE(ABORT,'Permanent audit records cannot be deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_checks_no_delete BEFORE DELETE ON audit_checks BEGIN SELECT RAISE(ABORT,'Permanent audit records cannot be deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_versions_no_delete BEFORE DELETE ON audit_versions BEGIN SELECT RAISE(ABORT,'Permanent audit records cannot be deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_ai_runs_no_delete BEFORE DELETE ON audit_ai_runs BEGIN SELECT RAISE(ABORT,'Permanent audit records cannot be deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_members_no_delete BEFORE DELETE ON audit_members BEGIN SELECT RAISE(ABORT,'Permanent audit records cannot be deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_workspace_no_delete BEFORE DELETE ON audit_workspace BEGIN SELECT RAISE(ABORT,'Permanent audit records cannot be deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_events_no_update BEFORE UPDATE ON audit_events BEGIN SELECT RAISE(ABORT,'Permanent audit records cannot be altered'); END;
--> statement-breakpoint
CREATE TRIGGER audit_checks_no_update BEFORE UPDATE ON audit_checks BEGIN SELECT RAISE(ABORT,'Permanent audit records cannot be altered'); END;
--> statement-breakpoint
CREATE TRIGGER audit_versions_no_update BEFORE UPDATE ON audit_versions BEGIN SELECT RAISE(ABORT,'Permanent audit records cannot be altered'); END;
--> statement-breakpoint
CREATE TRIGGER audit_workspace_no_update BEFORE UPDATE ON audit_workspace BEGIN SELECT RAISE(ABORT,'Permanent audit records cannot be altered'); END;
--> statement-breakpoint
CREATE TRIGGER audit_evidence_no_rewrite BEFORE UPDATE ON audit_evidence WHEN OLD.id IS NOT NEW.id OR OLD.owner IS NOT NEW.owner OR OLD.audit_id IS NOT NEW.audit_id OR OLD.name IS NOT NEW.name OR OLD.type IS NOT NEW.type OR OLD.hash IS NOT NEW.hash OR OLD.created IS NOT NEW.created OR OLD.uploaded_by_id IS NOT NEW.uploaded_by_id OR OLD.uploaded_by_name IS NOT NEW.uploaded_by_name OR OLD.uploaded_by_email IS NOT NEW.uploaded_by_email OR (OLD.upload_status='available' AND NEW.upload_status!='available') BEGIN SELECT RAISE(ABORT,'Original evidence cannot be rewritten'); END;
--> statement-breakpoint
CREATE TRIGGER audit_cases_archive_insert AFTER INSERT ON audit_cases BEGIN INSERT INTO audit_versions (id,owner,audit_id,data,created) VALUES (lower(hex(randomblob(16))),NEW.owner,NEW.id,NEW.data,strftime('%Y-%m-%dT%H:%M:%fZ','now')); END;
--> statement-breakpoint
CREATE TRIGGER audit_cases_archive_update AFTER UPDATE ON audit_cases BEGIN INSERT INTO audit_versions (id,owner,audit_id,data,created) VALUES (lower(hex(randomblob(16))),OLD.owner,OLD.id,OLD.data,strftime('%Y-%m-%dT%H:%M:%fZ','now')); END;
--> statement-breakpoint
CREATE TRIGGER audit_cases_no_replace BEFORE INSERT ON audit_cases WHEN EXISTS (SELECT 1 FROM audit_cases WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Permanent records cannot be replaced'); END;
--> statement-breakpoint
CREATE TRIGGER audit_evidence_no_replace BEFORE INSERT ON audit_evidence WHEN EXISTS (SELECT 1 FROM audit_evidence WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Permanent records cannot be replaced'); END;
--> statement-breakpoint
CREATE TRIGGER audit_events_no_replace BEFORE INSERT ON audit_events WHEN EXISTS (SELECT 1 FROM audit_events WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Permanent records cannot be replaced'); END;
--> statement-breakpoint
CREATE TRIGGER audit_checks_no_replace BEFORE INSERT ON audit_checks WHEN EXISTS (SELECT 1 FROM audit_checks WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Permanent records cannot be replaced'); END;
--> statement-breakpoint
CREATE TRIGGER audit_versions_no_replace BEFORE INSERT ON audit_versions WHEN EXISTS (SELECT 1 FROM audit_versions WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Permanent records cannot be replaced'); END;
--> statement-breakpoint
CREATE TRIGGER audit_ai_runs_no_replace BEFORE INSERT ON audit_ai_runs WHEN EXISTS (SELECT 1 FROM audit_ai_runs WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Permanent records cannot be replaced'); END;
--> statement-breakpoint
CREATE TRIGGER audit_cases_identity_lock BEFORE UPDATE ON audit_cases WHEN OLD.id IS NOT NEW.id OR OLD.owner IS NOT NEW.owner BEGIN SELECT RAISE(ABORT,'Audit identity cannot change'); END;
--> statement-breakpoint
CREATE TRIGGER audit_ai_runs_completed_lock BEFORE UPDATE ON audit_ai_runs WHEN OLD.status='complete' BEGIN SELECT RAISE(ABORT,'Completed AI records cannot change'); END;
