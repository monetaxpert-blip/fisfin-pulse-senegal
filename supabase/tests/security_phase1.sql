-- FISFIN : tests de sécurité de l'étape 1 (données synthétiques, TOUJOURS annulées).
-- Simule deux identités au niveau de la base (rôle `authenticated` + jeton JWT),
-- exactement comme l'API les évalue. Le bloc se termine par une exception
-- volontaire : tout ce qui a été créé pendant le test est annulé.
-- Utilisateur A : premier profil réel existant. Utilisateur B : identifiant fictif.
DO $test$
DECLARE
  ua uuid := (SELECT id FROM public.profiles ORDER BY created_at LIMIT 1);
  ub uuid := gen_random_uuid();
  ca uuid; cb uuid; fy_open uuid; fy_closed uuid; fy_b uuid;
  n int; st text; ok int := 0; ko int := 0; report text := '';
  ua_prev_active uuid;
BEGIN
  SELECT active_company_id INTO ua_prev_active FROM public.profiles WHERE id = ua;

  -- Données de départ (créées comme chaque utilisateur, sous RLS)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  INSERT INTO public.companies(name, legal_form, sector) VALUES ('TEST SYNTHETIQUE A', 'SARL', 'Commerce') RETURNING id INTO ca;
  INSERT INTO public.fiscal_years(company_id, label, start_date, end_date) VALUES (ca, 'TEST-1', '2030-01-01', '2030-12-31') RETURNING id INTO fy_open;
  INSERT INTO public.fiscal_years(company_id, label, start_date, end_date) VALUES (ca, 'TEST-2', '2031-01-01', '2031-12-31') RETURNING id INTO fy_closed;
  UPDATE public.fiscal_years SET status = 'cloture' WHERE id = fy_closed;
  RESET ROLE;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', ub, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  INSERT INTO public.companies(name, legal_form, sector) VALUES ('TEST SYNTHETIQUE B', 'SA', 'Services') RETURNING id INTO cb;
  INSERT INTO public.fiscal_years(company_id, label, start_date, end_date) VALUES (cb, 'TEST-B', '2030-01-01', '2030-12-31') RETURNING id INTO fy_b;
  RESET ROLE;

  -- ===== Tests en tant qu'utilisateur A =====
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;

  SELECT count(*) INTO n FROM public.companies WHERE id = cb;
  IF n = 0 THEN ok := ok + 1; report := report || E'\nOK  T01 A ne voit pas l''entreprise de B';
  ELSE ko := ko + 1; report := report || E'\nKO  T01 A voit l''entreprise de B'; END IF;

  SELECT count(*) INTO n FROM public.fiscal_years WHERE company_id = cb;
  IF n = 0 THEN ok := ok + 1; report := report || E'\nOK  T02 A ne voit pas les exercices de B';
  ELSE ko := ko + 1; report := report || E'\nKO  T02 A voit les exercices de B'; END IF;

  SELECT count(*) INTO n FROM public.activity_log WHERE company_id = cb;
  IF n = 0 THEN ok := ok + 1; report := report || E'\nOK  T03 A ne voit pas l''historique de B';
  ELSE ko := ko + 1; report := report || E'\nKO  T03 A voit l''historique de B'; END IF;

  UPDATE public.companies SET name = 'pirate' WHERE id = cb; GET DIAGNOSTICS n = ROW_COUNT;
  IF n = 0 THEN ok := ok + 1; report := report || E'\nOK  T04 A ne peut pas modifier l''entreprise de B';
  ELSE ko := ko + 1; report := report || E'\nKO  T04 A a modifié l''entreprise de B'; END IF;

  UPDATE public.fiscal_years SET label = 'pirate' WHERE id = fy_b; GET DIAGNOSTICS n = ROW_COUNT;
  IF n = 0 THEN ok := ok + 1; report := report || E'\nOK  T05 A ne peut pas modifier un exercice de B';
  ELSE ko := ko + 1; report := report || E'\nKO  T05 A a modifié un exercice de B'; END IF;

  DELETE FROM public.fiscal_years WHERE id = fy_b; GET DIAGNOSTICS n = ROW_COUNT;
  IF n = 0 THEN ok := ok + 1; report := report || E'\nOK  T06 A ne peut pas supprimer un exercice de B';
  ELSE ko := ko + 1; report := report || E'\nKO  T06 A a supprimé un exercice de B'; END IF;

  st := 'aucune erreur';
  BEGIN INSERT INTO public.fiscal_years(company_id, label, start_date, end_date) VALUES (cb, 'X', '2040-01-01', '2040-12-31');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = '42501' THEN ok := ok + 1; report := report || E'\nOK  T07 A ne peut pas créer d''exercice chez B (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  T07 création chez B : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN INSERT INTO public.companies(owner_id, name, legal_form, sector) VALUES (ub, 'usurpation', 'SA', 'Services');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = '42501' THEN ok := ok + 1; report := report || E'\nOK  T08 A ne peut pas créer une entreprise au nom de B (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  T08 usurpation propriétaire : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN UPDATE public.companies SET owner_id = ub WHERE id = ca;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st IN ('42501', 'FS005') THEN ok := ok + 1; report := report || E'\nOK  T09 A ne peut pas transférer son entreprise (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  T09 transfert propriétaire : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN DELETE FROM public.companies WHERE id = ca;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = '42501' THEN ok := ok + 1; report := report || E'\nOK  T10 suppression d''entreprise refusée côté API (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  T10 suppression entreprise : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN UPDATE public.profiles SET active_company_id = cb WHERE id = ua;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS004' THEN ok := ok + 1; report := report || E'\nOK  T11 entreprise active de B refusée pour A (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  T11 entreprise active étrangère : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN UPDATE public.profiles SET active_company_id = gen_random_uuid() WHERE id = ua;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS004' THEN ok := ok + 1; report := report || E'\nOK  T12 entreprise active inexistante refusée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  T12 entreprise active inexistante : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN UPDATE public.profiles SET active_company_id = ca WHERE id = ua;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'aucune erreur' THEN ok := ok + 1; report := report || E'\nOK  T13 A peut activer sa propre entreprise';
  ELSE ko := ko + 1; report := report || E'\nKO  T13 activation propre entreprise : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN DELETE FROM public.fiscal_years WHERE id = fy_closed;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS002' THEN ok := ok + 1; report := report || E'\nOK  T14 exercice clôturé non supprimable (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  T14 suppression exercice clôturé : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN DELETE FROM public.fiscal_years WHERE id = fy_open; GET DIAGNOSTICS n = ROW_COUNT;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'aucune erreur' AND n = 1 THEN ok := ok + 1; report := report || E'\nOK  T15 exercice ouvert sans données supprimable';
  ELSE ko := ko + 1; report := report || E'\nKO  T15 suppression exercice ouvert : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN UPDATE public.fiscal_years SET company_id = cb WHERE id = fy_closed;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st IN ('42501', 'FS005') THEN ok := ok + 1; report := report || E'\nOK  T16 exercice non déplaçable vers une autre entreprise (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  T16 déplacement exercice : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN INSERT INTO public.activity_log(company_id, user_id, action, entity) VALUES (ca, ua, 'faux', 'faux');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = '42501' THEN ok := ok + 1; report := report || E'\nOK  T17 historique non falsifiable (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  T17 écriture historique : ' || st; END IF;

  IF public.can_access_company(cb) = false AND public.can_access_company(ca) = true THEN ok := ok + 1; report := report || E'\nOK  T18 can_access_company correct pour A';
  ELSE ko := ko + 1; report := report || E'\nKO  T18 can_access_company'; END IF;

  -- Archivage de l'entreprise active
  UPDATE public.companies SET archived_at = now() WHERE id = ca;
  SELECT count(*) INTO n FROM public.profiles WHERE id = ua AND active_company_id IS NULL;
  IF n = 1 THEN ok := ok + 1; report := report || E'\nOK  T19 archivage : l''entreprise n''est plus active';
  ELSE ko := ko + 1; report := report || E'\nKO  T19 archivage ne libère pas l''entreprise active'; END IF;

  st := 'aucune erreur';
  BEGIN UPDATE public.profiles SET active_company_id = ca WHERE id = ua;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS004' THEN ok := ok + 1; report := report || E'\nOK  T20 entreprise archivée non activable (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  T20 activation archivée : ' || st; END IF;

  SELECT count(*) INTO n FROM public.companies WHERE id = ca;
  IF n = 1 THEN ok := ok + 1; report := report || E'\nOK  T21 entreprise archivée conservée et visible par A';
  ELSE ko := ko + 1; report := report || E'\nKO  T21 entreprise archivée introuvable'; END IF;
  RESET ROLE;

  -- ===== Accès anonyme =====
  PERFORM set_config('request.jwt.claims', '{"role":"anon"}', true);
  SET LOCAL ROLE anon;
  st := 'aucune erreur';
  BEGIN PERFORM 1 FROM public.companies LIMIT 1;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = '42501' THEN ok := ok + 1; report := report || E'\nOK  T22 visiteur anonyme sans accès aux entreprises (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  T22 accès anonyme : ' || st; END IF;
  RESET ROLE;

  -- ===== Accès privilégié (contournement de l'API) =====
  st := 'aucune erreur';
  BEGIN DELETE FROM public.companies WHERE id = cb;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS001' THEN ok := ok + 1; report := report || E'\nOK  T23 suppression d''entreprise bloquée même hors API (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  T23 suppression privilégiée : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN TRUNCATE public.fiscal_years CASCADE;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS001' THEN ok := ok + 1; report := report || E'\nOK  T24 vidage des exercices bloqué (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  T24 vidage exercices : ' || st; END IF;

  RAISE EXCEPTION 'RAPPORT FISFIN (annulé, aucune donnée conservée) : % réussis, % échoués%', ok, ko, report;
END
$test$;
