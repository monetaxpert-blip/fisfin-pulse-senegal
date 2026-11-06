-- 1. Fichiers sources du bucket "balances" : ni remplacement ni suppression.
-- Politiques RESTRICTIVES : elles s'appliquent en plus de toute politique permissive future,
-- donc aucune règle ajoutée plus tard ne pourra rouvrir UPDATE/DELETE sur ce bucket.
CREATE POLICY "balances no update" ON storage.objects AS RESTRICTIVE FOR UPDATE TO authenticated, anon
  USING (bucket_id <> 'balances') WITH CHECK (bucket_id <> 'balances');
CREATE POLICY "balances no delete" ON storage.objects AS RESTRICTIVE FOR DELETE TO authenticated, anon
  USING (bucket_id <> 'balances');

-- 2. Archivage d'une entreprise refusé tant qu'un import est en brouillon ou en analyse.
CREATE OR REPLACE FUNCTION public.companies_guard_archive()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE pending text;
BEGIN
  IF NEW.archived_at IS NOT NULL AND OLD.archived_at IS NULL THEN
    SELECT string_agg(format('%s (%s au %s, %s)', i.file_name, to_char(i.period_start, 'DD/MM/YYYY'),
                             to_char(i.period_end, 'DD/MM/YYYY'),
                             CASE i.status WHEN 'brouillon' THEN 'brouillon' ELSE 'en analyse' END), ' ; ' ORDER BY i.created_at)
      INTO pending
      FROM public.balance_imports i
     WHERE i.company_id = NEW.id AND i.status IN ('brouillon', 'analyse');
    IF pending IS NOT NULL THEN
      RAISE EXCEPTION 'Archivage impossible : validez ou abandonnez d''abord les imports en cours : %', pending
        USING ERRCODE = 'FS021';
    END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE EXECUTE ON FUNCTION public.companies_guard_archive() FROM public, anon, authenticated;

CREATE TRIGGER companies_archive_guard BEFORE UPDATE ON public.companies
  FOR EACH ROW EXECUTE FUNCTION public.companies_guard_archive();