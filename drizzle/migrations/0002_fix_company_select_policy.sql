-- La fonction d'accès ne voit pas encore une ligne en cours de création (INSERT ... RETURNING).
-- Le propriétaire est donc vérifié directement, l'accès partagé futur passe par can_access_company.
DROP POLICY IF EXISTS "access select companies" ON public.companies;
CREATE POLICY "access select companies" ON public.companies FOR SELECT TO authenticated
  USING (owner_id = auth.uid() OR public.can_access_company(id));