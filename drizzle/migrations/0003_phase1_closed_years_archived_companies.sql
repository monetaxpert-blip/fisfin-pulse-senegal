-- =====================================================================
-- FISFIN : compléments de sécurité de l'étape 1. Additif, aucune donnée supprimée.
-- 1. Exercices clôturés : réouverture motivée et tracée, jamais supprimables ensuite.
-- 2. Entreprises archivées : exercices figés, entreprise non modifiable avant restauration.
-- 3. Fonctions d'accès : privilèges vérifiés et documentés, aucune politique modifiée.
-- =====================================================================

-- 1. Traçabilité du cycle de vie d'un exercice (colonnes facultatives)
ALTER TABLE public.fiscal_years
  ADD COLUMN IF NOT EXISTS first_closed_at timestamptz,
  ADD COLUMN IF NOT EXISTS closed_at timestamptz,
  ADD COLUMN IF NOT EXISTS reopened_at timestamptz,
  ADD COLUMN IF NOT EXISTS reopened_by uuid,
  ADD COLUMN IF NOT EXISTS reopen_reason text;
COMMENT ON COLUMN public.fiscal_years.first_closed_at IS 'Première clôture. Immuable : un exercice clôturé au moins une fois n''est jamais supprimable.';
COMMENT ON COLUMN public.fiscal_years.reopen_reason IS 'Motif obligatoire de la dernière réouverture. L''historique complet est dans activity_log.';

-- Rattrapage des exercices déjà clôturés, sans générer de faux événements d'historique
ALTER TABLE public.fiscal_years DISABLE TRIGGER fiscal_years_log;
ALTER TABLE public.fiscal_years DISABLE TRIGGER fiscal_years_updated;
UPDATE public.fiscal_years SET first_closed_at = updated_at, closed_at = updated_at
  WHERE status = 'cloture' AND first_closed_at IS NULL;
ALTER TABLE public.fiscal_years ENABLE TRIGGER fiscal_years_log;
ALTER TABLE public.fiscal_years ENABLE TRIGGER fiscal_years_updated;

ALTER TABLE public.fiscal_years ADD CONSTRAINT fiscal_years_reopen_reason_len
  CHECK (reopen_reason IS NULL OR char_length(reopen_reason) BETWEEN 10 AND 500);

-- Entreprise archivée ?
CREATE OR REPLACE FUNCTION private.company_is_archived(_company_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.companies WHERE id = _company_id AND archived_at IS NOT NULL)
$$;

-- Règles de cycle de vie appliquées à toute écriture, même hors interface
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
    NEW.first_closed_at := coalesce(OLD.first_closed_at, now());
    NEW.closed_at := now();
    NEW.reopen_reason := NULL;  -- une prochaine réouverture exigera un nouveau motif

  ELSE
    NEW.reopen_reason := OLD.reopen_reason;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER fiscal_years_lifecycle_guard BEFORE INSERT OR UPDATE ON public.fiscal_years
  FOR EACH ROW EXECUTE FUNCTION public.fiscal_years_lifecycle();

-- Suppression : interdite si clôturé, déjà clôturé une fois, avec données, ou entreprise archivée
CREATE OR REPLACE FUNCTION public.fiscal_years_guard_delete()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF OLD.status = 'cloture' THEN
    RAISE EXCEPTION 'Un exercice clôturé ne peut pas être supprimé.' USING ERRCODE = 'FS002';
  END IF;
  IF OLD.first_closed_at IS NOT NULL THEN
    RAISE EXCEPTION 'Cet exercice a déjà été clôturé : il reste conservé même après réouverture.' USING ERRCODE = 'FS006';
  END IF;
  IF private.company_is_archived(OLD.company_id) THEN
    RAISE EXCEPTION 'Entreprise archivée : ses exercices ne peuvent être ni créés, ni modifiés, ni supprimés. Restaurez-la d''abord.'
      USING ERRCODE = 'FS007';
  END IF;
  IF private.fiscal_year_has_accounting_data(OLD.id) THEN
    RAISE EXCEPTION 'Cet exercice contient des imports ou des données comptables et ne peut pas être supprimé.' USING ERRCODE = 'FS003';
  END IF;
  RETURN OLD;
END $$;

-- Historique : clôture et réouverture (avec motif) apparaissent explicitement
CREATE OR REPLACE FUNCTION public.log_fiscal_year_change() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r public.fiscal_years; act text; det jsonb;
BEGIN
  r := CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
  IF TG_OP = 'DELETE' AND NOT EXISTS (SELECT 1 FROM public.companies WHERE id = OLD.company_id) THEN RETURN OLD; END IF;
  act := CASE TG_OP WHEN 'INSERT' THEN 'creation' WHEN 'DELETE' THEN 'suppression' ELSE 'modification' END;
  det := jsonb_build_object('libelle', r.label, 'debut', r.start_date, 'fin', r.end_date, 'statut', r.status);
  IF TG_OP = 'UPDATE' AND OLD.status = 'ouvert' AND NEW.status = 'cloture' THEN
    act := 'cloture';
  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'cloture' AND NEW.status = 'ouvert' THEN
    act := 'reouverture';
    det := det || jsonb_build_object('motif', NEW.reopen_reason);
  END IF;
  INSERT INTO public.activity_log(company_id,user_id,action,entity,entity_id,details)
  VALUES (r.company_id, coalesce(auth.uid(), r.created_by), act, 'exercice', r.id, det);
  RETURN r;
END $$;

-- 2. Entreprise archivée : seule la restauration est permise
CREATE OR REPLACE FUNCTION public.companies_guard_update()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.owner_id IS DISTINCT FROM OLD.owner_id THEN
    RAISE EXCEPTION 'Le propriétaire d''une entreprise ne peut pas être modifié.' USING ERRCODE = 'FS005';
  END IF;
  IF OLD.archived_at IS NOT NULL AND NEW.archived_at IS NOT NULL
     AND (NEW.name, NEW.legal_form, NEW.sector, NEW.tax_id, NEW.address, NEW.currency,
          NEW.activity_start_date, NEW.fiscal_year_start_month, NEW.archived_at)
         IS DISTINCT FROM
         (OLD.name, OLD.legal_form, OLD.sector, OLD.tax_id, OLD.address, OLD.currency,
          OLD.activity_start_date, OLD.fiscal_year_start_month, OLD.archived_at) THEN
    RAISE EXCEPTION 'Entreprise archivée : restaurez-la avant toute modification.' USING ERRCODE = 'FS007';
  END IF;
  NEW.created_at := OLD.created_at;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.log_company_change() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.activity_log(company_id,user_id,action,entity,entity_id,details)
    VALUES (NEW.id, coalesce(auth.uid(), NEW.owner_id), 'creation', 'entreprise', NEW.id, jsonb_build_object('nom',NEW.name,'forme',NEW.legal_form));
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO public.activity_log(company_id,user_id,action,entity,entity_id,details)
    VALUES (NEW.id, coalesce(auth.uid(), NEW.owner_id),
      CASE WHEN NEW.archived_at IS NOT NULL AND OLD.archived_at IS NULL THEN 'archivage'
           WHEN NEW.archived_at IS NULL AND OLD.archived_at IS NOT NULL THEN 'restauration'
           ELSE 'modification' END,
      'entreprise', NEW.id, jsonb_build_object('nom',NEW.name));
  END IF;
  RETURN NEW;
END $$;

-- 3. Fonctions privées : non exposées par l'API (schéma private), appelables uniquement
--    depuis les politiques et déclencheurs. Pas d'accès anonyme.
REVOKE EXECUTE ON FUNCTION private.company_is_archived(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION private.company_is_archived(uuid) TO authenticated, service_role;

-- Fonctions publiques utilisées par les politiques RLS : conservées, limitées aux comptes connectés,
-- elles ne répondent que pour l'utilisateur appelant (auth.uid()).
COMMENT ON FUNCTION public.can_access_company(uuid) IS 'RLS : accès de l''utilisateur appelant (auth.uid()) à une entreprise. Ne révèle que ses propres droits. SECURITY DEFINER requis pour éviter la récursion RLS sur companies.';
COMMENT ON FUNCTION public.is_company_owner(uuid) IS 'RLS : l''utilisateur appelant (auth.uid()) est-il propriétaire ? Ne révèle que ses propres droits. SECURITY DEFINER requis pour éviter la récursion RLS sur companies.';

REVOKE EXECUTE ON FUNCTION public.fiscal_years_lifecycle() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fiscal_years_guard_delete(), public.log_fiscal_year_change(),
  public.companies_guard_update(), public.log_company_change() FROM public, anon, authenticated;
