CREATE TABLE `audit_ai_runs` (
	`id` text PRIMARY KEY NOT NULL,
	`owner` text NOT NULL,
	`audit_id` text NOT NULL,
	`created_by` text NOT NULL,
	`created` text NOT NULL,
	`mode` text NOT NULL,
	`model` text NOT NULL,
	`status` text NOT NULL,
	`data` text NOT NULL
);
