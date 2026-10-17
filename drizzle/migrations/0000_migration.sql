
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text,
  job_title text,
  phone text,
  active_company_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own profile select" ON public.profiles FOR SELECT TO authenticated USING (id = auth.uid());
CREATE POLICY "own profile insert" ON public.profiles FOR INSERT TO authenticated WITH CHECK (id = auth.uid());
CREATE POLICY "own profile update" ON public.profiles FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());

CREATE TABLE public.companies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  name text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 200),
  legal_form text NOT NULL CHECK (char_length(legal_form) BETWEEN 1 AND 50),
  sector text NOT NULL CHECK (char_length(sector) BETWEEN 1 AND 100),
  tax_id text CHECK (tax_id IS NULL OR char_length(tax_id) <= 50),
  address text CHECK (address IS NULL OR char_length(address) <= 300),
  currency text NOT NULL DEFAULT 'XOF' CHECK (char_length(currency) = 3),
  activity_start_date date,
  fiscal_year_start_month smallint NOT NULL DEFAULT 1 CHECK (fiscal_year_start_month BETWEEN 1 AND 12),
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX companies_owner_idx ON public.companies(owner_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.companies TO authenticated;
GRANT ALL ON public.companies TO service_role;
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.can_access_company(_company_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.companies WHERE id = _company_id AND owner_id = auth.uid())
$$;
REVOKE EXECUTE ON FUNCTION public.can_access_company(uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.can_access_company(uuid) TO authenticated;

CREATE POLICY "owner select companies" ON public.companies FOR SELECT TO authenticated USING (owner_id = auth.uid());
CREATE POLICY "owner insert companies" ON public.companies FOR INSERT TO authenticated WITH CHECK (owner_id = auth.uid());
CREATE POLICY "owner update companies" ON public.companies FOR UPDATE TO authenticated USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());
CREATE POLICY "owner delete companies" ON public.companies FOR DELETE TO authenticated USING (owner_id = auth.uid());

CREATE TABLE public.fiscal_years (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  label text NOT NULL CHECK (char_length(label) BETWEEN 1 AND 50),
  start_date date NOT NULL,
  end_date date NOT NULL,
  status text NOT NULL DEFAULT 'ouvert' CHECK (status IN ('ouvert','cloture')),
  created_by uuid NOT NULL DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (end_date > start_date),
  UNIQUE (company_id, label)
);
CREATE INDEX fiscal_years_company_idx ON public.fiscal_years(company_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.fiscal_years TO authenticated;
GRANT ALL ON public.fiscal_years TO service_role;
ALTER TABLE public.fiscal_years ENABLE ROW LEVEL SECURITY;
CREATE POLICY "fy select" ON public.fiscal_years FOR SELECT TO authenticated USING (public.can_access_company(company_id));
CREATE POLICY "fy insert" ON public.fiscal_years FOR INSERT TO authenticated WITH CHECK (public.can_access_company(company_id) AND created_by = auth.uid());
CREATE POLICY "fy update" ON public.fiscal_years FOR UPDATE TO authenticated USING (public.can_access_company(company_id)) WITH CHECK (public.can_access_company(company_id));
CREATE POLICY "fy delete" ON public.fiscal_years FOR DELETE TO authenticated USING (public.can_access_company(company_id));

-- Overlap guard
CREATE OR REPLACE FUNCTION public.fiscal_years_no_overlap()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.fiscal_years f WHERE f.company_id = NEW.company_id AND f.id <> NEW.id
     AND daterange(f.start_date, f.end_date, '[]') && daterange(NEW.start_date, NEW.end_date, '[]')) THEN
    RAISE EXCEPTION 'Cet exercice chevauche un exercice existant.' USING ERRCODE = '23P01';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER fiscal_years_overlap BEFORE INSERT OR UPDATE ON public.fiscal_years FOR EACH ROW EXECUTE FUNCTION public.fiscal_years_no_overlap();

CREATE TABLE public.activity_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid REFERENCES public.companies(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  action text NOT NULL,
  entity text NOT NULL,
  entity_id uuid,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX activity_log_company_idx ON public.activity_log(company_id, created_at DESC);
CREATE INDEX activity_log_user_idx ON public.activity_log(user_id, created_at DESC);
GRANT SELECT ON public.activity_log TO authenticated;
GRANT ALL ON public.activity_log TO service_role;
ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "log select" ON public.activity_log FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR (company_id IS NOT NULL AND public.can_access_company(company_id)));

CREATE OR REPLACE FUNCTION public.set_updated_at() RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;
CREATE TRIGGER profiles_updated BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER companies_updated BEFORE UPDATE ON public.companies FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER fiscal_years_updated BEFORE UPDATE ON public.fiscal_years FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Audit triggers (server-side, cannot be forged by clients)
CREATE OR REPLACE FUNCTION public.log_company_change() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.activity_log(company_id,user_id,action,entity,entity_id,details)
    VALUES (NEW.id, coalesce(auth.uid(), NEW.owner_id), 'creation', 'entreprise', NEW.id, jsonb_build_object('nom',NEW.name,'forme',NEW.legal_form));
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO public.activity_log(company_id,user_id,action,entity,entity_id,details)
    VALUES (NEW.id, coalesce(auth.uid(), NEW.owner_id), CASE WHEN NEW.archived_at IS NOT NULL AND OLD.archived_at IS NULL THEN 'archivage' ELSE 'modification' END, 'entreprise', NEW.id, jsonb_build_object('nom',NEW.name));
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER companies_log AFTER INSERT OR UPDATE ON public.companies FOR EACH ROW EXECUTE FUNCTION public.log_company_change();

CREATE OR REPLACE FUNCTION public.log_fiscal_year_change() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r public.fiscal_years;
BEGIN
  r := CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
  IF TG_OP = 'DELETE' AND NOT EXISTS (SELECT 1 FROM public.companies WHERE id = OLD.company_id) THEN RETURN OLD; END IF;
  INSERT INTO public.activity_log(company_id,user_id,action,entity,entity_id,details)
  VALUES (r.company_id, coalesce(auth.uid(), r.created_by),
    CASE TG_OP WHEN 'INSERT' THEN 'creation' WHEN 'UPDATE' THEN 'modification' ELSE 'suppression' END,
    'exercice', r.id, jsonb_build_object('libelle', r.label, 'debut', r.start_date, 'fin', r.end_date, 'statut', r.status));
  RETURN r;
END $$;
CREATE TRIGGER fiscal_years_log AFTER INSERT OR UPDATE OR DELETE ON public.fiscal_years FOR EACH ROW EXECUTE FUNCTION public.log_fiscal_year_change();

CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles(id, full_name) VALUES (NEW.id, coalesce(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name'));
  RETURN NEW;
END $$;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

REVOKE EXECUTE ON FUNCTION public.log_company_change(), public.log_fiscal_year_change(), public.handle_new_user(), public.fiscal_years_no_overlap(), public.set_updated_at() FROM anon, authenticated, public;
