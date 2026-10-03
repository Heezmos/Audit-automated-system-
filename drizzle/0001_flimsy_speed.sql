CREATE TABLE `audit_checks` (
	`id` text PRIMARY KEY NOT NULL,
	`owner` text NOT NULL,
	`audit_id` text NOT NULL,
	`data` text NOT NULL,
	`created` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `audit_members` (
	`email` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`role` text NOT NULL,
	`active` text NOT NULL,
	`created` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `audit_workspace` (
	`id` text PRIMARY KEY NOT NULL,
	`owner` text NOT NULL,
	`email` text NOT NULL
);
