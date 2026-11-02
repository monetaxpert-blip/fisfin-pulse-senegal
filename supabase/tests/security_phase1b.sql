-- FISFIN : tests complémentaires de l'étape 1 (données synthétiques, TOUJOURS annulées).
-- Couvre : clôture / réouverture / suppression d'exercice, entreprise archivée,
-- conservation des exercices et de l'historique, fonctions de vérification d'accès.
-- Identités simulées au niveau de la base (rôle + jeton JWT), comme l'API les évalue.
-- Utilisateur A : premier profil réel existant. Utilisateur B : identifiant fictif.
-- Le bloc se termine par une exception volontaire : tout est annulé.
-- Résultat attendu : « RAPPORT FISFIN 1B ... : N réussis, 0 échoués ».
DO $test$
DECLARE
  ua uuid := (SELECT id FROM public.profiles ORDER BY created_at LIMIT 1);
  ub uuid := gen_random_uuid();
  ca uuid; cb uuid; fy1 uuid; fy2 uuid; fy3 uuid; fy4 uuid; fy_b uuid;
  n int; n2 int; st text; ok int := 0; ko int := 0; report text := '';
  r public.fiscal_years;
  fy_before int; log_before int;
BEGIN
  -- ===== Données de départ =====
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ub, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  INSERT INTO public.companies(name, legal_form, sector) VALUES ('TEST SYNTHETIQUE B', 'SA', 'Services') RETURNING id INTO cb;
  INSERT INTO public.fiscal_years(company_id, label, start_date, end_date) VALUES (cb, 'TEST-B', '2030-01-01', '2030-12-31') RETURNING id INTO fy_b;
  RESET ROLE;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  INSERT INTO public.companies(name, legal_form, sector) VALUES ('TEST SYNTHETIQUE A', 'SARL', 'Commerce') RETURNING id INTO ca;
  INSERT INTO public.fiscal_years(company_id, label, start_date, end_date) VALUES (ca, 'TEST-1', '2030-01-01', '2030-12-31') RETURNING id INTO fy1;
  INSERT INTO public.fiscal_years(company_id, label, start_date, end_date) VALUES (ca, 'TEST-2', '2031-01-01', '2031-12-31') RETURNING id INTO fy2;
  INSERT INTO public.fiscal_years(company_id, label, start_date, end_date) VALUES (ca, 'TEST-3', '2032-01-01', '2032-12-31') RETURNING id INTO fy3;

  -- ===== Clôture, réouverture, suppression =====
  UPDATE public.fiscal_years SET status = 'cloture' WHERE id = fy1;
  SELECT * INTO r FROM public.fiscal_years WHERE id = fy1;
  SELECT count(*) INTO n FROM public.activity_log WHERE entity_id = fy1 AND action = 'cloture';
  IF r.first_closed_at IS NOT NULL AND r.closed_at IS NOT NULL AND n = 1 THEN ok := ok + 1; report := report || E'\nOK  C01 clôture horodatée et tracée';
  ELSE ko := ko + 1; report := report || E'\nKO  C01 clôture non horodatée ou non tracée'; END IF;

  st := 'aucune erreur';
  BEGIN UPDATE public.fiscal_years SET label = 'TEST-1-modifie' WHERE id = fy1;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS008' THEN ok := ok + 1; report := report || E'\nOK  C02 exercice clôturé non modifiable (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  C02 modification exercice clôturé : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN UPDATE public.fiscal_years SET status = 'ouvert' WHERE id = fy1;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS009' THEN ok := ok + 1; report := report || E'\nOK  C03 réouverture sans motif refusée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  C03 réouverture sans motif : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN UPDATE public.fiscal_years SET status = 'ouvert', reopen_reason = '   court  ' WHERE id = fy1;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS009' THEN ok := ok + 1; report := report || E'\nOK  C04 réouverture avec motif trop court refusée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  C04 motif trop court : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN UPDATE public.fiscal_years SET status = 'ouvert', reopen_reason = 'Correction écriture inventaire', start_date = '2029-12-01' WHERE id = fy1;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS008' THEN ok := ok + 1; report := report || E'\nOK  C05 réouverture couplée à une modification refusée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  C05 réouverture + modification : ' || st; END IF;

  UPDATE public.fiscal_years SET status = 'ouvert', reopen_reason = 'Correction écriture inventaire' WHERE id = fy1;
  SELECT * INTO r FROM public.fiscal_years WHERE id = fy1;
  SELECT count(*) INTO n FROM public.activity_log WHERE entity_id = fy1 AND action = 'reouverture' AND details->>'motif' = 'Correction écriture inventaire' AND user_id = ua;
  IF r.status = 'ouvert' AND r.reopened_by = ua AND r.reopened_at IS NOT NULL AND n = 1 THEN ok := ok + 1; report := report || E'\nOK  C06 réouverture motivée : auteur, date et motif tracés';
  ELSE ko := ko + 1; report := report || E'\nKO  C06 réouverture motivée mal tracée'; END IF;

  st := 'aucune erreur';
  BEGIN DELETE FROM public.fiscal_years WHERE id = fy1;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS006' THEN ok := ok + 1; report := report || E'\nOK  C07 exercice rouvert après clôture non supprimable (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  C07 suppression après réouverture : ' || st; END IF;

  UPDATE public.fiscal_years SET first_closed_at = NULL, reopened_by = ub, reopened_at = NULL WHERE id = fy1;
  SELECT * INTO r FROM public.fiscal_years WHERE id = fy1;
  IF r.first_closed_at IS NOT NULL AND r.reopened_by = ua AND r.reopened_at IS NOT NULL THEN ok := ok + 1; report := report || E'\nOK  C08 champs de traçabilité non falsifiables';
  ELSE ko := ko + 1; report := report || E'\nKO  C08 traçabilité falsifiée'; END IF;

  st := 'aucune erreur';
  BEGIN DELETE FROM public.fiscal_years WHERE id = fy1;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS006' THEN ok := ok + 1; report := report || E'\nOK  C09 suppression toujours refusée après tentative d''effacement de la trace (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  C09 contournement suppression : ' || st; END IF;

  UPDATE public.fiscal_years SET status = 'cloture' WHERE id = fy1;
  st := 'aucune erreur';
  BEGIN UPDATE public.fiscal_years SET status = 'ouvert' WHERE id = fy1;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS009' THEN ok := ok + 1; report := report || E'\nOK  C10 une nouvelle réouverture exige un nouveau motif (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  C10 réouverture sans nouveau motif : ' || st; END IF;

  INSERT INTO public.fiscal_years(company_id, label, start_date, end_date, status, first_closed_at) VALUES (ca, 'TEST-4', '2033-01-01', '2033-12-31', 'ouvert', NULL) RETURNING id INTO fy4;
  st := 'aucune erreur';
  BEGIN DELETE FROM public.fiscal_years WHERE id = fy4; GET DIAGNOSTICS n = ROW_COUNT;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'aucune erreur' AND n = 1 THEN ok := ok + 1; report := report || E'\nOK  C11 exercice ouvert jamais clôturé et sans données supprimable';
  ELSE ko := ko + 1; report := report || E'\nKO  C11 suppression exercice jamais clôturé : ' || st; END IF;

  UPDATE public.fiscal_years SET status = 'cloture' WHERE id = fy3;
  RESET ROLE;
  st := 'aucune erreur';
  BEGIN DELETE FROM public.fiscal_years WHERE id = fy3;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS002' THEN ok := ok + 1; report := report || E'\nOK  C12 exercice clôturé non supprimable même hors API (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  C12 suppression privilégiée exercice clôturé : ' || st; END IF;

  -- ===== Entreprise archivée =====
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  SELECT count(*) INTO fy_before FROM public.fiscal_years WHERE company_id = ca;
  SELECT count(*) INTO log_before FROM public.activity_log WHERE company_id = ca;
  UPDATE public.companies SET archived_at = now() WHERE id = ca;
  SELECT count(*) INTO n FROM public.fiscal_years WHERE company_id = ca;
  SELECT count(*) INTO n2 FROM public.activity_log WHERE company_id = ca;
  IF n = fy_before AND n = 3 AND n2 = log_before + 1 THEN ok := ok + 1; report := report || E'\nOK  A01 archivage : exercices (' || n || ') et historique conservés et visibles';
  ELSE ko := ko + 1; report := report || E'\nKO  A01 archivage : exercices ' || n || '/' || fy_before || ', historique ' || n2 || '/' || log_before; END IF;

  st := 'aucune erreur';
  BEGIN INSERT INTO public.fiscal_years(company_id, label, start_date, end_date) VALUES (ca, 'TEST-ARCH', '2034-01-01', '2034-12-31');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS007' THEN ok := ok + 1; report := report || E'\nOK  A02 création d''exercice refusée dans une entreprise archivée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  A02 création dans entreprise archivée : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN UPDATE public.fiscal_years SET label = 'TEST-2-modifie' WHERE id = fy2;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS007' THEN ok := ok + 1; report := report || E'\nOK  A03 modification d''exercice refusée dans une entreprise archivée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  A03 modification dans entreprise archivée : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN UPDATE public.fiscal_years SET status = 'cloture' WHERE id = fy2;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS007' THEN ok := ok + 1; report := report || E'\nOK  A04 clôture refusée dans une entreprise archivée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  A04 clôture dans entreprise archivée : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN DELETE FROM public.fiscal_years WHERE id = fy2;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS007' THEN ok := ok + 1; report := report || E'\nOK  A05 suppression d''exercice refusée dans une entreprise archivée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  A05 suppression dans entreprise archivée : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN UPDATE public.companies SET name = 'renommage interdit' WHERE id = ca;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS007' THEN ok := ok + 1; report := report || E'\nOK  A06 entreprise archivée non modifiable (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  A06 modification entreprise archivée : ' || st; END IF;

  UPDATE public.companies SET archived_at = NULL WHERE id = ca;
  SELECT count(*) INTO n FROM public.activity_log WHERE company_id = ca AND action = 'restauration';
  st := 'aucune erreur';
  BEGIN INSERT INTO public.fiscal_years(company_id, label, start_date, end_date) VALUES (ca, 'TEST-REST', '2035-01-01', '2035-12-31');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF n = 1 AND st = 'aucune erreur' THEN ok := ok + 1; report := report || E'\nOK  A07 restauration tracée, création d''exercice de nouveau possible';
  ELSE ko := ko + 1; report := report || E'\nKO  A07 restauration : ' || st || ' / journal ' || n; END IF;

  -- ===== Fonctions de vérification d'accès (utilisateur A) =====
  IF public.can_access_company(ca) AND NOT public.can_access_company(cb) AND NOT public.can_access_company(gen_random_uuid()) THEN
    ok := ok + 1; report := report || E'\nOK  F01 can_access_company : vrai pour sa société, faux pour B et pour un identifiant inconnu';
  ELSE ko := ko + 1; report := report || E'\nKO  F01 can_access_company'; END IF;

  IF public.is_company_owner(ca) AND NOT public.is_company_owner(cb) THEN
    ok := ok + 1; report := report || E'\nOK  F02 is_company_owner : vrai pour sa société, faux pour B';
  ELSE ko := ko + 1; report := report || E'\nKO  F02 is_company_owner'; END IF;
  RESET ROLE;

  -- Utilisateur B ne peut pas sonder les droits de A
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ub, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  IF NOT public.can_access_company(ca) AND NOT public.is_company_owner(ca) AND public.can_access_company(cb) THEN
    ok := ok + 1; report := report || E'\nOK  F03 B : les fonctions ne répondent que pour B lui-même';
  ELSE ko := ko + 1; report := report || E'\nKO  F03 B obtient des droits sur A'; END IF;

  SELECT count(*) INTO n FROM public.activity_log WHERE company_id = ca;
  SELECT count(*) INTO n2 FROM public.fiscal_years WHERE company_id = ca;
  IF n = 0 AND n2 = 0 THEN ok := ok + 1; report := report || E'\nOK  F04 B ne voit ni les exercices ni l''historique de A';
  ELSE ko := ko + 1; report := report || E'\nKO  F04 B voit des données de A'; END IF;
  RESET ROLE;

  -- Visiteur anonyme
  PERFORM set_config('request.jwt.claims', '{"role":"anon"}', true);
  SET LOCAL ROLE anon;
  st := 'aucune erreur';
  BEGIN PERFORM public.can_access_company(ca);
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = '42501' THEN ok := ok + 1; report := report || E'\nOK  F05 anonyme : can_access_company refusée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  F05 anonyme can_access_company : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN PERFORM public.is_company_owner(ca);
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = '42501' THEN ok := ok + 1; report := report || E'\nOK  F06 anonyme : is_company_owner refusée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  F06 anonyme is_company_owner : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN PERFORM private.has_company_access(ua, ca);
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = '42501' THEN ok := ok + 1; report := report || E'\nOK  F07 anonyme : fonction privée refusée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  F07 anonyme fonction privée : ' || st; END IF;
  RESET ROLE;

  -- Catalogue : seules les deux fonctions attendues sont SECURITY DEFINER et appelables par un compte connecté dans le schéma exposé
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace s ON s.oid = p.pronamespace
   WHERE s.nspname = 'public' AND p.prosecdef AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND p.proname NOT IN ('can_access_company', 'is_company_owner');
  SELECT count(*) INTO n2 FROM pg_proc p JOIN pg_namespace s ON s.oid = p.pronamespace
   WHERE s.nspname = 'public' AND p.proname IN ('can_access_company', 'is_company_owner')
     AND (pg_get_function_identity_arguments(p.oid) <> '_company_id uuid' OR has_function_privilege('anon', p.oid, 'EXECUTE'));
  IF n = 0 AND n2 = 0 THEN ok := ok + 1; report := report || E'\nOK  F08 schéma exposé : aucune autre fonction privilégiée, aucun paramètre utilisateur, pas d''accès anonyme';
  ELSE ko := ko + 1; report := report || E'\nKO  F08 catalogue : ' || n || ' fonction(s) en trop, ' || n2 || ' signature(s) ou droit(s) inattendus'; END IF;

  RAISE EXCEPTION 'RAPPORT FISFIN 1B (annulé, aucune donnée conservée) : % réussis, % échoués%', ok, ko, report;
END
$test$;
