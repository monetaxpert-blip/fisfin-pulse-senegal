<!-- LOVABLE:BEGIN -->
> [!IMPORTANT]
> This project is connected to [Lovable](https://lovable.dev). Avoid rewriting
> published git history — force pushing, or rebasing/amending/squashing commits
> that are already pushed — as it rewrites history on Lovable's side and the
> user will likely lose their project history.
>
> Commits you push to the connected branch sync back to Lovable and show up in
> the editor, so keep the branch in a working state.
<!-- LOVABLE:END -->

# FISFIN engineering rules
- Company access is decided only by `private.has_company_access(user, company)` (wrapped by `public.can_access_company` for RLS); future sharing/membership logic goes there, never into individual policies. Why: one audited place for authorization.
- Companies are never hard-deleted: no DELETE grant or policy, a BEFORE DELETE/TRUNCATE trigger blocks it, child FKs use ON DELETE RESTRICT. Why: archiving preserves accounting history.
- Every new table referencing `fiscal_years` uses ON DELETE RESTRICT and must be added to `private.fiscal_year_has_accounting_data`. Why: the fiscal-year delete guard relies on it.
- Every new public table gets explicit REVOKE ALL then minimal GRANTs per role (no TRUNCATE, no anon unless public). Why: this project inherited ALL privileges by default.
- Business rule errors raised by the database use custom SQLSTATE codes `FSxxx`, translated in `dbErrorMessage` (src/lib/validation.ts). Why: stable, user-readable errors.
- Database security scenarios live in `supabase/tests/*.sql` as self-rolling-back DO blocks; rerun them after any RLS or trigger change. Why: they exercise RLS with simulated JWT identities.
