-- =====================================================================
-- FISFIN : durcissement sécurité (étape 1). Additif, aucune donnée supprimée.
-- =====================================================================

-- 0. Schéma privé non exposé par l'API pour les fonctions internes
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM public, anon;
GRANT USAGE ON SCHEMA private TO authenticated;

-- 1. Privilèges explicites (le projet avait hérité de ALL, y compris TRUNCATE, pour anon/authenticated)
REVOKE ALL ON public.profiles, public.companies, public.fiscal_years, public.activity_log FROM anon, authenticated, public;
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.companies TO authenticated;          -- pas de DELETE : archivage uniquement
GRANT SELECT, INSERT, UPDATE, DELETE ON public.fiscal_years TO authenticated;
GRANT SELECT ON public.activity_log TO authenticated;                       -- journal alimenté par triggers uniquement
GRANT ALL ON public.profiles, public.companies, public.fiscal_years, public.activity_log TO service_role;

-- 2. Point unique de contrôle d'accès (préparation au partage futur d'entreprise)
CREATE OR REPLACE FUNCTION private.has_company_access(_user_id uuid, _company_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  -- Aujourd'hui : propriétaire unique. Le partage (membres, rôles) s'ajoutera ici uniquement.
  SELECT _user_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.companies WHERE id = _company_id AND owner_id = _user_id
  )
$$;
REVOKE EXECUTE ON FUNCTION private.has_company_access(uuid, uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION private.has_company_access(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.can_access_company(_company_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT private.has_company_access(auth.uid(), _company_id)
$$;
REVOKE EXECUTE ON FUNCTION public.can_access_company(uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.can_access_company(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.is_company_owner(_company_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.companies WHERE id = _company_id AND owner_id = auth.uid()
  )
$$;
REVOKE EXECUTE ON FUNCTION public.is_company_owner(uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.is_company_owner(uuid) TO authenticated;

-- Lecture : tout utilisateur autorisé ; modification/archivage : propriétaire uniquement
DROP POLICY IF EXISTS "owner select companies" ON public.companies;
CREATE POLICY "access select companies" ON public.companies FOR SELECT TO authenticated
  USING (public.can_access_company(id));
DROP POLICY IF EXISTS "owner update companies" ON public.companies;
CREATE POLICY "owner update companies" ON public.companies FOR UPDATE TO authenticated
  USING (public.is_company_owner(id)) WITH CHECK (owner_id = auth.uid());

-- 3. Interdiction de la suppression définitive d'une entreprise (base de données)
DROP POLICY IF EXISTS "owner delete companies" ON public.companies;

CREATE OR REPLACE FUNCTION public.prevent_company_delete()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  RAISE EXCEPTION 'La suppression définitive d''une entreprise est interdite. Utilisez l''archivage.'
    USING ERRCODE = 'FS001';
END $$;
CREATE TRIGGER companies_no_delete BEFORE DELETE ON public.companies
  FOR EACH ROW EXECUTE FUNCTION public.prevent_company_delete();
CREATE TRIGGER companies_no_truncate BEFORE TRUNCATE ON public.companies
  FOR EACH STATEMENT EXECUTE FUNCTION public.prevent_company_delete();

-- Les données liées ne disparaissent plus en cascade
ALTER TABLE public.fiscal_years DROP CONSTRAINT fiscal_years_company_id_fkey;
ALTER TABLE public.fiscal_years ADD CONSTRAINT fiscal_years_company_id_fkey
  FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE RESTRICT;
ALTER TABLE public.activity_log DROP CONSTRAINT activity_log_company_id_fkey;
ALTER TABLE public.activity_log ADD CONSTRAINT activity_log_company_id_fkey
  FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE RESTRICT;

-- Champs immuables : propriétaire d'une entreprise
CREATE OR REPLACE FUNCTION public.companies_guard_update()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.owner_id IS DISTINCT FROM OLD.owner_id THEN
    RAISE EXCEPTION 'Le propriétaire d''une entreprise ne peut pas être modifié.' USING ERRCODE = 'FS005';
  END IF;
  NEW.created_at := OLD.created_at;
  RETURN NEW;
END $$;
CREATE TRIGGER companies_guard BEFORE UPDATE ON public.companies
  FOR EACH ROW EXECUTE FUNCTION public.companies_guard_update();

-- 4. Exercices : suppression interdite si clôturé ou contenant des données comptables
CREATE OR REPLACE FUNCTION private.fiscal_year_has_accounting_data(_fiscal_year_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  -- Aucune table d'import n'existe encore (phase 2). Chaque future table rattachée
  -- à un exercice (imports, balances, lignes) doit être ajoutée à cette vérification
  -- et référencer fiscal_years avec ON DELETE RESTRICT.
  SELECT false
$$;
REVOKE EXECUTE ON FUNCTION private.fiscal_year_has_accounting_data(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION private.fiscal_year_has_accounting_data(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.fiscal_years_guard_delete()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF OLD.status = 'cloture' THEN
    RAISE EXCEPTION 'Un exercice clôturé ne peut pas être supprimé.' USING ERRCODE = 'FS002';
  END IF;
  IF private.fiscal_year_has_accounting_data(OLD.id) THEN
    RAISE EXCEPTION 'Cet exercice contient des imports ou des données comptables et ne peut pas être supprimé.' USING ERRCODE = 'FS003';
  END IF;
  RETURN OLD;
END $$;
CREATE TRIGGER fiscal_years_no_delete BEFORE DELETE ON public.fiscal_years
  FOR EACH ROW EXECUTE FUNCTION public.fiscal_years_guard_delete();

CREATE OR REPLACE FUNCTION public.prevent_truncate()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  RAISE EXCEPTION 'Vidage de table interdit.' USING ERRCODE = 'FS001';
END $$;
CREATE TRIGGER fiscal_years_no_truncate BEFORE TRUNCATE ON public.fiscal_years
  FOR EACH STATEMENT EXECUTE FUNCTION public.prevent_truncate();
CREATE TRIGGER activity_log_no_truncate BEFORE TRUNCATE ON public.activity_log
  FOR EACH STATEMENT EXECUTE FUNCTION public.prevent_truncate();

-- Champs immuables : entreprise et auteur d'un exercice
CREATE OR REPLACE FUNCTION public.fiscal_years_guard_update()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.company_id IS DISTINCT FROM OLD.company_id THEN
    RAISE EXCEPTION 'Un exercice ne peut pas être rattaché à une autre entreprise.' USING ERRCODE = 'FS005';
  END IF;
  IF NEW.created_by IS DISTINCT FROM OLD.created_by THEN
    RAISE EXCEPTION 'L''auteur d''un exercice ne peut pas être modifié.' USING ERRCODE = 'FS005';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER fiscal_years_guard BEFORE UPDATE ON public.fiscal_years
  FOR EACH ROW EXECUTE FUNCTION public.fiscal_years_guard_update();

-- 5. Entreprise active du profil : doit exister, être accessible et non archivée
ALTER TABLE public.profiles ADD CONSTRAINT profiles_active_company_id_fkey
  FOREIGN KEY (active_company_id) REFERENCES public.companies(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.profiles_validate_active_company()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.active_company_id IS NOT NULL
     AND (TG_OP = 'INSERT' OR NEW.active_company_id IS DISTINCT FROM OLD.active_company_id) THEN
    IF NOT private.has_company_access(NEW.id, NEW.active_company_id)
       OR EXISTS (SELECT 1 FROM public.companies WHERE id = NEW.active_company_id AND archived_at IS NOT NULL) THEN
      RAISE EXCEPTION 'Entreprise active invalide : accès non autorisé ou entreprise archivée.' USING ERRCODE = 'FS004';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER profiles_active_company_check BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.profiles_validate_active_company();

-- Archivage d'une entreprise : elle cesse d'être l'entreprise active des profils concernés
CREATE OR REPLACE FUNCTION public.companies_clear_active_on_archive()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.archived_at IS NOT NULL AND OLD.archived_at IS NULL THEN
    UPDATE public.profiles SET active_company_id = NULL WHERE active_company_id = NEW.id;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER companies_archive_clear_active AFTER UPDATE ON public.companies
  FOR EACH ROW EXECUTE FUNCTION public.companies_clear_active_on_archive();

-- Fonctions de trigger : non appelables directement par les clients
REVOKE EXECUTE ON FUNCTION public.prevent_company_delete(), public.prevent_truncate(), public.companies_guard_update(),
  public.fiscal_years_guard_update(), public.fiscal_years_guard_delete(), public.profiles_validate_active_company(),
  public.companies_clear_active_on_archive() FROM public, anon, authenticated;