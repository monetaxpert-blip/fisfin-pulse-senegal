-- FISFIN : tests de sécurité de la phase 2, importation des balances (données synthétiques, TOUJOURS annulées).
-- Couvre : isolation entre utilisateurs, droits d'écriture, contrôle des périodes, cycle de vie
-- (brouillon, analyse, validation, remplacement, référence, retrait, abandon), immutabilité,
-- doublons, clôture bloquée, dates d'exercice figées, stockage privé, catalogue des fonctions.
-- Utilisateur A : premier profil réel existant. Utilisateur B : identifiant fictif.
-- Le bloc se termine par une exception volontaire : tout est annulé.
-- Exécution : outil SQL de modification de données. Attendu : « RAPPORT FISFIN 2 ... : N réussis, 0 échoués ».
DO $test$
DECLARE
  ua uuid := (SELECT id FROM public.profiles ORDER BY created_at LIMIT 1);
  ub uuid := gen_random_uuid();
  ca uuid; cb uuid; fy1 uuid; fy2 uuid; fy_b uuid;
  i1 uuid; i2 uuid; i3 uuid; i4 uuid; i5 uuid; i6 uuid; iss_block uuid; iss_rev uuid;
  n int; n2 int; st text; ok int := 0; ko int := 0; report text := '';
  imp public.balance_imports;
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

  -- ===== Création d'un brouillon =====
  INSERT INTO public.balance_imports(company_id, fiscal_year_id, balance_type, amount_basis, period_start, period_end, file_name, status, is_reference, summary)
  VALUES (ca, fy1, 'mensuelle', 'cumulee', '2030-01-01', '2030-03-31', 'TEST_SYNTHETIQUE_mars.xlsx', 'valide', true, '{"x":1}')
  RETURNING id INTO i1;
  SELECT * INTO imp FROM public.balance_imports WHERE id = i1;
  SELECT count(*) INTO n FROM public.activity_log WHERE entity_id = i1 AND action = 'creation' AND entity = 'import';
  IF imp.status = 'brouillon' AND NOT imp.is_reference AND imp.summary = '{}'::jsonb AND imp.currency = 'XOF' AND imp.created_by = ua AND n = 1 THEN
    ok := ok + 1; report := report || E'\nOK  I01 brouillon créé : statut, référence et résumé imposés par la base, création tracée';
  ELSE ko := ko + 1; report := report || E'\nKO  I01 brouillon : statut ' || imp.status || ' ref ' || imp.is_reference; END IF;

  -- ===== Contrôle des périodes =====
  st := 'aucune erreur';
  BEGIN INSERT INTO public.balance_imports(company_id, fiscal_year_id, balance_type, amount_basis, period_start, period_end, file_name)
        VALUES (ca, fy1, 'mensuelle', 'cumulee', '2030-01-01', '2031-01-31', 'x.xlsx');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS013' THEN ok := ok + 1; report := report || E'\nOK  P01 période hors exercice refusée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  P01 période hors exercice : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN INSERT INTO public.balance_imports(company_id, fiscal_year_id, balance_type, amount_basis, period_start, period_end, file_name)
        VALUES (ca, fy1, 'annuelle', 'cumulee', '2030-01-01', '2030-06-30', 'x.xlsx');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS013' THEN ok := ok + 1; report := report || E'\nOK  P02 balance annuelle partielle refusée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  P02 annuelle partielle : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN INSERT INTO public.balance_imports(company_id, fiscal_year_id, balance_type, amount_basis, period_start, period_end, file_name)
        VALUES (ca, fy1, 'mensuelle', 'cumulee', '2030-02-01', '2030-03-31', 'x.xlsx');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS013' THEN ok := ok + 1; report := report || E'\nOK  P03 cumul ne partant pas du début d''exercice refusé (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  P03 cumul mal daté : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN INSERT INTO public.balance_imports(company_id, fiscal_year_id, balance_type, amount_basis, period_start, period_end, file_name)
        VALUES (ca, fy1, 'mensuelle', 'periodique', '2030-02-01', '2030-03-31', 'x.xlsx');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS013' THEN ok := ok + 1; report := report || E'\nOK  P04 balance de mouvements sur deux mois refusée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  P04 mouvements sur deux mois : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN INSERT INTO public.balance_imports(company_id, fiscal_year_id, balance_type, amount_basis, period_start, period_end, file_name)
        VALUES (ca, fy1, 'mensuelle', 'cumulee', '2030-01-01', '2030-03-15', 'x.xlsx');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS013' THEN ok := ok + 1; report := report || E'\nOK  P05 fin de période en milieu de mois refusée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  P05 fin en milieu de mois : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN INSERT INTO public.balance_imports(company_id, fiscal_year_id, balance_type, amount_basis, period_start, period_end, file_name)
        VALUES (ca, fy_b, 'annuelle', 'cumulee', '2030-01-01', '2030-12-31', 'x.xlsx');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st IN ('FS013', '42501') THEN ok := ok + 1; report := report || E'\nOK  P06 exercice d''une autre entreprise refusé (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  P06 exercice étranger : ' || st; END IF;

  -- ===== Droits d'écriture directs refusés =====
  st := 'aucune erreur';
  BEGIN INSERT INTO public.balance_lines(import_id, company_id, source_row, account_number, account_number_raw) VALUES (i1, ca, 1, '601', '601');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = '42501' THEN ok := ok + 1; report := report || E'\nOK  W01 écriture directe de lignes refusée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  W01 écriture directe de lignes : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN UPDATE public.balance_imports SET status = 'valide' WHERE id = i1;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = '42501' THEN ok := ok + 1; report := report || E'\nOK  W02 validation par modification directe refusée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  W02 modification directe : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN DELETE FROM public.balance_imports WHERE id = i1;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = '42501' THEN ok := ok + 1; report := report || E'\nOK  W03 suppression d''un import refusée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  W03 suppression import : ' || st; END IF;

  -- ===== Exercice : clôture bloquée, dates figées, suppression interdite =====
  st := 'aucune erreur';
  BEGIN UPDATE public.fiscal_years SET status = 'cloture' WHERE id = fy1;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS019' THEN ok := ok + 1; report := report || E'\nOK  E01 clôture refusée tant qu''un import est en brouillon (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  E01 clôture avec brouillon : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN UPDATE public.fiscal_years SET end_date = '2030-11-30' WHERE id = fy1;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS020' THEN ok := ok + 1; report := report || E'\nOK  E02 dates d''un exercice avec imports figées (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  E02 dates modifiables : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN DELETE FROM public.fiscal_years WHERE id = fy1;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS003' THEN ok := ok + 1; report := report || E'\nOK  E03 suppression d''un exercice avec import refusée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  E03 suppression exercice : ' || st; END IF;
  RESET ROLE;

  -- ===== Isolation : B ne voit rien et ne peut rien faire =====
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ub, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  SELECT count(*) INTO n FROM public.balance_imports WHERE company_id = ca;
  IF n = 0 THEN ok := ok + 1; report := report || E'\nOK  R01 B ne voit pas les imports de A';
  ELSE ko := ko + 1; report := report || E'\nKO  R01 B voit ' || n || ' import(s) de A'; END IF;

  st := 'aucune erreur';
  BEGIN INSERT INTO public.balance_imports(company_id, fiscal_year_id, balance_type, amount_basis, period_start, period_end, file_name)
        VALUES (ca, fy1, 'mensuelle', 'cumulee', '2030-01-01', '2030-01-31', 'x.xlsx');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = '42501' THEN ok := ok + 1; report := report || E'\nOK  R02 B ne peut pas créer d''import chez A (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  R02 B crée chez A : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN PERFORM public.abandon_balance_import(i1);
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = '42501' THEN ok := ok + 1; report := report || E'\nOK  R03 B ne peut pas agir sur un import de A (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  R03 B agit sur import de A : ' || st; END IF;

  SELECT count(*) INTO n FROM (SELECT private.balance_upload_allowed(ca || '/' || i1 || '/source.xlsx') AS a) s WHERE a;
  IF n = 0 THEN ok := ok + 1; report := report || E'\nOK  R04 B ne peut pas déposer de fichier dans le dossier de A';
  ELSE ko := ko + 1; report := report || E'\nKO  R04 dépôt autorisé pour B'; END IF;
  RESET ROLE;

  -- ===== Stockage : chemin imposé =====
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  IF private.balance_upload_allowed(ca || '/' || i1 || '/source.xlsx')
     AND NOT private.balance_upload_allowed(ca || '/' || i1 || '/autre.xlsx')
     AND NOT private.balance_upload_allowed(cb || '/' || i1 || '/source.xlsx')
     AND NOT private.balance_upload_allowed('pas-un-uuid/' || i1 || '/source.xlsx') THEN
    ok := ok + 1; report := report || E'\nOK  S01 dépôt limité au chemin {entreprise}/{import brouillon}/source.xlsx';
  ELSE ko := ko + 1; report := report || E'\nKO  S01 règle de chemin de dépôt'; END IF;
  RESET ROLE;

  -- ===== Analyse serveur simulée (rôle serveur) : une anomalie bloquante =====
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  SET LOCAL ROLE service_role;
  INSERT INTO public.balance_lines(import_id, company_id, source_row, account_number, account_number_raw, closing_debit, closing_credit)
  VALUES (i1, cb, 4, '521000', '521000', 1000, NULL), (i1, cb, 5, '101000', '101000', NULL, 1000);
  INSERT INTO public.balance_import_issues(import_id, company_id, code, severity, message)
  VALUES (i1, cb, 'IMP-T02', 'bloquant', 'TEST déséquilibre') RETURNING id INTO iss_block;
  UPDATE public.balance_imports SET status = 'analyse', file_sha256 = 'TEST-F1', content_sha256 = 'TEST-C1', analysed_at = now(), summary = '{"issues":{"bloquant":1}}' WHERE id = i1;
  SELECT count(*) INTO n FROM public.balance_lines WHERE import_id = i1 AND company_id = ca;
  IF n = 2 THEN ok := ok + 1; report := report || E'\nOK  A01 lignes rattachées à l''entreprise de l''import, même si une autre est fournie';
  ELSE ko := ko + 1; report := report || E'\nKO  A01 rattachement des lignes : ' || n; END IF;
  RESET ROLE;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  st := 'aucune erreur';
  BEGIN PERFORM public.validate_balance_import(i1);
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS015' THEN ok := ok + 1; report := report || E'\nOK  V01 validation refusée avec anomalie bloquante (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  V01 validation avec bloquant : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN PERFORM public.acknowledge_balance_issue(iss_block, 'je force');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS015' THEN ok := ok + 1; report := report || E'\nOK  V02 une anomalie bloquante ne peut pas être confirmée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  V02 confirmation bloquante : ' || st; END IF;
  RESET ROLE;

  -- Nouvelle analyse : l'anomalie devient « à vérifier »
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  SET LOCAL ROLE service_role;
  DELETE FROM public.balance_import_issues WHERE import_id = i1;
  INSERT INTO public.balance_import_issues(import_id, company_id, code, severity, message)
  VALUES (i1, ca, 'IMP-S01', 'a_verifier', 'TEST cumul en baisse') RETURNING id INTO iss_rev;
  RESET ROLE;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  st := 'aucune erreur';
  BEGIN PERFORM public.validate_balance_import(i1);
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS016' THEN ok := ok + 1; report := report || E'\nOK  V03 validation refusée tant qu''une anomalie à vérifier n''est pas confirmée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  V03 validation sans confirmation : ' || st; END IF;

  PERFORM public.acknowledge_balance_issue(iss_rev, 'Extourne vérifiée');
  SELECT count(*) INTO n FROM public.balance_import_issues WHERE id = iss_rev AND acknowledged_by = ua AND acknowledgement_note = 'Extourne vérifiée';
  SELECT count(*) INTO n2 FROM public.activity_log WHERE entity_id = i1 AND action = 'confirmation_anomalie';
  IF n = 1 AND n2 = 1 THEN ok := ok + 1; report := report || E'\nOK  V04 confirmation d''anomalie : auteur, commentaire et trace';
  ELSE ko := ko + 1; report := report || E'\nKO  V04 confirmation mal tracée'; END IF;

  imp := public.validate_balance_import(i1);
  SELECT count(*) INTO n FROM public.activity_log WHERE entity_id = i1 AND action = 'validation';
  IF imp.status = 'valide' AND imp.is_reference AND imp.version = 1 AND imp.validated_by = ua AND n = 1 THEN
    ok := ok + 1; report := report || E'\nOK  V05 validation : version 1, source de référence, auteur et trace';
  ELSE ko := ko + 1; report := report || E'\nKO  V05 validation : ' || imp.status; END IF;
  RESET ROLE;

  -- ===== Immutabilité, même pour le rôle serveur =====
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  SET LOCAL ROLE service_role;
  st := 'aucune erreur';
  BEGIN UPDATE public.balance_lines SET closing_debit = 999 WHERE import_id = i1;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS012' THEN ok := ok + 1; report := report || E'\nOK  M01 ligne validée non modifiable (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  M01 modification ligne validée : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN DELETE FROM public.balance_lines WHERE import_id = i1;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS012' THEN ok := ok + 1; report := report || E'\nOK  M02 ligne validée non supprimable (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  M02 suppression ligne validée : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN UPDATE public.balance_imports SET column_mapping = '{"x":1}' WHERE id = i1;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS012' THEN ok := ok + 1; report := report || E'\nOK  M03 paramètres d''un import validé figés (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  M03 import validé modifiable : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN UPDATE public.balance_imports SET status = 'brouillon' WHERE id = i1;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS011' THEN ok := ok + 1; report := report || E'\nOK  M04 retour d''une version validée en brouillon refusé (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  M04 retour en brouillon : ' || st; END IF;
  RESET ROLE;

  -- ===== Réimport de la même période : remplacement explicite =====
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  INSERT INTO public.balance_imports(company_id, fiscal_year_id, balance_type, amount_basis, period_start, period_end, file_name)
  VALUES (ca, fy1, 'mensuelle', 'cumulee', '2030-01-01', '2030-03-31', 'TEST_SYNTHETIQUE_mars_v2.xlsx') RETURNING id INTO i2;
  INSERT INTO public.balance_imports(company_id, fiscal_year_id, balance_type, amount_basis, period_start, period_end, file_name)
  VALUES (ca, fy1, 'mensuelle', 'cumulee', '2030-01-01', '2030-03-31', 'TEST_SYNTHETIQUE_copie.xlsx') RETURNING id INTO i3;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  SET LOCAL ROLE service_role;
  UPDATE public.balance_imports SET status = 'analyse', file_sha256 = 'TEST-F2', content_sha256 = 'TEST-C2', analysed_at = now() WHERE id = i2;
  UPDATE public.balance_imports SET status = 'analyse', file_sha256 = 'TEST-F3', content_sha256 = 'TEST-C1', analysed_at = now() WHERE id = i3;
  RESET ROLE;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  st := 'aucune erreur';
  BEGIN PERFORM public.validate_balance_import(i3, true, 'Copie du même contenu pour test');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS017' THEN ok := ok + 1; report := report || E'\nOK  D01 même contenu déjà validé refusé (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  D01 doublon de contenu : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN PERFORM public.validate_balance_import(i2);
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS014' THEN ok := ok + 1; report := report || E'\nOK  D02 écrasement silencieux refusé (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  D02 écrasement silencieux : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN PERFORM public.validate_balance_import(i2, true, 'court');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS018' THEN ok := ok + 1; report := report || E'\nOK  D03 remplacement sans motif suffisant refusé (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  D03 remplacement motif court : ' || st; END IF;

  imp := public.validate_balance_import(i2, true, 'Correction des écritures de stock');
  SELECT count(*) INTO n FROM public.balance_imports WHERE id = i1 AND status = 'remplace' AND NOT is_reference;
  SELECT count(*) INTO n2 FROM public.balance_lines WHERE import_id = i1;
  IF imp.status = 'valide' AND imp.version = 2 AND imp.supersedes_import_id = i1 AND imp.is_reference AND n = 1 AND n2 = 2 THEN
    ok := ok + 1; report := report || E'\nOK  D04 remplacement motivé : version 2, ancienne conservée avec ses lignes, référence transférée';
  ELSE ko := ko + 1; report := report || E'\nKO  D04 remplacement'; END IF;

  -- ===== Annuelle et cumulée de fin d'exercice : une seule référence =====
  INSERT INTO public.balance_imports(company_id, fiscal_year_id, balance_type, amount_basis, period_start, period_end, file_name)
  VALUES (ca, fy1, 'mensuelle', 'cumulee', '2030-01-01', '2030-12-31', 'TEST_SYNTHETIQUE_decembre.xlsx') RETURNING id INTO i4;
  INSERT INTO public.balance_imports(company_id, fiscal_year_id, balance_type, amount_basis, period_start, period_end, file_name)
  VALUES (ca, fy1, 'annuelle', 'cumulee', '2030-01-01', '2030-12-31', 'TEST_SYNTHETIQUE_annuelle.xlsx') RETURNING id INTO i5;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  SET LOCAL ROLE service_role;
  UPDATE public.balance_imports SET status = 'analyse', file_sha256 = 'TEST-F4', content_sha256 = 'TEST-C4', analysed_at = now() WHERE id = i4;
  UPDATE public.balance_imports SET status = 'analyse', file_sha256 = 'TEST-F5', content_sha256 = 'TEST-C5', analysed_at = now() WHERE id = i5;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  PERFORM public.validate_balance_import(i4);
  imp := public.validate_balance_import(i5);
  SELECT count(*) INTO n FROM public.balance_imports WHERE fiscal_year_id = fy1 AND period_end = '2030-12-31' AND is_reference;
  IF imp.status = 'valide' AND NOT imp.is_reference AND n = 1 THEN
    ok := ok + 1; report := report || E'\nOK  F01 annuelle importée à côté de la cumulée de décembre, sans devenir une seconde référence';
  ELSE ko := ko + 1; report := report || E'\nKO  F01 références : ' || n; END IF;

  PERFORM public.set_reference_balance_import(i5);
  SELECT count(*) INTO n FROM public.balance_imports WHERE fiscal_year_id = fy1 AND period_end = '2030-12-31' AND is_reference;
  SELECT count(*) INTO n2 FROM public.balance_imports WHERE id = i5 AND is_reference;
  IF n = 1 AND n2 = 1 THEN ok := ok + 1; report := report || E'\nOK  F02 changement explicite de source de référence, toujours une seule par période';
  ELSE ko := ko + 1; report := report || E'\nKO  F02 changement de référence'; END IF;

  -- ===== Retrait et abandon =====
  st := 'aucune erreur';
  BEGIN PERFORM public.archive_balance_import(i4, 'court');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS018' THEN ok := ok + 1; report := report || E'\nOK  X01 retrait sans motif suffisant refusé (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  X01 retrait motif court : ' || st; END IF;

  imp := public.archive_balance_import(i4, 'Doublon de la balance annuelle');
  IF imp.status = 'archive' AND NOT imp.is_reference AND imp.archived_by = ua THEN
    ok := ok + 1; report := report || E'\nOK  X02 retrait motivé : conservé, plus utilisé comme référence';
  ELSE ko := ko + 1; report := report || E'\nKO  X02 retrait'; END IF;

  st := 'aucune erreur';
  BEGIN PERFORM public.abandon_balance_import(i2);
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS011' THEN ok := ok + 1; report := report || E'\nOK  X03 une balance validée ne peut pas être abandonnée (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  X03 abandon validée : ' || st; END IF;

  imp := public.abandon_balance_import(i3);
  IF imp.status = 'abandonne' THEN ok := ok + 1; report := report || E'\nOK  X04 brouillon abandonné et conservé';
  ELSE ko := ko + 1; report := report || E'\nKO  X04 abandon brouillon'; END IF;

  -- ===== Clôture possible une fois les imports traités, puis exercice figé =====
  UPDATE public.fiscal_years SET status = 'cloture' WHERE id = fy1;
  SELECT count(*) INTO n FROM public.fiscal_years WHERE id = fy1 AND status = 'cloture';
  IF n = 1 THEN ok := ok + 1; report := report || E'\nOK  E04 clôture acceptée quand aucun import n''est en cours';
  ELSE ko := ko + 1; report := report || E'\nKO  E04 clôture'; END IF;

  st := 'aucune erreur';
  BEGIN INSERT INTO public.balance_imports(company_id, fiscal_year_id, balance_type, amount_basis, period_start, period_end, file_name)
        VALUES (ca, fy1, 'mensuelle', 'cumulee', '2030-01-01', '2030-01-31', 'x.xlsx');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS010' THEN ok := ok + 1; report := report || E'\nOK  E05 import dans un exercice clôturé refusé (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  E05 import exercice clôturé : ' || st; END IF;

  st := 'aucune erreur';
  BEGIN PERFORM public.set_reference_balance_import(i4);
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st IN ('FS010', 'FS011') THEN ok := ok + 1; report := report || E'\nOK  E06 aucune opération sur les imports d''un exercice clôturé (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  E06 opération exercice clôturé : ' || st; END IF;

  -- ===== Entreprise archivée =====
  INSERT INTO public.balance_imports(company_id, fiscal_year_id, balance_type, amount_basis, period_start, period_end, file_name)
  VALUES (ca, fy2, 'mensuelle', 'periodique', '2031-01-01', '2031-01-31', 'TEST_SYNTHETIQUE_janvier.xlsx') RETURNING id INTO i6;
  PERFORM public.abandon_balance_import(i6);
  UPDATE public.companies SET archived_at = now() WHERE id = ca;
  st := 'aucune erreur';
  BEGIN INSERT INTO public.balance_imports(company_id, fiscal_year_id, balance_type, amount_basis, period_start, period_end, file_name)
        VALUES (ca, fy2, 'mensuelle', 'periodique', '2031-02-01', '2031-02-28', 'x.xlsx');
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS007' THEN ok := ok + 1; report := report || E'\nOK  E07 import dans une entreprise archivée refusé (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  E07 import entreprise archivée : ' || st; END IF;
  RESET ROLE;

  -- ===== Anonyme et vidage =====
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  SET LOCAL ROLE anon;
  st := 'aucune erreur';
  BEGIN SELECT count(*) INTO n FROM public.balance_imports;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = '42501' THEN ok := ok + 1; report := report || E'\nOK  N01 accès anonyme aux imports refusé (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  N01 accès anonyme : ' || st; END IF;
  RESET ROLE;

  st := 'aucune erreur';
  BEGIN TRUNCATE public.balance_lines;
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  IF st = 'FS001' THEN ok := ok + 1; report := report || E'\nOK  N02 vidage des lignes de balance refusé (' || st || ')';
  ELSE ko := ko + 1; report := report || E'\nKO  N02 vidage : ' || st; END IF;

  -- Catalogue : fonctions privilégiées exposées aux comptes connectés = liste attendue, sans accès anonyme
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace s ON s.oid = p.pronamespace
   WHERE s.nspname = 'public' AND p.prosecdef AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND p.proname NOT IN ('can_access_company', 'is_company_owner', 'validate_balance_import', 'set_reference_balance_import',
                           'archive_balance_import', 'abandon_balance_import', 'acknowledge_balance_issue');
  SELECT count(*) INTO n2 FROM pg_proc p JOIN pg_namespace s ON s.oid = p.pronamespace
   WHERE s.nspname = 'public' AND p.proname LIKE '%balance%' AND has_function_privilege('anon', p.oid, 'EXECUTE');
  IF n = 0 AND n2 = 0 THEN ok := ok + 1; report := report || E'\nOK  N03 catalogue : aucune fonction privilégiée inattendue, pas d''accès anonyme';
  ELSE ko := ko + 1; report := report || E'\nKO  N03 catalogue : ' || n || ' en trop, ' || n2 || ' anonymes'; END IF;

  RAISE EXCEPTION 'RAPPORT FISFIN 2 (annulé, aucune donnée conservée) : % réussis, % échoués%', ok, ko, report;
END
$test$;
