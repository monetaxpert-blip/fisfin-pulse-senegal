-- =====================================================================
-- FISFIN phase 2 : importation des balances comptables. Additif, aucune donnée supprimée.
-- Tables : balance_imports (une version d'import), balance_lines, balance_import_issues.
-- Écritures client : création d'un brouillon uniquement. Analyse : serveur (service_role).
-- Validation, remplacement, référence, retrait, abandon, confirmation : fonctions dédiées.
-- =====================================================================

CREATE OR REPLACE FUNCTION private.try_uuid(_v text)
RETURNS uuid LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  RETURN _v::uuid;
EXCEPTION WHEN others THEN
  RETURN NULL;
END $$;
REVOKE EXECUTE ON FUNCTION private.try_uuid(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION private.try_uuid(text) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------
CREATE TABLE public.balance_imports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
  fiscal_year_id uuid NOT NULL REFERENCES public.fiscal_years(id) ON DELETE RESTRICT,
  balance_type text NOT NULL CHECK (balance_type IN ('mensuelle', 'annuelle')),
  amount_basis text NOT NULL CHECK (amount_basis IN ('cumulee', 'periodique')),
  period_start date NOT NULL,
  period_end date NOT NULL,
  currency text NOT NULL DEFAULT 'XOF',
  status text NOT NULL DEFAULT 'brouillon'
    CHECK (status IN ('brouillon', 'analyse', 'valide', 'remplace', 'archive', 'abandonne')),
  is_reference boolean NOT NULL DEFAULT false,
  version integer NOT NULL DEFAULT 1,
  supersedes_import_id uuid UNIQUE REFERENCES public.balance_imports(id) ON DELETE RESTRICT,
  replacement_reason text,
  file_name text NOT NULL,
  file_size integer,
  file_path text,
  file_sha256 text,
  content_sha256 text,
  sheet_name text,
  header_row integer,
  column_mapping jsonb NOT NULL DEFAULT '{}'::jsonb,
  excluded_rows jsonb NOT NULL DEFAULT '[]'::jsonb,
  parser_version text,
  summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by uuid NOT NULL DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  analysed_at timestamptz,
  validated_by uuid,
  validated_at timestamptz,
  archived_by uuid,
  archived_at timestamptz,
  archive_reason text,
  abandoned_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT balance_imports_period_order CHECK (period_end >= period_start),
  CONSTRAINT balance_imports_annual_is_cumulative CHECK (balance_type = 'mensuelle' OR amount_basis = 'cumulee'),
  CONSTRAINT balance_imports_reference_only_valid CHECK (NOT is_reference OR status = 'valide'),
  CONSTRAINT balance_imports_replacement_reason_len CHECK (replacement_reason IS NULL OR char_length(replacement_reason) BETWEEN 10 AND 500),
  CONSTRAINT balance_imports_archive_reason_len CHECK (archive_reason IS NULL OR char_length(archive_reason) BETWEEN 10 AND 500),
  CONSTRAINT balance_imports_file_size_max CHECK (file_size IS NULL OR (file_size > 0 AND file_size <= 10485760)),
  CONSTRAINT balance_imports_file_name_len CHECK (char_length(file_name) BETWEEN 1 AND 255),
  CONSTRAINT balance_imports_currency_len CHECK (char_length(currency) = 3)
);
COMMENT ON TABLE public.balance_imports IS 'Une version d''import de balance. Jamais supprimée. Une seule version valide par emplacement, une seule source de référence par période.';
COMMENT ON COLUMN public.balance_imports.is_reference IS 'Source comptable de référence pour (exercice, début, fin). Deux balances couvrant la même période ne sont jamais additionnées.';

CREATE UNIQUE INDEX balance_imports_one_valid_per_slot ON public.balance_imports
  (fiscal_year_id, balance_type, amount_basis, period_start, period_end) WHERE status = 'valide';
CREATE UNIQUE INDEX balance_imports_one_reference_per_period ON public.balance_imports
  (fiscal_year_id, period_start, period_end) WHERE is_reference;
CREATE UNIQUE INDEX balance_imports_file_once_valid ON public.balance_imports
  (company_id, file_sha256) WHERE status = 'valide';
CREATE INDEX balance_imports_company_fy ON public.balance_imports (company_id, fiscal_year_id, period_end);

CREATE TABLE public.balance_lines (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  import_id uuid NOT NULL REFERENCES public.balance_imports(id) ON DELETE RESTRICT,
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
  source_row integer NOT NULL,
  account_number text,
  account_number_raw text,
  account_label text,
  opening_debit numeric(24,6),
  opening_credit numeric(24,6),
  period_debit numeric(24,6),
  period_credit numeric(24,6),
  closing_debit numeric(24,6),
  closing_credit numeric(24,6),
  included boolean NOT NULL DEFAULT true,
  exclusion_reason text,
  raw jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT balance_lines_included_has_account CHECK (NOT included OR account_number IS NOT NULL),
  CONSTRAINT balance_lines_excluded_has_reason CHECK (included OR exclusion_reason IS NOT NULL)
);
CREATE UNIQUE INDEX balance_lines_unique_account ON public.balance_lines (import_id, account_number) WHERE included;
CREATE INDEX balance_lines_import ON public.balance_lines (import_id, source_row);

CREATE TABLE public.balance_import_issues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  import_id uuid NOT NULL REFERENCES public.balance_imports(id) ON DELETE RESTRICT,
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
  source_row integer,
  code text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('bloquant', 'avertissement', 'a_verifier')),
  message text NOT NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  acknowledged_by uuid,
  acknowledged_at timestamptz,
  acknowledgement_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT balance_issues_ack_only_review CHECK (acknowledged_at IS NULL OR severity = 'a_verifier'),
  CONSTRAINT balance_issues_note_len CHECK (acknowledgement_note IS NULL OR char_length(acknowledgement_note) <= 500)
);
CREATE INDEX balance_import_issues_import ON public.balance_import_issues (import_id, severity);

-- ---------------------------------------------------------------------
-- 2. Privilèges minimaux
-- ---------------------------------------------------------------------
REVOKE ALL ON public.balance_imports, public.balance_lines, public.balance_import_issues FROM anon, authenticated, public;
GRANT SELECT, INSERT ON public.balance_imports TO authenticated;
GRANT SELECT ON public.balance_lines, public.balance_import_issues TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.balance_imports, public.balance_lines, public.balance_import_issues TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.balance_lines_id_seq TO service_role;

-- ---------------------------------------------------------------------
-- 3. RLS : point unique can_access_company
-- ---------------------------------------------------------------------
ALTER TABLE public.balance_imports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.balance_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.balance_import_issues ENABLE ROW LEVEL SECURITY;

CREATE POLICY "imports select" ON public.balance_imports FOR SELECT TO authenticated
  USING (public.can_access_company(company_id));
CREATE POLICY "imports insert draft" ON public.balance_imports FOR INSERT TO authenticated
  WITH CHECK (public.can_access_company(company_id) AND created_by = auth.uid());
CREATE POLICY "lines select" ON public.balance_lines FOR SELECT TO authenticated
  USING (public.can_access_company(company_id));
CREATE POLICY "issues select" ON public.balance_import_issues FOR SELECT TO authenticated
  USING (public.can_access_company(company_id));

-- ---------------------------------------------------------------------
-- 4. Règles d'intégrité des imports (s'appliquent à toute écriture)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.balance_imports_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE fy public.fiscal_years; expected_end date; ok_transition boolean;
BEGIN
  SELECT * INTO fy FROM public.fiscal_years WHERE id = NEW.fiscal_year_id;
  IF NOT FOUND OR fy.company_id <> NEW.company_id THEN
    RAISE EXCEPTION 'L''exercice choisi n''appartient pas à cette entreprise.' USING ERRCODE = 'FS013';
  END IF;
  IF private.company_is_archived(NEW.company_id) THEN
    RAISE EXCEPTION 'Entreprise archivée : restaurez-la avant toute opération d''import.' USING ERRCODE = 'FS007';
  END IF;
  IF fy.status = 'cloture' THEN
    RAISE EXCEPTION 'Exercice clôturé : rouvrez-le avec un motif avant d''importer ou de modifier une balance.' USING ERRCODE = 'FS010';
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- Valeurs gérées uniquement par le système
    NEW.status := 'brouillon'; NEW.is_reference := false; NEW.version := 1;
    NEW.supersedes_import_id := NULL; NEW.replacement_reason := NULL;
    NEW.file_path := NULL; NEW.file_sha256 := NULL; NEW.content_sha256 := NULL;
    NEW.parser_version := NULL; NEW.summary := '{}'::jsonb; NEW.analysed_at := NULL;
    NEW.validated_by := NULL; NEW.validated_at := NULL; NEW.archived_by := NULL;
    NEW.archived_at := NULL; NEW.archive_reason := NULL; NEW.abandoned_at := NULL;
    NEW.created_at := now(); NEW.updated_at := now();
    NEW.currency := (SELECT currency FROM public.companies WHERE id = NEW.company_id);
    IF auth.uid() IS NOT NULL THEN NEW.created_by := auth.uid(); END IF;

    -- Contrôle strict de la période par rapport à l'exercice et au type
    IF NEW.period_start < fy.start_date OR NEW.period_end > fy.end_date THEN
      RAISE EXCEPTION 'La période doit être comprise dans l''exercice (% au %).', fy.start_date, fy.end_date USING ERRCODE = 'FS013';
    END IF;
    IF NEW.balance_type = 'annuelle' THEN
      IF NEW.period_start <> fy.start_date OR NEW.period_end <> fy.end_date THEN
        RAISE EXCEPTION 'Une balance annuelle couvre l''exercice complet (% au %).', fy.start_date, fy.end_date USING ERRCODE = 'FS013';
      END IF;
    ELSE
      expected_end := least((date_trunc('month', NEW.period_end) + interval '1 month - 1 day')::date, fy.end_date);
      IF NEW.period_end <> expected_end THEN
        RAISE EXCEPTION 'Une balance mensuelle se termine le dernier jour du mois (ou à la fin de l''exercice).' USING ERRCODE = 'FS013';
      END IF;
      IF NEW.amount_basis = 'cumulee' AND NEW.period_start <> fy.start_date THEN
        RAISE EXCEPTION 'Une balance cumulée commence au début de l''exercice (%).', fy.start_date USING ERRCODE = 'FS013';
      END IF;
      IF NEW.amount_basis = 'periodique'
         AND NEW.period_start <> greatest(date_trunc('month', NEW.period_end)::date, fy.start_date) THEN
        RAISE EXCEPTION 'Une balance de mouvements mensuels couvre un seul mois.' USING ERRCODE = 'FS013';
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  -- UPDATE : identité de l'import immuable
  IF (NEW.company_id, NEW.fiscal_year_id, NEW.balance_type, NEW.amount_basis, NEW.period_start, NEW.period_end,
      NEW.currency, NEW.created_by, NEW.created_at, NEW.file_name, NEW.file_size)
     IS DISTINCT FROM
     (OLD.company_id, OLD.fiscal_year_id, OLD.balance_type, OLD.amount_basis, OLD.period_start, OLD.period_end,
      OLD.currency, OLD.created_by, OLD.created_at, OLD.file_name, OLD.file_size) THEN
    RAISE EXCEPTION 'Les informations d''identification d''un import ne peuvent pas être modifiées.' USING ERRCODE = 'FS012';
  END IF;

  ok_transition := NEW.status = OLD.status
    OR (OLD.status = 'brouillon' AND NEW.status IN ('analyse', 'abandonne'))
    OR (OLD.status = 'analyse' AND NEW.status IN ('brouillon', 'valide', 'abandonne'))
    OR (OLD.status = 'valide' AND NEW.status IN ('remplace', 'archive'));
  IF NOT ok_transition OR OLD.status IN ('remplace', 'archive', 'abandonne') AND NEW IS DISTINCT FROM OLD THEN
    RAISE EXCEPTION 'Changement de statut d''import non autorisé (% vers %).', OLD.status, NEW.status USING ERRCODE = 'FS011';
  END IF;

  -- Contenu figé dès la validation
  IF OLD.status NOT IN ('brouillon', 'analyse')
     AND (NEW.file_path, NEW.file_sha256, NEW.content_sha256, NEW.sheet_name, NEW.header_row, NEW.column_mapping,
          NEW.excluded_rows, NEW.parser_version, NEW.summary, NEW.analysed_at, NEW.version, NEW.supersedes_import_id,
          NEW.replacement_reason, NEW.validated_by, NEW.validated_at)
         IS DISTINCT FROM
         (OLD.file_path, OLD.file_sha256, OLD.content_sha256, OLD.sheet_name, OLD.header_row, OLD.column_mapping,
          OLD.excluded_rows, OLD.parser_version, OLD.summary, OLD.analysed_at, OLD.version, OLD.supersedes_import_id,
          OLD.replacement_reason, OLD.validated_by, OLD.validated_at) THEN
    RAISE EXCEPTION 'Une balance validée, remplacée ou archivée ne peut pas être modifiée.' USING ERRCODE = 'FS012';
  END IF;
  IF NEW.status <> 'valide' THEN NEW.is_reference := false; END IF;
  NEW.updated_at := now();
  RETURN NEW;
END $$;
CREATE TRIGGER balance_imports_guard BEFORE INSERT OR UPDATE ON public.balance_imports
  FOR EACH ROW EXECUTE FUNCTION public.balance_imports_guard();

CREATE OR REPLACE FUNCTION public.balance_children_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE parent public.balance_imports; r record;
BEGIN
  r := CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
  SELECT * INTO parent FROM public.balance_imports WHERE id = r.import_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Import introuvable.' USING ERRCODE = 'FS012';
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.company_id := parent.company_id;
    IF parent.status NOT IN ('brouillon', 'analyse') THEN
      RAISE EXCEPTION 'Une balance validée, remplacée ou archivée ne peut pas être modifiée.' USING ERRCODE = 'FS012';
    END IF;
    RETURN NEW;
  END IF;
  IF TG_OP = 'DELETE' THEN
    IF parent.status NOT IN ('brouillon', 'analyse') THEN
      RAISE EXCEPTION 'Une balance validée, remplacée ou archivée ne peut pas être modifiée.' USING ERRCODE = 'FS012';
    END IF;
    RETURN OLD;
  END IF;
  -- UPDATE : lignes jamais modifiées ; anomalies : seule la confirmation avant validation
  IF TG_TABLE_NAME = 'balance_import_issues' AND parent.status = 'analyse'
     AND (NEW.import_id, NEW.company_id, NEW.source_row, NEW.code, NEW.severity, NEW.message, NEW.details, NEW.created_at)
         IS NOT DISTINCT FROM
         (OLD.import_id, OLD.company_id, OLD.source_row, OLD.code, OLD.severity, OLD.message, OLD.details, OLD.created_at) THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'Les lignes et anomalies d''un import ne peuvent pas être modifiées.' USING ERRCODE = 'FS012';
END $$;
CREATE TRIGGER balance_lines_guard BEFORE INSERT OR UPDATE OR DELETE ON public.balance_lines
  FOR EACH ROW EXECUTE FUNCTION public.balance_children_guard();
CREATE TRIGGER balance_issues_guard BEFORE INSERT OR UPDATE OR DELETE ON public.balance_import_issues
  FOR EACH ROW EXECUTE FUNCTION public.balance_children_guard();

CREATE TRIGGER balance_imports_no_truncate BEFORE TRUNCATE ON public.balance_imports
  FOR EACH STATEMENT EXECUTE FUNCTION public.prevent_truncate();
CREATE TRIGGER balance_lines_no_truncate BEFORE TRUNCATE ON public.balance_lines
  FOR EACH STATEMENT EXECUTE FUNCTION public.prevent_truncate();
CREATE TRIGGER balance_issues_no_truncate BEFORE TRUNCATE ON public.balance_import_issues
  FOR EACH STATEMENT EXECUTE FUNCTION public.prevent_truncate();

-- ---------------------------------------------------------------------
-- 5. Historique
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_balance_import_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE act text; det jsonb;
BEGIN
  det := jsonb_build_object('fichier', NEW.file_name, 'type', NEW.balance_type, 'nature', NEW.amount_basis,
                            'debut', NEW.period_start, 'fin', NEW.period_end, 'version', NEW.version);
  IF TG_OP = 'INSERT' THEN
    act := 'creation';
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    act := CASE NEW.status WHEN 'analyse' THEN 'analyse' WHEN 'brouillon' THEN 'reprise'
                           WHEN 'valide' THEN 'validation' WHEN 'remplace' THEN 'remplacement'
                           WHEN 'archive' THEN 'retrait' WHEN 'abandonne' THEN 'abandon' END;
    IF NEW.status = 'archive' THEN det := det || jsonb_build_object('motif', NEW.archive_reason); END IF;
    IF NEW.status = 'valide' AND NEW.replacement_reason IS NOT NULL THEN det := det || jsonb_build_object('motif', NEW.replacement_reason); END IF;
    IF NEW.status = 'analyse' THEN det := det || jsonb_build_object('anomalies', NEW.summary->'issues'); END IF;
  ELSIF NEW.is_reference AND NOT OLD.is_reference THEN
    act := 'reference';
  ELSIF OLD.status = 'analyse' AND NEW.analysed_at IS DISTINCT FROM OLD.analysed_at THEN
    act := 'analyse';
    det := det || jsonb_build_object('anomalies', NEW.summary->'issues');
  ELSE
    RETURN NEW;
  END IF;
  INSERT INTO public.activity_log(company_id, user_id, action, entity, entity_id, details)
  VALUES (NEW.company_id, coalesce(auth.uid(), NEW.created_by), act, 'import', NEW.id, det);
  RETURN NEW;
END $$;
CREATE TRIGGER balance_imports_log AFTER INSERT OR UPDATE ON public.balance_imports
  FOR EACH ROW EXECUTE FUNCTION public.log_balance_import_change();

CREATE OR REPLACE FUNCTION public.log_balance_issue_ack()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.acknowledged_at IS NOT NULL AND OLD.acknowledged_at IS NULL THEN
    INSERT INTO public.activity_log(company_id, user_id, action, entity, entity_id, details)
    VALUES (NEW.company_id, coalesce(auth.uid(), NEW.acknowledged_by), 'confirmation_anomalie', 'import', NEW.import_id,
            jsonb_build_object('code', NEW.code, 'ligne', NEW.source_row, 'commentaire', NEW.acknowledgement_note));
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER balance_issues_log AFTER UPDATE ON public.balance_import_issues
  FOR EACH ROW EXECUTE FUNCTION public.log_balance_issue_ack();

-- ---------------------------------------------------------------------
-- 6. Fonctions de cycle de vie (répondent pour auth.uid(), prennent un identifiant d'import)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.lock_import_for_caller(_import_id uuid)
RETURNS public.balance_imports LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE imp public.balance_imports;
BEGIN
  SELECT * INTO imp FROM public.balance_imports WHERE id = _import_id FOR UPDATE;
  IF NOT FOUND OR NOT private.has_company_access(auth.uid(), imp.company_id) THEN
    RAISE EXCEPTION 'Import introuvable ou accès non autorisé.' USING ERRCODE = '42501';
  END IF;
  RETURN imp;
END $$;
REVOKE EXECUTE ON FUNCTION private.lock_import_for_caller(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION private.lock_import_for_caller(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.validate_balance_import(
  _import_id uuid, _replace boolean DEFAULT false, _reason text DEFAULT NULL, _make_reference boolean DEFAULT false)
RETURNS public.balance_imports LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE imp public.balance_imports; prev public.balance_imports; ref_id uuid; was_ref boolean := false; n int;
BEGIN
  imp := private.lock_import_for_caller(_import_id);
  IF imp.status <> 'analyse' THEN
    RAISE EXCEPTION 'Seul un import analysé peut être validé.' USING ERRCODE = 'FS011';
  END IF;
  -- Sérialise les validations sur une même période d'un exercice
  PERFORM pg_advisory_xact_lock(hashtext(imp.fiscal_year_id::text || imp.period_start::text || imp.period_end::text));

  SELECT count(*) INTO n FROM public.balance_import_issues WHERE import_id = imp.id AND severity = 'bloquant';
  IF n > 0 THEN
    RAISE EXCEPTION 'Des anomalies bloquantes empêchent la validation (%).', n USING ERRCODE = 'FS015';
  END IF;
  SELECT count(*) INTO n FROM public.balance_import_issues WHERE import_id = imp.id AND severity = 'a_verifier' AND acknowledged_at IS NULL;
  IF n > 0 THEN
    RAISE EXCEPTION 'Toutes les anomalies à vérifier doivent être confirmées (% restantes).', n USING ERRCODE = 'FS016';
  END IF;
  IF imp.file_sha256 IS NULL OR imp.content_sha256 IS NULL OR imp.analysed_at IS NULL THEN
    RAISE EXCEPTION 'L''analyse de cet import est incomplète.' USING ERRCODE = 'FS011';
  END IF;
  IF EXISTS (SELECT 1 FROM public.balance_imports WHERE company_id = imp.company_id AND status = 'valide'
             AND (file_sha256 = imp.file_sha256 OR content_sha256 = imp.content_sha256)) THEN
    RAISE EXCEPTION 'Ce fichier ou ce contenu a déjà été importé.' USING ERRCODE = 'FS017';
  END IF;

  SELECT * INTO prev FROM public.balance_imports
   WHERE fiscal_year_id = imp.fiscal_year_id AND balance_type = imp.balance_type AND amount_basis = imp.amount_basis
     AND period_start = imp.period_start AND period_end = imp.period_end AND status = 'valide'
   FOR UPDATE;
  IF FOUND THEN
    IF NOT coalesce(_replace, false) THEN
      RAISE EXCEPTION 'Une balance validée existe déjà pour cette période. Choisissez explicitement de la remplacer, avec un motif.' USING ERRCODE = 'FS014';
    END IF;
    IF _reason IS NULL OR char_length(btrim(_reason)) NOT BETWEEN 10 AND 500 THEN
      RAISE EXCEPTION 'Un motif de 10 à 500 caractères est obligatoire.' USING ERRCODE = 'FS018';
    END IF;
    was_ref := prev.is_reference;
    UPDATE public.balance_imports SET status = 'remplace', is_reference = false WHERE id = prev.id;
    imp.version := prev.version + 1;
    imp.supersedes_import_id := prev.id;
    imp.replacement_reason := btrim(_reason);
  END IF;

  SELECT id INTO ref_id FROM public.balance_imports
   WHERE fiscal_year_id = imp.fiscal_year_id AND period_start = imp.period_start AND period_end = imp.period_end
     AND is_reference FOR UPDATE;
  IF ref_id IS NOT NULL AND coalesce(_make_reference, false) THEN
    UPDATE public.balance_imports SET is_reference = false WHERE id = ref_id;
    ref_id := NULL;
  END IF;

  UPDATE public.balance_imports SET
    status = 'valide', validated_by = auth.uid(), validated_at = now(),
    version = imp.version, supersedes_import_id = imp.supersedes_import_id, replacement_reason = imp.replacement_reason,
    is_reference = (ref_id IS NULL)
  WHERE id = imp.id RETURNING * INTO imp;
  RETURN imp;
END $$;

CREATE OR REPLACE FUNCTION public.set_reference_balance_import(_import_id uuid)
RETURNS public.balance_imports LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE imp public.balance_imports;
BEGIN
  imp := private.lock_import_for_caller(_import_id);
  IF imp.status <> 'valide' THEN
    RAISE EXCEPTION 'Seule une balance validée peut devenir la source de référence.' USING ERRCODE = 'FS011';
  END IF;
  IF imp.is_reference THEN RETURN imp; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(imp.fiscal_year_id::text || imp.period_start::text || imp.period_end::text));
  UPDATE public.balance_imports SET is_reference = false
   WHERE fiscal_year_id = imp.fiscal_year_id AND period_start = imp.period_start AND period_end = imp.period_end AND is_reference;
  UPDATE public.balance_imports SET is_reference = true WHERE id = imp.id RETURNING * INTO imp;
  RETURN imp;
END $$;

CREATE OR REPLACE FUNCTION public.archive_balance_import(_import_id uuid, _reason text)
RETURNS public.balance_imports LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE imp public.balance_imports;
BEGIN
  imp := private.lock_import_for_caller(_import_id);
  IF imp.status <> 'valide' THEN
    RAISE EXCEPTION 'Seule une balance validée peut être retirée.' USING ERRCODE = 'FS011';
  END IF;
  IF _reason IS NULL OR char_length(btrim(_reason)) NOT BETWEEN 10 AND 500 THEN
    RAISE EXCEPTION 'Un motif de 10 à 500 caractères est obligatoire.' USING ERRCODE = 'FS018';
  END IF;
  UPDATE public.balance_imports SET status = 'archive', is_reference = false, archived_by = auth.uid(),
         archived_at = now(), archive_reason = btrim(_reason)
   WHERE id = imp.id RETURNING * INTO imp;
  RETURN imp;
END $$;

CREATE OR REPLACE FUNCTION public.abandon_balance_import(_import_id uuid)
RETURNS public.balance_imports LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE imp public.balance_imports;
BEGIN
  imp := private.lock_import_for_caller(_import_id);
  IF imp.status NOT IN ('brouillon', 'analyse') THEN
    RAISE EXCEPTION 'Seul un import non validé peut être abandonné.' USING ERRCODE = 'FS011';
  END IF;
  UPDATE public.balance_imports SET status = 'abandonne', abandoned_at = now() WHERE id = imp.id RETURNING * INTO imp;
  RETURN imp;
END $$;

CREATE OR REPLACE FUNCTION public.acknowledge_balance_issue(_issue_id uuid, _note text DEFAULT NULL)
RETURNS public.balance_import_issues LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE iss public.balance_import_issues; imp public.balance_imports;
BEGIN
  SELECT * INTO iss FROM public.balance_import_issues WHERE id = _issue_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Anomalie introuvable ou accès non autorisé.' USING ERRCODE = '42501';
  END IF;
  imp := private.lock_import_for_caller(iss.import_id);
  IF iss.severity <> 'a_verifier' THEN
    RAISE EXCEPTION 'Seule une anomalie à vérifier peut être confirmée. Une anomalie bloquante doit être corrigée.' USING ERRCODE = 'FS015';
  END IF;
  IF imp.status <> 'analyse' THEN
    RAISE EXCEPTION 'Cet import n''est plus en cours de vérification.' USING ERRCODE = 'FS011';
  END IF;
  IF _note IS NOT NULL AND char_length(_note) > 500 THEN
    RAISE EXCEPTION 'Commentaire limité à 500 caractères.' USING ERRCODE = '23514';
  END IF;
  UPDATE public.balance_import_issues SET acknowledged_by = auth.uid(), acknowledged_at = now(),
         acknowledgement_note = nullif(btrim(coalesce(_note, '')), '')
   WHERE id = iss.id AND acknowledged_at IS NULL RETURNING * INTO iss;
  IF iss.id IS NULL THEN SELECT * INTO iss FROM public.balance_import_issues WHERE id = _issue_id; END IF;
  RETURN iss;
END $$;

REVOKE EXECUTE ON FUNCTION public.validate_balance_import(uuid, boolean, text, boolean),
  public.set_reference_balance_import(uuid), public.archive_balance_import(uuid, text),
  public.abandon_balance_import(uuid), public.acknowledge_balance_issue(uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.validate_balance_import(uuid, boolean, text, boolean),
  public.set_reference_balance_import(uuid), public.archive_balance_import(uuid, text),
  public.abandon_balance_import(uuid), public.acknowledge_balance_issue(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.balance_imports_guard(), public.balance_children_guard(),
  public.log_balance_import_change(), public.log_balance_issue_ack() FROM public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 7. Exercices : données comptables, clôture bloquée par un import en cours, dates figées
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.fiscal_year_has_accounting_data(_fiscal_year_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.balance_imports WHERE fiscal_year_id = _fiscal_year_id)
$$;

CREATE OR REPLACE FUNCTION public.fiscal_years_lifecycle()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF private.company_is_archived(NEW.company_id) THEN
    RAISE EXCEPTION 'Entreprise archivée : ses exercices ne peuvent être ni créés, ni modifiés, ni supprimés. Restaurez-la d''abord.'
      USING ERRCODE = 'FS007';
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.first_closed_at := CASE WHEN NEW.status = 'cloture' THEN now() END;
    NEW.closed_at := NEW.first_closed_at;
    NEW.reopened_at := NULL; NEW.reopened_by := NULL; NEW.reopen_reason := NULL;
    RETURN NEW;
  END IF;

  -- Champs de traçabilité : jamais saisis librement
  NEW.first_closed_at := OLD.first_closed_at;
  NEW.closed_at := OLD.closed_at;
  NEW.reopened_at := OLD.reopened_at;
  NEW.reopened_by := OLD.reopened_by;

  -- Phase 2 : les dates d'un exercice contenant des imports sont figées (affectation des périodes)
  IF (NEW.start_date, NEW.end_date) IS DISTINCT FROM (OLD.start_date, OLD.end_date)
     AND EXISTS (SELECT 1 FROM public.balance_imports WHERE fiscal_year_id = OLD.id AND status <> 'abandonne') THEN
    RAISE EXCEPTION 'Les dates d''un exercice contenant des balances importées ne peuvent pas être modifiées.' USING ERRCODE = 'FS020';
  END IF;

  IF OLD.status = 'cloture' AND NEW.status = 'cloture' THEN
    IF (NEW.label, NEW.start_date, NEW.end_date) IS DISTINCT FROM (OLD.label, OLD.start_date, OLD.end_date) THEN
      RAISE EXCEPTION 'Un exercice clôturé ne peut pas être modifié. Rouvrez-le d''abord avec un motif.' USING ERRCODE = 'FS008';
    END IF;
    NEW.reopen_reason := OLD.reopen_reason;

  ELSIF OLD.status = 'cloture' AND NEW.status = 'ouvert' THEN
    -- Réouverture : motif nouveau et obligatoire, aucune autre modification simultanée
    IF NEW.reopen_reason IS NULL OR char_length(btrim(NEW.reopen_reason)) < 10
       OR NEW.reopen_reason IS NOT DISTINCT FROM OLD.reopen_reason THEN
      RAISE EXCEPTION 'La réouverture d''un exercice clôturé exige un motif d''au moins 10 caractères.' USING ERRCODE = 'FS009';
    END IF;
    IF (NEW.label, NEW.start_date, NEW.end_date) IS DISTINCT FROM (OLD.label, OLD.start_date, OLD.end_date) THEN
      RAISE EXCEPTION 'Un exercice clôturé ne peut pas être modifié. Rouvrez-le d''abord avec un motif.' USING ERRCODE = 'FS008';
    END IF;
    NEW.reopen_reason := btrim(NEW.reopen_reason);
    NEW.reopened_at := now();
    NEW.reopened_by := auth.uid();

  ELSIF OLD.status = 'ouvert' AND NEW.status = 'cloture' THEN
    -- Phase 2 : clôture impossible tant qu'un import est en brouillon ou en analyse
    IF EXISTS (SELECT 1 FROM public.balance_imports WHERE fiscal_year_id = OLD.id AND status IN ('brouillon', 'analyse')) THEN
      RAISE EXCEPTION 'Clôture impossible : un import est encore en brouillon ou en cours d''analyse. Validez-le ou abandonnez-le.' USING ERRCODE = 'FS019';
    END IF;
    NEW.first_closed_at := coalesce(OLD.first_closed_at, now());
    NEW.closed_at := now();
    NEW.reopen_reason := NULL;  -- une prochaine réouverture exigera un nouveau motif

  ELSE
    NEW.reopen_reason := OLD.reopen_reason;
  END IF;
  RETURN NEW;
END $$;
REVOKE EXECUTE ON FUNCTION public.fiscal_years_lifecycle() FROM public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 8. Stockage privé des fichiers sources (bucket "balances", créé hors migration)
--    Chemin imposé : {company_id}/{import_id}/source.xlsx. Ni remplacement ni suppression.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.balance_upload_allowed(_name text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT auth.uid() IS NOT NULL
     AND array_length(string_to_array(_name, '/'), 1) = 3
     AND split_part(_name, '/', 3) = 'source.xlsx'
     AND EXISTS (
       SELECT 1 FROM public.balance_imports i
        WHERE i.id = private.try_uuid(split_part(_name, '/', 2))
          AND i.company_id = private.try_uuid(split_part(_name, '/', 1))
          AND i.status = 'brouillon'
          AND i.created_by = auth.uid()
          AND private.has_company_access(auth.uid(), i.company_id))
$$;
REVOKE EXECUTE ON FUNCTION private.balance_upload_allowed(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION private.balance_upload_allowed(text) TO authenticated;

CREATE POLICY "balances read" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'balances' AND public.can_access_company(private.try_uuid(split_part(name, '/', 1))));
CREATE POLICY "balances upload draft" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'balances' AND private.balance_upload_allowed(name));
