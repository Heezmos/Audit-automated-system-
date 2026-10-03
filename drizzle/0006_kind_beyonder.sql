CREATE TABLE `audit_alert_transitions` (
	`seq` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`owner` text NOT NULL,
	`alert_id` text NOT NULL,
	`state` text NOT NULL,
	`created` text NOT NULL,
	`actor_id` text NOT NULL,
	`actor_name` text NOT NULL,
	`actor_email` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `audit_alerts` (
	`id` text PRIMARY KEY NOT NULL,
	`owner` text NOT NULL,
	`audit_id` text NOT NULL,
	`finding_id` text NOT NULL,
	`kind` text NOT NULL,
	`level` text NOT NULL,
	`due` text NOT NULL,
	`title` text NOT NULL,
	`responsible` text NOT NULL,
	`recipients` text NOT NULL,
	`created` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `audit_monitor_runs` (
	`id` text PRIMARY KEY NOT NULL,
	`owner` text NOT NULL,
	`created` text NOT NULL,
	`actor_id` text NOT NULL,
	`actor_name` text NOT NULL,
	`actor_email` text NOT NULL,
	`data` text NOT NULL
);

--> statement-breakpoint
CREATE INDEX audit_alert_transitions_latest ON audit_alert_transitions(owner,alert_id,seq);
--> statement-breakpoint
CREATE INDEX audit_alerts_owner ON audit_alerts(owner,created);
--> statement-breakpoint
CREATE TRIGGER audit_alerts_no_delete BEFORE DELETE ON audit_alerts BEGIN SELECT RAISE(ABORT,'Permanent monitoring records cannot be changed or deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_alerts_no_update BEFORE UPDATE ON audit_alerts BEGIN SELECT RAISE(ABORT,'Permanent monitoring records cannot be changed or deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_alerts_no_replace BEFORE INSERT ON audit_alerts WHEN EXISTS(SELECT 1 FROM audit_alerts WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Permanent monitoring records cannot be replaced'); END;
--> statement-breakpoint
CREATE TRIGGER audit_alert_transitions_no_delete BEFORE DELETE ON audit_alert_transitions BEGIN SELECT RAISE(ABORT,'Permanent monitoring records cannot be changed or deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_alert_transitions_no_update BEFORE UPDATE ON audit_alert_transitions BEGIN SELECT RAISE(ABORT,'Permanent monitoring records cannot be changed or deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_alert_transitions_no_replace BEFORE INSERT ON audit_alert_transitions WHEN EXISTS(SELECT 1 FROM audit_alert_transitions WHERE seq=NEW.seq) BEGIN SELECT RAISE(ABORT,'Permanent monitoring records cannot be replaced'); END;
--> statement-breakpoint
CREATE TRIGGER audit_monitor_runs_no_delete BEFORE DELETE ON audit_monitor_runs BEGIN SELECT RAISE(ABORT,'Permanent monitoring records cannot be changed or deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_monitor_runs_no_update BEFORE UPDATE ON audit_monitor_runs BEGIN SELECT RAISE(ABORT,'Permanent monitoring records cannot be changed or deleted'); END;
--> statement-breakpoint
CREATE TRIGGER audit_monitor_runs_no_replace BEFORE INSERT ON audit_monitor_runs WHEN EXISTS(SELECT 1 FROM audit_monitor_runs WHERE id=NEW.id) BEGIN SELECT RAISE(ABORT,'Permanent monitoring records cannot be replaced'); END;
