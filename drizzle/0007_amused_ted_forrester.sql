CREATE TABLE `audit_backup_requests` (
	`id` text PRIMARY KEY NOT NULL,
	`owner` text NOT NULL,
	`created` text NOT NULL,
	`actor_id` text NOT NULL,
	`actor_name` text NOT NULL,
	`actor_email` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `audit_file_scans` (
	`seq` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`owner` text NOT NULL,
	`file_id` text NOT NULL,
	`hash` text NOT NULL,
	`verdict` text NOT NULL,
	`engine` text NOT NULL,
	`version` text NOT NULL,
	`signatures` text NOT NULL,
	`created` text NOT NULL,
	`actor_id` text NOT NULL,
	`actor_name` text NOT NULL,
	`actor_email` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `audit_rate_windows` (
	`id` text PRIMARY KEY NOT NULL,
	`owner` text NOT NULL,
	`count` integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE `audit_security_events` (
	`id` text PRIMARY KEY NOT NULL,
	`owner` text NOT NULL,
	`category` text NOT NULL,
	`status` integer NOT NULL,
	`path` text NOT NULL,
	`method` text NOT NULL,
	`created` text NOT NULL,
	`actor_id` text NOT NULL,
	`actor_name` text NOT NULL,
	`actor_email` text NOT NULL
);

--> statement-breakpoint
CREATE INDEX audit_file_scans_latest ON audit_file_scans(owner,file_id,seq);
--> statement-breakpoint
CREATE TRIGGER audit_file_scans_no_delete BEFORE DELETE ON audit_file_scans BEGIN SELECT RAISE(ABORT,'Permanent security records cannot be changed or deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_file_scans_no_update BEFORE UPDATE ON audit_file_scans BEGIN SELECT RAISE(ABORT,'Permanent security records cannot be changed or deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_file_scans_no_replace BEFORE INSERT ON audit_file_scans WHEN EXISTS(SELECT 1 FROM audit_file_scans WHERE seq=NEW.seq) BEGIN SELECT RAISE(ABORT,'Permanent security records cannot be replaced'); END;
--> statement-breakpoint
CREATE TRIGGER audit_security_events_no_delete BEFORE DELETE ON audit_security_events BEGIN SELECT RAISE(ABORT,'Permanent security records cannot be changed or deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_security_events_no_update BEFORE UPDATE ON audit_security_events BEGIN SELECT RAISE(ABORT,'Permanent security records cannot be changed or deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_security_events_no_replace BEFORE INSERT ON audit_security_events WHEN EXISTS(SELECT 1 FROM audit_security_events WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Permanent security records cannot be replaced'); END;
--> statement-breakpoint
CREATE TRIGGER audit_backup_requests_no_delete BEFORE DELETE ON audit_backup_requests BEGIN SELECT RAISE(ABORT,'Permanent security records cannot be changed or deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_backup_requests_no_update BEFORE UPDATE ON audit_backup_requests BEGIN SELECT RAISE(ABORT,'Permanent security records cannot be changed or deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_backup_requests_no_replace BEFORE INSERT ON audit_backup_requests WHEN EXISTS(SELECT 1 FROM audit_backup_requests WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Permanent security records cannot be replaced'); END;
--> statement-breakpoint
CREATE TRIGGER audit_rate_windows_no_delete BEFORE DELETE ON audit_rate_windows BEGIN SELECT RAISE(ABORT,'Activity counters cannot be deleted'); END;
