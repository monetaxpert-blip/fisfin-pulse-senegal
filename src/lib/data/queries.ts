import { queryOptions } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import type { Database } from "@/integrations/supabase/types";
import type { CompanyValues, FiscalYearValues } from "@/lib/validation";

/** Data-access layer. All reads/writes rely on RLS policies enforced by the database. */

export type Company = Database["public"]["Tables"]["companies"]["Row"];
export type FiscalYear = Database["public"]["Tables"]["fiscal_years"]["Row"];
export type Profile = Database["public"]["Tables"]["profiles"]["Row"];
export type Activity = Database["public"]["Tables"]["activity_log"]["Row"];

function check<T>(res: { data: T; error: { message: string; code?: string } | null }): T {
  if (res.error) {
    if (res.error.code === "23P01") throw new Error("Cet exercice chevauche un exercice existant.");
    if (res.error.code === "23505") throw new Error("Un exercice porte déjà ce libellé.");
    throw new Error(res.error.message);
  }
  return res.data;
}

export const profileQuery = (userId: string) =>
  queryOptions({
    queryKey: ["profile", userId],
    queryFn: async () => check(await supabase.from("profiles").select("*").eq("id", userId).maybeSingle()),
  });

export const companiesQuery = () =>
  queryOptions({
    queryKey: ["companies"],
    queryFn: async () => check(await supabase.from("companies").select("*").order("created_at", { ascending: true })) ?? [],
  });

export const fiscalYearsQuery = (companyId: string | null | undefined) =>
  queryOptions({
    queryKey: ["fiscal_years", companyId],
    enabled: !!companyId,
    queryFn: async () =>
      check(await supabase.from("fiscal_years").select("*").eq("company_id", companyId!).order("start_date", { ascending: false })) ?? [],
  });

export const activityQuery = (companyId: string | null | undefined, limit = 10) =>
  queryOptions({
    queryKey: ["activity", companyId, limit],
    queryFn: async () => {
      let q = supabase.from("activity_log").select("*").order("created_at", { ascending: false }).limit(limit);
      if (companyId) q = q.eq("company_id", companyId);
      return check(await q) ?? [];
    },
  });

export async function updateProfile(userId: string, patch: Partial<Pick<Profile, "full_name" | "job_title" | "phone" | "active_company_id">>) {
  return check(await supabase.from("profiles").update(patch).eq("id", userId).select().single());
}

export async function createCompany(values: CompanyValues) {
  return check(await supabase.from("companies").insert(values).select().single());
}

export async function updateCompany(id: string, values: Partial<CompanyValues> & { archived_at?: string | null }) {
  return check(await supabase.from("companies").update(values).eq("id", id).select().single());
}

export async function createFiscalYear(companyId: string, values: FiscalYearValues) {
  return check(await supabase.from("fiscal_years").insert({ ...values, company_id: companyId }).select().single());
}

export async function updateFiscalYear(id: string, values: Partial<FiscalYearValues>) {
  return check(await supabase.from("fiscal_years").update(values).eq("id", id).select().single());
}

export async function deleteFiscalYear(id: string) {
  check(await supabase.from("fiscal_years").delete().eq("id", id));
}
