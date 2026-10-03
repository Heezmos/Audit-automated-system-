BEGIN;
INSERT INTO audit_test.workspaces(id,name,owner_email) VALUES('00000000-0000-4000-8000-000000000001','Rollback fixture','fixture.invalid@example.invalid');
INSERT INTO audit_test.members(workspace_id,user_id,email,display_name,role) VALUES
('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000010','owner@example.invalid','Fixture Owner','Owner'),
('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000011','viewer@example.invalid','Fixture Viewer','Viewer');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000010',true);
DO $$ DECLARE cid uuid; eid jsonb; v integer; BEGIN
 cid:=public.audit_test_create_case('00000000-0000-4000-8000-000000000001','Fictional institution','Backend verification','Internal','Fixture Auditor','Test data only','2026-10-20');
 PERFORM set_config('audit_test.fixture_case',cid::text,true);
 v:=public.audit_test_update_case(cid,1,'Fictional institution','Updated fixture','Internal','Fixture Auditor','Test data only','2026-10-20','Fieldwork');
 IF v<>2 THEN RAISE EXCEPTION 'Version check failed'; END IF;
 IF (SELECT count(*) FROM audit_test.activity WHERE subject_id=cid AND actor_name='Fixture Owner' AND actor_email='owner@example.invalid')<>2 THEN RAISE EXCEPTION 'Named history missing'; END IF;
 IF NOT EXISTS(SELECT 1 FROM audit_test.activity WHERE subject_id=cid AND before_data->>'title'='Backend verification' AND after_data->>'title'='Updated fixture') THEN RAISE EXCEPTION 'Revision missing'; END IF;
 BEGIN
  PERFORM public.audit_test_update_case(cid,1,'Fictional institution','Stale update','Internal','Fixture Auditor','Test','2026-10-20','Fieldwork');
  RAISE EXCEPTION 'Stale update incorrectly allowed';
 EXCEPTION WHEN serialization_failure THEN NULL; END;
 eid:=public.audit_test_register_evidence(cid,'fixture.txt',repeat('a',64),12,'text/plain');
 IF audit_test.file_is_clean(eid->>'object_key') THEN RAISE EXCEPTION 'Unscanned file released'; END IF;
 BEGIN INSERT INTO audit_test.scans(evidence_id,sha256,verdict,engine,signatures_at) VALUES((eid->>'id')::uuid,repeat('a',64),'clean','Forged',now()); RAISE EXCEPTION 'Client scan forgery allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN DELETE FROM audit_test.cases WHERE id=cid; RAISE EXCEPTION 'Case deletion allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE audit_test.activity SET actor_name='Forged'; RAISE EXCEPTION 'History rewriting allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO audit_test.members(workspace_id,user_id,email,display_name,role) VALUES('00000000-0000-4000-8000-000000000001',gen_random_uuid(),'intruder@example.invalid','Intruder','Owner'); RAISE EXCEPTION 'Client membership forgery allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000011',true);
DO $$ BEGIN
 IF (SELECT count(*) FROM public.audit_test_list_cases('00000000-0000-4000-8000-000000000001'))<>1 THEN RAISE EXCEPTION 'Viewer read failed'; END IF;
 BEGIN PERFORM public.audit_test_create_case('00000000-0000-4000-8000-000000000001','Fixture','Denied','Internal','Fixture','Test','2026-10-20'); RAISE EXCEPTION 'Viewer write allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000099',true);
DO $$ BEGIN
 IF (SELECT count(*) FROM public.audit_test_list_cases('00000000-0000-4000-8000-000000000001'))<>0 THEN RAISE EXCEPTION 'Nonmember case leak'; END IF;
 IF (SELECT count(*) FROM public.audit_test_activity('00000000-0000-4000-8000-000000000001'))<>0 THEN RAISE EXCEPTION 'Nonmember history leak'; END IF;
 BEGIN PERFORM public.audit_test_create_case('00000000-0000-4000-8000-000000000001','Fixture','Denied','Internal','Fixture','Test','2026-10-20'); RAISE EXCEPTION 'Nonmember write allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.audit_test_activate_owner('00000000-0000-4000-8000-000000000001','Imposter'); RAISE EXCEPTION 'Unverified owner activation allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN PERFORM public.audit_test_list_cases('00000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'Anonymous API allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
DO $$ BEGIN
 BEGIN DELETE FROM audit_test.activity; RAISE EXCEPTION 'Append-only trigger failed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN TRUNCATE audit_test.activity; RAISE EXCEPTION 'Truncation trigger failed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
ROLLBACK;
SELECT 'PASS: owner create/update, canonical actor and revisions, stale update rejection, file quarantine, denied scan/history/member forgery, viewer and nonmember isolation, anonymous denial, deletion/truncation guards; fixtures rolled back' AS result;
