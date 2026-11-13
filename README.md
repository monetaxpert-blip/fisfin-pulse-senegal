# FISFIN

# FISFIN — CONCEPTION ET DÉVELOPPEMENT DE LA PLATEFORME FINANCIÈRE

## 1. TON RÔLE

Agis comme une équipe senior composée de :
- Un architecte logiciel SaaS spécialisé en applications financières.
- Un expert React, TypeScript, Supabase et PostgreSQL.
- Un expert UX/UI spécialisé dans les logiciels financiers professionnels.
- Un expert en analyse financière selon le référentiel SYSCOHADA.
- Un ingénieur QA chargé de vérifier chaque fonctionnalité et chaque calcul.

Tu dois concevoir et développer une application financière professionnelle, sécurisée, cohérente et réellement fonctionnelle pour les PME sénégalaises.

Ne te contente pas de générer une maquette. Construis une application exploitable, avec une architecture adaptée à l'ajout ultérieur de fonctionnalités.

# 2. PRÉSENTATION DU PROJET

Nom : FISFIN

Signature : « Votre gestion simplifiée »

Positionnement : plateforme numérique de pilotage financier des PME à partir de leurs données comptables.

Objectif : permettre à une PME d'importer ses données comptables, de suivre ses performances financières, de comprendre sa situation économique, de détecter des situations à surveiller et de prendre des décisions mieux éclairées.

FISFIN doit notamment répondre à ces questions :
- Quelle est la situation financière de l'entreprise ?
- L'entreprise est-elle rentable ?
- Dispose-t-elle d'une trésorerie suffisante ?
- Sa structure financière est-elle équilibrée ?
- Comment évoluent son chiffre d'affaires et ses résultats ?
- Quelles charges pèsent le plus sur sa performance ?
- Quels indicateurs nécessitent une attention particulière ?
- Quelles actions de gestion méritent d'être examinées ?

La plateforme est destinée aux PME sénégalaises et doit privilégier le référentiel SYSCOHADA.

# 3. PÉRIMÈTRE STRICT

Pour cette première version, développe exclusivement la partie financière.

INCLUS :
- Gestion des utilisateurs et des entreprises.
- Gestion des exercices comptables.
- Importation des balances comptables Excel et CSV.
- Contrôle et normalisation des données.
- Calcul des indicateurs financiers définis dans le référentiel FISFIN.
- Analyses financières.
- Diagnostics et alertes financiers.
- Recommandations liées aux résultats calculés.
- Tableaux de bord.
- Comparaisons entre périodes.
- Export des résultats et rapports financiers.

EXCLUS :
- Calendrier fiscal.
- Obligations fiscales.
- Calcul des impôts.
- Calcul de TVA.
- Calcul des pénalités.
- Toute règle fiscale automatique.

Ne développe pas le module fiscal dans cette version. N'ajoute pas de données fiscales fictives. L'architecture doit rester suffisamment modulaire pour permettre son ajout ultérieur sans réécriture majeure.

# 4. IDENTITÉ VISUELLE OBLIGATOIRE

Utilise le logo FISFIN fourni par l'utilisateur. Ne le redessine pas, ne le déforme pas et ne le remplace pas par un logo généré.

Respecte la palette suivante :

- Bleu marine profond : #102746
- Bleu nuit : #071A3D
- Bleu royal : #123FC4
- Indigo électrique : #3023C8
- Blanc : #FFFFFF
- Gris clair : #F3F6FB
- Gris de bordure : #E1E8F2
- Texte secondaire : #657796
- Vert positif : #16A765
- Rouge d'alerte : #D64545
- Orange d'attention : #E99A26

Le bleu marine et le bleu nuit doivent structurer la navigation. Le bleu royal et l'indigo doivent mettre en valeur les éléments interactifs et les visualisations.

Utilise :
- Une barre latérale bleu nuit avec le logo officiel.
- Une interface principale claire.
- Des cartes blanches avec des bordures discrètes.
- Des graphiques lisibles.
- Une hiérarchie typographique professionnelle.
- Des espaces réguliers.
- Des tableaux financiers bien alignés.
- Des icônes cohérentes.
- Des états visuels clairs pour les alertes et les indicateurs.

La capture fournie sert de référence visuelle. Reproduis son langage graphique, sa palette, son organisation générale et son niveau de finition, sans copier aveuglément les données fictives qu'elle contient.

Le résultat doit évoquer un logiciel de gestion financière professionnel, pas un simple template SaaS générique.

L'interface doit être entièrement en français, adaptée aux ordinateurs et aux téléphones.

Devise d'affichage par défaut : FCFA (XOF).

# 5. TECHNOLOGIES ET ARCHITECTURE

Utilise :
- React.
- TypeScript.
- Tailwind CSS et les composants UI compatibles avec le projet Lovable.
- Supabase pour PostgreSQL, l'authentification et le stockage sécurisé des fichiers.
- Une bibliothèque de graphiques compatible avec React.
- Une bibliothèque fiable de lecture Excel et CSV.

Avant de commencer, inspecte les technologies et les fichiers déjà présents. Ne réinitialise pas inutilement le projet.

Sépare clairement :
- L'interface utilisateur.
- L'accès aux données.
- La validation des fichiers.
- La normalisation comptable.
- Le moteur de calcul financier.
- Les diagnostics.
- Les recommandations.
- La génération des rapports.

Les calculs financiers doivent être effectués dans une logique métier testable et centralisée, et non directement dans les composants visuels.

Ne crée pas un monolithe difficile à maintenir.

# 6. AUTHENTIFICATION ET GESTION DES ENTREPRISES

Implémente :
- Inscription.
- Connexion.
- Déconnexion.
- Gestion des sessions.
- Réinitialisation du mot de passe.
- Profil utilisateur.
- Création et modification d'une entreprise.
- Sélection de l'entreprise active.
- Gestion des exercices comptables.
- Historique des imports.

Informations d'entreprise :
- Raison sociale.
- Forme juridique.
- Secteur d'activité.
- Numéro d'identification fiscale, facultatif.
- Adresse, facultative.
- Devise.
- Date de début d'activité, facultative.
- Exercice comptable.
- Utilisateur propriétaire.

Chaque utilisateur ne doit accéder qu'aux données auxquelles il est autorisé.

Configure correctement les politiques RLS Supabase sur toutes les tables contenant des données privées. Vérifie les permissions côté serveur et ne compte jamais uniquement sur l'interface pour protéger les données.

Ne mets aucune clé secrète dans le code client.

# 7. MODULE D'IMPORTATION COMPTABLE

C'est l'une des fonctions les plus importantes de FISFIN.

Permets l'importation de fichiers Excel et CSV contenant une balance comptable.

Prévois un parcours en plusieurs étapes :

1. Sélection du fichier.
2. Vérification du format.
3. Lecture des colonnes.
4. Association des colonnes aux champs attendus.
5. Aperçu des données.
6. Contrôle des erreurs.
7. Résumé des anomalies.
8. Confirmation de l'importation.
9. Enregistrement et traçabilité.

Format cible minimal :

- Numéro de compte.
- Libellé du compte.
- Débit de la période.
- Crédit de la période.
- Solde débiteur.
- Solde créditeur.

Certaines sources peuvent ne pas fournir toutes ces colonnes. Permets le mappage et vérifie les informations nécessaires avant de poursuivre.

Métadonnées de l'import :
- Entreprise.
- Exercice.
- Période de début et de fin.
- Date d'importation.
- Nom du fichier.
- Utilisateur ayant réalisé l'import.
- Statut de validation.

Contrôles obligatoires :
- Fichier vide ou illisible.
- Colonnes manquantes.
- Comptes sans numéro.
- Valeurs non numériques.
- Lignes en double.
- Totaux débit/crédit incohérents.
- Solde comptable déséquilibré lorsque le contrôle est applicable.
- Import déjà réalisé pour la même période.
- Données incompatibles avec la période sélectionnée.

Distingue les erreurs bloquantes des avertissements.

Ne corrige jamais silencieusement une valeur comptable. Présente l'anomalie et demande une action explicite à l'utilisateur.

Ne lance aucun calcul financier sur un import invalide sans signaler clairement les limites des résultats.

Prévois la consultation, le remplacement contrôlé et l'archivage des imports, avec traçabilité des opérations.

# 8. RÉFÉRENTIEL FINANCIER

Le moteur financier doit être construit à partir du référentiel financier FISFIN validé, qui comprend notamment :

- 105 variables normalisées SYSCOHADA.
- 33 indicateurs financiers.
- 8 diagnostics.
- Des règles d'alerte.
- Des recommandations.
- Des contrôles de cohérence.
- Des tests de validation.

Le référentiel maître sera fourni séparément. Ne prétends pas l'avoir lu si le fichier n'est pas disponible dans le projet.

Avant d'implémenter les calculs :
1. Lis le référentiel maître.
2. Identifie les variables et leurs sources.
3. Vérifie les formules et les dépendances.
4. Identifie les données manquantes pour chaque calcul.
5. Établis une correspondance explicite entre les comptes importés et les variables financières.
6. Signale les correspondances ambiguës au lieu de les inventer.
7. Implémente les calculs avec des tests unitaires.
8. Compare les résultats avec des cas de référence.

N'invente aucune formule, aucun seuil et aucune interprétation présentés comme validés.

Si une formule ou un seuil est marqué comme devant être validé par un expert, conserve ce statut et empêche son activation automatique comme règle définitive.

## Indicateurs à couvrir

Les 33 indicateurs du référentiel comprennent notamment :

- Croissance du chiffre d'affaires.
- Croissance de la valeur ajoutée.
- Taux de marge commerciale.
- Taux de valeur ajoutée.
- Marge d'EBE.
- Marge opérationnelle.
- Poids des charges de personnel dans la valeur ajoutée.
- Marge nette.
- Part du résultat hors activités ordinaires.
- Rentabilité des capitaux propres.
- Rentabilité économique.
- Autonomie financière.
- Fonds de roulement net global.
- Besoin en fonds de roulement d'exploitation.
- Besoin en fonds de roulement hors activités ordinaires.
- Besoin en fonds de roulement global.
- Trésorerie nette.
- Ratios de liquidité générale, réduite et immédiate.
- Endettement.
- Capacité de remboursement.
- Rotation des stocks.
- Délais clients.
- Délais fournisseurs.
- Durée du cycle d'exploitation.
- Cycle de conversion de trésorerie.
- Conversion du résultat en trésorerie.
- Flux de trésorerie disponible.
- Taux de capacité d'autofinancement.
- Analyse horizontale.
- Analyse verticale.
- Analyse dynamique N/N-1/N-2.

Cette liste est indicative pour l'interface. Les identifiants, les formules et les définitions de référence doivent être lus dans le fichier maître avant le codage.

Ne prétends pas calculer un indicateur lorsque les données requises sont absentes.

Une balance de clôture seule ne permet pas nécessairement de calculer les flux de trésorerie, les comparaisons historiques ou certains indicateurs nécessitant des moyennes de période.

Prévois les statuts :
- Calculé.
- Non calculable : données manquantes.
- Non applicable.
- À vérifier.
- Bloqué par une anomalie.

Une division par zéro doit être traitée proprement. N'affiche jamais une valeur infinie, une erreur technique ou un zéro trompeur pour masquer une donnée non calculable.

# 9. MODULE D'ANALYSE FINANCIÈRE

Crée une page principale d'analyse financière comprenant les sections suivantes :

### A. Situation financière
- Structure actif/passif.
- FRNG.
- BFR.
- Trésorerie nette.
- Équilibre financier.

### B. Rentabilité
- Chiffre d'affaires.
- Valeur ajoutée.
- EBE.
- Résultat d'exploitation.
- Résultat net.
- Marges et ratios de rentabilité.

### C. Liquidité
- Ratios de liquidité.
- Trésorerie disponible, si les données permettent de la déterminer.
- Évolution des besoins de financement à court terme.

### D. Solvabilité
- Autonomie financière.
- Endettement.
- Capacité de remboursement.
- Structure des ressources.

### E. Charges et produits
- Analyse des charges.
- Analyse des produits.
- Principaux postes de variation.
- Comparaison entre périodes lorsque les données existent.

### F. Évolution
- Comparaison N/N-1/N-2.
- Analyse horizontale.
- Analyse verticale.
- Graphiques temporels lorsque les périodes sont comparables.

Les tableaux et graphiques doivent provenir des données réellement importées et des calculs réellement exécutés.

# 10. DIAGNOSTICS, ALERTES ET RECOMMANDATIONS

Implémente ces fonctionnalités à partir des règles du référentiel.

Un diagnostic doit présenter :
- Son identifiant.
- Son intitulé.
- Les données utilisées.
- Le résultat du contrôle.
- La règle appliquée.
- Le niveau de gravité.
- Une explication compréhensible.
- La période concernée.
- Les limites éventuelles de l'analyse.

Une recommandation doit être reliée à un indicateur ou à un diagnostic identifiable.

N'affirme pas qu'une entreprise est en difficulté, qu'elle est frauduleuse ou qu'elle est insolvable sans fondement dans les règles validées.

Ne confonds pas une alerte de gestion avec une conclusion d'audit comptable.

Si les données sont insuffisantes, indique que l'analyse est partielle.

# 11. TABLEAU DE BORD PRINCIPAL

Construis un tableau de bord inspiré de la capture fournie.

## En-tête
- Logo FISFIN.
- Recherche, si elle est réellement fonctionnelle.
- Profil utilisateur.
- Sélecteur d'entreprise.
- Sélecteur de période.
- Accès aux paramètres.

## Cartes d'indicateurs
Afficher uniquement des indicateurs calculés et disponibles :
- Total actif.
- Résultat net.
- Ratio de liquidité.
- Taux d'endettement.

Chaque carte peut afficher une comparaison avec la période précédente uniquement si les données nécessaires existent.

## Graphique de performance
Prévoir un graphique d'évolution du chiffre d'affaires, du résultat net et des charges lorsque les données sont disponibles.

## Répartition de l'actif
Présenter une visualisation calculée à partir des comptes disponibles et correctement classés.

## Alertes financières
Afficher les diagnostics et anomalies issus du moteur de règles.

## Activités récentes
Afficher les imports, les modifications et les événements réellement enregistrés.

N'affiche pas de montants, de dates, de variations ou d'événements fictifs comme s'ils provenaient d'une entreprise réelle.

Pour les nouveaux comptes, prévois un état vide professionnel qui explique comment importer la première balance.

# 12. RAPPORTS ET EXPORTS

Prévois des rapports professionnels comprenant :
- Identification de l'entreprise.
- Période analysée.
- Résumé de la situation financière.
- Indicateurs calculés.
- Tableaux et graphiques.
- Diagnostics.
- Recommandations.
- Limites et données manquantes.
- Date de génération.

Permets l'export des résultats dans les formats adaptés, notamment Excel et PDF.

Vérifie que les valeurs exportées correspondent exactement aux résultats présentés à l'écran.

Ne présente pas un rapport comme certifié ou audité par un expert-comptable.

# 13. QUALITÉ ET TESTS

Teste au minimum :
- Inscription et connexion.
- Gestion des sessions.
- Création d'entreprise.
- Isolation des données entre utilisateurs.
- Import d'une balance valide.
- Rejet d'un fichier invalide.
- Détection des incohérences débit/crédit.
- Traitement des valeurs manquantes.
- Calculs financiers sur des cas de référence.
- Gestion des divisions par zéro.
- Affichage des états vides.
- Fonctionnement des filtres.
- Cohérence entre tableau de bord et rapports.
- Export des données.
- Utilisation sur mobile et ordinateur.

Crée des jeux de données synthétiques uniquement pour les tests, en les identifiant clairement comme tels. Ils ne doivent pas être mélangés aux données des utilisateurs.

Chaque bouton visible doit fonctionner, être explicitement désactivé avec une explication, ou être retiré.

# 14. MÉTHODE D'EXÉCUTION

Travaille par phases contrôlées :

PHASE 1 : architecture, authentification, gestion des entreprises et sécurité.

PHASE 2 : importation comptable, validation et stockage des balances.

PHASE 3 : normalisation SYSCOHADA et moteur financier.

PHASE 4 : indicateurs, diagnostics, alertes et recommandations.

PHASE 5 : tableau de bord, analyses comparatives et rapports.

PHASE 6 : tests complets, corrections et préparation de la démonstration.

Ne tente pas de coder toute la plateforme en une seule opération si cela augmente le risque d'erreur.

Commence par analyser le projet, puis réalise uniquement la PHASE 1. Termine par un bilan des éléments réellement implémentés et testés.

Ne passe pas automatiquement à la phase suivante sans vérifier la stabilité de la phase en cours.

# CRITÈRE FINAL

FISFIN doit être une application financière réellement fonctionnelle, sécurisée et évolutive, fondée sur les données comptables des entreprises et sur un référentiel financier traçable.

La priorité absolue est la fiabilité des données, la justesse des calculs, la sécurité et la cohérence fonctionnelle. Le design est important, mais il ne doit jamais masquer une fonctionnalité inexistante ou un calcul non validé.

This project was built with [Lovable](https://lovable.dev).

## Build with Lovable

Continue developing this project in the [Lovable editor](https://lovable.dev/projects/554d320b-e5d8-4518-9b86-4af8141f7530).

- **Ship faster**: describe what you want to build and Lovable handles the code.
- **Stay in sync**: every change made in Lovable is committed straight to this repository.
- **Full ownership**: this code is yours. Push to `main` on GitHub and your changes sync back into Lovable, ready for your next prompt.

## Development

Prefer working locally? You need Node.js and npm — [install with nvm](https://github.com/nvm-sh/nvm#installing-and-updating).

```sh
git clone <this-repository-url>
cd <repository-name>
npm i
npm run dev
```
