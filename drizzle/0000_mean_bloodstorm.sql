CREATE TABLE `audit_cases` (
	`id` text PRIMARY KEY NOT NULL,
	`owner` text NOT NULL,
	`data` text NOT NULL,
	`updated` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `audit_events` (
	`id` text PRIMARY KEY NOT NULL,
	`owner` text NOT NULL,
	`audit_id` text NOT NULL,
	`description` text NOT NULL,
	`created` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `audit_evidence` (
	`id` text PRIMARY KEY NOT NULL,
	`owner` text NOT NULL,
	`audit_id` text NOT NULL,
	`name` text NOT NULL,
	`type` text NOT NULL,
	`hash` text NOT NULL,
	`created` text NOT NULL
);
