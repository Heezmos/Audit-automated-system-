DO $audit_migration$ BEGIN IF to_regnamespace('audit_test') IS NULL THEN EXECUTE $audit_schema$CREATE SCHEMA audit_test;
REVOKE ALL ON SCHEMA audit_test FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA audit_test TO authenticated;

CREATE TABLE audit_test.workspaces (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 name text NOT NULL CHECK(length(name) BETWEEN 1 AND 200),
 environment text NOT NULL DEFAULT 'test' CHECK(environment='test'),
 owner_email text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE audit_test.members (
 workspace_id uuid NOT NULL REFERENCES audit_test.workspaces(id) ON DELETE RESTRICT,
 user_id uuid NOT NULL,
 email text NOT NULL,
 display_name text NOT NULL CHECK(length(display_name) BETWEEN 1 AND 200),
 role text NOT NULL CHECK(role IN ('Owner','Auditor','Reviewer','Viewer')),
 active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(workspace_id,user_id), UNIQUE(workspace_id,email)
);
CREATE TABLE audit_test.cases (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 workspace_id uuid NOT NULL REFERENCES audit_test.workspaces(id) ON DELETE RESTRICT,
 entity text NOT NULL CHECK(length(entity) BETWEEN 1 AND 200),
 title text NOT NULL CHECK(length(title) BETWEEN 1 AND 200),
 audit_type text NOT NULL CHECK(audit_type IN ('Financial','Compliance','Performance','Internal')),
 lead text NOT NULL CHECK(length(lead) BETWEEN 1 AND 100),
 scope text NOT NULL CHECK(length(scope) BETWEEN 1 AND 4000),
 due date NOT NULL,
 status text NOT NULL DEFAULT 'Planning' CHECK(status IN ('Planning','Fieldwork')),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE audit_test.evidence (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 workspace_id uuid NOT NULL REFERENCES audit_test.workspaces(id) ON DELETE RESTRICT,
 case_id uuid NOT NULL REFERENCES audit_test.cases(id) ON DELETE RESTRICT,
 filename text NOT NULL CHECK(length(filename) BETWEEN 1 AND 200 AND filename !~ '[[:cntrl:]/\\]'),
 object_key text NOT NULL UNIQUE,
 sha256 text NOT NULL CHECK(sha256 ~ '^[a-f0-9]{64}$'),
 byte_size bigint NOT NULL CHECK(byte_size BETWEEN 1 AND 10485760),
 content_type text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE audit_test.scans (
 seq bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 evidence_id uuid NOT NULL REFERENCES audit_test.evidence(id) ON DELETE RESTRICT,
 sha256 text NOT NULL CHECK(sha256 ~ '^[a-f0-9]{64}$'),
 verdict text NOT NULL CHECK(verdict IN ('clean','infected','error')),
 engine text NOT NULL,
 signatures_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE audit_test.activity (
 seq bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 workspace_id uuid NOT NULL REFERENCES audit_test.workspaces(id) ON DELETE RESTRICT,
 subject_id uuid NOT NULL,
 action text NOT NULL,
 actor_id uuid,
 actor_name text NOT NULL,
 actor_email text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 before_data jsonb,
 after_data jsonb
);
CREATE INDEX audit_test_cases_workspace_idx ON audit_test.cases(workspace_id,updated_at DESC,id DESC);
CREATE INDEX audit_test_evidence_workspace_idx ON audit_test.evidence(workspace_id,created_at DESC,id DESC);
CREATE INDEX audit_test_activity_workspace_idx ON audit_test.activity(workspace_id,seq DESC);
CREATE INDEX audit_test_scans_latest_idx ON audit_test.scans(evidence_id,seq DESC);

ALTER TABLE audit_test.workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_test.members ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_test.cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_test.evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_test.scans ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_test.activity ENABLE ROW LEVEL SECURITY;

-- Bounded private membership helper avoids recursive member policies. It trusts
-- auth.uid() from a Supabase-verified JWT, never user-editable profile metadata.
CREATE FUNCTION audit_test.current_role(p_workspace uuid) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$ SELECT role FROM audit_test.members WHERE workspace_id=p_workspace AND user_id=(SELECT auth.uid()) AND active $$;
REVOKE ALL ON FUNCTION audit_test.current_role(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION audit_test.current_role(uuid) TO authenticated;

CREATE POLICY audit_test_workspace_read ON audit_test.workspaces FOR SELECT TO authenticated USING (audit_test.current_role(id) IS NOT NULL);
CREATE POLICY audit_test_member_read ON audit_test.members FOR SELECT TO authenticated USING (audit_test.current_role(workspace_id) IS NOT NULL);
CREATE POLICY audit_test_case_read ON audit_test.cases FOR SELECT TO authenticated USING (audit_test.current_role(workspace_id) IS NOT NULL);
CREATE POLICY audit_test_case_insert ON audit_test.cases FOR INSERT TO authenticated WITH CHECK (audit_test.current_role(workspace_id) IN ('Owner','Auditor'));
CREATE POLICY audit_test_case_update ON audit_test.cases FOR UPDATE TO authenticated USING (audit_test.current_role(workspace_id) IN ('Owner','Auditor')) WITH CHECK (audit_test.current_role(workspace_id) IN ('Owner','Auditor'));
CREATE POLICY audit_test_evidence_read ON audit_test.evidence FOR SELECT TO authenticated USING (audit_test.current_role(workspace_id) IS NOT NULL);
CREATE POLICY audit_test_evidence_insert ON audit_test.evidence FOR INSERT TO authenticated WITH CHECK (audit_test.current_role(workspace_id) IN ('Owner','Auditor'));
CREATE POLICY audit_test_activity_read ON audit_test.activity FOR SELECT TO authenticated USING (audit_test.current_role(workspace_id) IS NOT NULL);
CREATE POLICY audit_test_scan_read ON audit_test.scans FOR SELECT TO authenticated USING (EXISTS(SELECT 1 FROM audit_test.evidence e WHERE e.id=evidence_id AND audit_test.current_role(e.workspace_id) IS NOT NULL));

GRANT SELECT ON audit_test.workspaces,audit_test.members,audit_test.cases,audit_test.evidence,audit_test.scans,audit_test.activity TO authenticated;
GRANT INSERT ON audit_test.cases,audit_test.evidence TO authenticated;
GRANT UPDATE(entity,title,audit_type,lead,scope,due,status) ON audit_test.cases TO authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA audit_test FROM anon;

CREATE FUNCTION audit_test.preserve_records() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$ BEGIN RAISE EXCEPTION 'Permanent audit records cannot be removed or rewritten' USING ERRCODE='42501'; END $$;
REVOKE ALL ON FUNCTION audit_test.preserve_records() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER audit_test_case_no_delete BEFORE DELETE OR TRUNCATE ON audit_test.cases FOR EACH STATEMENT EXECUTE FUNCTION audit_test.preserve_records();
CREATE TRIGGER audit_test_workspace_no_delete BEFORE DELETE OR TRUNCATE ON audit_test.workspaces FOR EACH STATEMENT EXECUTE FUNCTION audit_test.preserve_records();
CREATE TRIGGER audit_test_member_no_delete BEFORE DELETE OR TRUNCATE ON audit_test.members FOR EACH STATEMENT EXECUTE FUNCTION audit_test.preserve_records();
CREATE TRIGGER audit_test_evidence_no_rewrite BEFORE UPDATE OR DELETE OR TRUNCATE ON audit_test.evidence FOR EACH STATEMENT EXECUTE FUNCTION audit_test.preserve_records();
CREATE TRIGGER audit_test_activity_no_rewrite BEFORE UPDATE OR DELETE OR TRUNCATE ON audit_test.activity FOR EACH STATEMENT EXECUTE FUNCTION audit_test.preserve_records();
CREATE TRIGGER audit_test_scan_no_rewrite BEFORE UPDATE OR DELETE OR TRUNCATE ON audit_test.scans FOR EACH STATEMENT EXECUTE FUNCTION audit_test.preserve_records();

CREATE FUNCTION audit_test.case_version() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$ BEGIN
 IF TG_OP='INSERT' THEN NEW.version:=1; NEW.created_at:=clock_timestamp(); NEW.updated_at:=NEW.created_at;
 ELSE
  IF NEW.id<>OLD.id OR NEW.workspace_id<>OLD.workspace_id OR NEW.created_at<>OLD.created_at THEN RAISE EXCEPTION 'Case identity cannot change'; END IF;
  NEW.version:=OLD.version+1; NEW.updated_at:=clock_timestamp();
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION audit_test.case_version() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER audit_test_case_version BEFORE INSERT OR UPDATE ON audit_test.cases FOR EACH ROW EXECUTE FUNCTION audit_test.case_version();

-- Trigger-only definer appends canonical membership snapshots and revisions.
-- Clients have no INSERT/UPDATE/DELETE grant on the activity table.
CREATE FUNCTION audit_test.track_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$ DECLARE actor audit_test.members; prior jsonb; BEGIN
 IF pg_trigger_depth()<1 THEN RAISE EXCEPTION 'Trigger context required'; END IF;
 SELECT * INTO actor FROM audit_test.members WHERE workspace_id=NEW.workspace_id AND user_id=(SELECT auth.uid()) AND active;
 IF NOT FOUND THEN RAISE EXCEPTION 'Active audit membership required' USING ERRCODE='42501'; END IF;
 IF TG_OP='UPDATE' THEN prior:=to_jsonb(OLD); END IF;
 INSERT INTO audit_test.activity(workspace_id,subject_id,action,actor_id,actor_name,actor_email,before_data,after_data)
 VALUES(NEW.workspace_id,NEW.id,TG_TABLE_NAME||' '||lower(TG_OP),actor.user_id,actor.display_name,actor.email,prior,to_jsonb(NEW));
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION audit_test.track_change() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER audit_test_case_history AFTER INSERT OR UPDATE ON audit_test.cases FOR EACH ROW EXECUTE FUNCTION audit_test.track_change();
CREATE TRIGGER audit_test_evidence_history AFTER INSERT ON audit_test.evidence FOR EACH ROW EXECUTE FUNCTION audit_test.track_change();

CREATE FUNCTION public.audit_test_create_case(p_workspace uuid,p_entity text,p_title text,p_type text,p_lead text,p_scope text,p_due date) RETURNS uuid
LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$ DECLARE result uuid; BEGIN
 INSERT INTO audit_test.cases(workspace_id,entity,title,audit_type,lead,scope,due) VALUES(p_workspace,btrim(p_entity),btrim(p_title),p_type,btrim(p_lead),btrim(p_scope),p_due) RETURNING id INTO result;
 RETURN result;
END $$;
CREATE FUNCTION public.audit_test_update_case(p_id uuid,p_version integer,p_entity text,p_title text,p_type text,p_lead text,p_scope text,p_due date,p_status text) RETURNS integer
LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$ DECLARE result integer; BEGIN
 UPDATE audit_test.cases SET entity=btrim(p_entity),title=btrim(p_title),audit_type=p_type,lead=btrim(p_lead),scope=btrim(p_scope),due=p_due,status=p_status WHERE id=p_id AND version=p_version RETURNING version INTO result;
 IF result IS NULL THEN RAISE EXCEPTION 'Case unavailable or changed; reload before retrying' USING ERRCODE='40001'; END IF;
 RETURN result;
END $$;
CREATE FUNCTION public.audit_test_list_cases(p_workspace uuid,p_before timestamptz DEFAULT 'infinity',p_before_id uuid DEFAULT 'ffffffff-ffff-ffff-ffff-ffffffffffff',p_limit integer DEFAULT 50) RETURNS SETOF audit_test.cases
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $$ SELECT * FROM audit_test.cases WHERE workspace_id=p_workspace AND (updated_at,id)<(p_before,p_before_id) ORDER BY updated_at DESC,id DESC LIMIT greatest(1,least(coalesce(p_limit,50),100)) $$;
CREATE FUNCTION public.audit_test_activity(p_workspace uuid,p_before bigint DEFAULT 9223372036854775807,p_limit integer DEFAULT 100) RETURNS SETOF audit_test.activity
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $$ SELECT * FROM audit_test.activity WHERE workspace_id=p_workspace AND seq<p_before ORDER BY seq DESC LIMIT greatest(1,least(coalesce(p_limit,100),100)) $$;
CREATE FUNCTION public.audit_test_register_evidence(p_case uuid,p_filename text,p_sha256 text,p_size bigint,p_type text) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$ DECLARE ws uuid; eid uuid:=gen_random_uuid(); object_path text; BEGIN
 SELECT workspace_id INTO ws FROM audit_test.cases WHERE id=p_case;
 IF ws IS NULL THEN RAISE EXCEPTION 'Audit case unavailable' USING ERRCODE='42501'; END IF;
 object_path:=ws::text||'/'||eid::text;
 INSERT INTO audit_test.evidence(id,workspace_id,case_id,filename,object_key,sha256,byte_size,content_type) VALUES(eid,ws,p_case,p_filename,object_path,p_sha256,p_size,p_type);
 RETURN jsonb_build_object('id',eid,'bucket','audit-test-evidence','object_key',object_path,'quarantined',true);
END $$;

-- Only these named new functions are exposed. No global API/Auth settings change.
REVOKE ALL ON FUNCTION public.audit_test_create_case(uuid,text,text,text,text,text,date),public.audit_test_update_case(uuid,integer,text,text,text,text,text,date,text),public.audit_test_list_cases(uuid,timestamptz,uuid,integer),public.audit_test_activity(uuid,bigint,integer),public.audit_test_register_evidence(uuid,text,text,bigint,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.audit_test_create_case(uuid,text,text,text,text,text,date),public.audit_test_update_case(uuid,integer,text,text,text,text,text,date,text),public.audit_test_list_cases(uuid,timestamptz,uuid,integer),public.audit_test_activity(uuid,bigint,integer),public.audit_test_register_evidence(uuid,text,text,bigint,text) TO authenticated;

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES('audit-test-evidence','audit-test-evidence',false,10485760,ARRAY['application/pdf','text/csv','text/plain','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.wordprocessingml.document','image/png','image/jpeg','application/octet-stream']);
CREATE POLICY audit_test_storage_upload ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='audit-test-evidence' AND EXISTS(SELECT 1 FROM audit_test.evidence e WHERE e.object_key=name AND audit_test.current_role(e.workspace_id) IN ('Owner','Auditor')));
CREATE POLICY audit_test_storage_upload_boundary ON storage.objects AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK(bucket_id<>'audit-test-evidence' OR EXISTS(SELECT 1 FROM audit_test.evidence e WHERE e.object_key=name AND audit_test.current_role(e.workspace_id) IN ('Owner','Auditor')));
-- No scan writer is granted to clients. Live scanner integration remains required.
CREATE FUNCTION audit_test.file_is_clean(p_key text) RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $$ SELECT EXISTS(SELECT 1 FROM audit_test.evidence e JOIN LATERAL (SELECT * FROM audit_test.scans s WHERE s.evidence_id=e.id ORDER BY seq DESC LIMIT 1) scan ON true WHERE e.object_key=p_key AND audit_test.current_role(e.workspace_id) IS NOT NULL AND scan.verdict='clean' AND scan.sha256=e.sha256 AND scan.created_at>now()-interval '7 days' AND scan.signatures_at>now()-interval '7 days' AND scan.signatures_at<now()+interval '5 minutes') $$;
REVOKE ALL ON FUNCTION audit_test.file_is_clean(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION audit_test.file_is_clean(text) TO authenticated;
CREATE POLICY audit_test_storage_download ON storage.objects FOR SELECT TO authenticated USING(bucket_id='audit-test-evidence' AND audit_test.file_is_clean(name));
CREATE POLICY audit_test_storage_download_boundary ON storage.objects AS RESTRICTIVE FOR SELECT TO authenticated USING(bucket_id<>'audit-test-evidence' OR audit_test.file_is_clean(name));
CREATE POLICY audit_test_storage_no_replace ON storage.objects AS RESTRICTIVE FOR UPDATE TO authenticated USING(bucket_id<>'audit-test-evidence') WITH CHECK(bucket_id<>'audit-test-evidence');
CREATE POLICY audit_test_storage_no_delete ON storage.objects AS RESTRICTIVE FOR DELETE TO authenticated USING(bucket_id<>'audit-test-evidence');
CREATE FUNCTION audit_test.evidence_identity() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM audit_test.cases c WHERE c.id=NEW.case_id AND c.workspace_id=NEW.workspace_id) THEN RAISE EXCEPTION 'Evidence must belong to its audit workspace' USING ERRCODE='42501'; END IF;
 IF NEW.object_key<>NEW.workspace_id::text||'/'||NEW.id::text THEN RAISE EXCEPTION 'Evidence object identity mismatch'; END IF;
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION audit_test.evidence_identity() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER audit_test_evidence_identity BEFORE INSERT ON audit_test.evidence FOR EACH ROW EXECUTE FUNCTION audit_test.evidence_identity();

-- Bootstrap is constrained to a verified auth account matching a workspace email
-- approved by the operator. It cannot create users or grant a Kwik Pay role.
CREATE FUNCTION audit_test.activate_owner_private(p_workspace uuid,p_display_name text) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$ DECLARE uid uuid:=(SELECT auth.uid()); approved_email text; verified_email text; BEGIN
 IF uid IS NULL OR p_display_name IS NULL OR length(btrim(p_display_name)) NOT BETWEEN 1 AND 200 THEN RAISE EXCEPTION 'Verified owner sign-in required' USING ERRCODE='42501'; END IF;
 SELECT owner_email INTO approved_email FROM audit_test.workspaces WHERE id=p_workspace FOR UPDATE;
 SELECT email INTO verified_email FROM auth.users WHERE id=uid AND email_confirmed_at IS NOT NULL AND deleted_at IS NULL;
 IF approved_email IS NULL OR verified_email IS NULL OR lower(verified_email)<>lower(approved_email) THEN RAISE EXCEPTION 'This account is not the approved audit owner' USING ERRCODE='42501'; END IF;
 IF EXISTS(SELECT 1 FROM audit_test.members WHERE workspace_id=p_workspace) THEN
  IF audit_test.current_role(p_workspace)='Owner' THEN RETURN true; END IF;
  RAISE EXCEPTION 'Audit workspace is already activated' USING ERRCODE='42501';
 END IF;
 INSERT INTO audit_test.members(workspace_id,user_id,email,display_name,role) VALUES(p_workspace,uid,lower(verified_email),btrim(p_display_name),'Owner');
 INSERT INTO audit_test.activity(workspace_id,subject_id,action,actor_id,actor_name,actor_email) VALUES(p_workspace,uid,'Verified owner activated',uid,btrim(p_display_name),lower(verified_email));
 RETURN true;
END $$;
REVOKE ALL ON FUNCTION audit_test.activate_owner_private(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION audit_test.activate_owner_private(uuid,text) TO authenticated;

CREATE FUNCTION public.audit_test_activate_owner(p_workspace uuid,p_display_name text) RETURNS boolean LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT audit_test.activate_owner_private(p_workspace,p_display_name) $$;
REVOKE ALL ON FUNCTION public.audit_test_activate_owner(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.audit_test_activate_owner(uuid,text) TO authenticated;
$audit_schema$; ELSE IF NOT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='audit_test' AND p.proname='activate_owner_private') THEN RAISE EXCEPTION 'Unexpected audit test schema; stop for reconciliation'; END IF; END IF; END $audit_migration$;
