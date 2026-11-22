# FiveM Tracker, version GitHub Pages + Supabase (100 % gratuit)

Site statique (GitHub Pages) + base de données et comptes (Supabase, offre gratuite).

## 1. Supabase (5 min)
1. Crée un compte et un projet sur https://supabase.com (offre Free).
2. Menu **SQL Editor** > New query > colle tout `supabase.sql` > **Run**.
3. Menu **Authentication > Providers > Email** : désactive **Confirm email** (sinon les inscriptions exigent un email de confirmation).
4. Menu **Project Settings > API** : copie **Project URL** et la clé **anon public**.
5. Ouvre `config.js` et colle ces deux valeurs. Ne mets jamais la clé `service_role` dans ce fichier.
6. (Recommandé) Dans le SQL Editor, exécute cette ligne avec ton code secret :
   `insert into public.settings values('invite','MON-CODE-SECRET') on conflict(key) do update set value=excluded.value;`

## 2. GitHub Pages
1. Crée un dépôt public sur GitHub, puis **Add file > Upload files** et envoie tout le contenu de ce dossier (y compris `vendor/` et `.nojekyll`).
2. **Settings > Pages** : Source = *Deploy from a branch*, branche `main`, dossier `/ (root)` > Save.
3. Après 1 à 2 minutes, le site est sur `https://TON-PSEUDO.github.io/NOM-DU-DEPOT/`.

## 3. Premier lancement
Ouvre le site, clique sur « Créer un compte » : **le premier compte créé est administrateur**. Les suivants doivent saisir le code d'invitation.

## Sécurité
- Les droits (admin / responsable / membre) sont appliqués par la base de données (RLS + triggers), pas seulement par l'interface.
- L'URL et la clé anon sont publiques par conception : la protection vient des règles de la base.
- Ne mets jamais d'autre clé secrète dans le dépôt.
