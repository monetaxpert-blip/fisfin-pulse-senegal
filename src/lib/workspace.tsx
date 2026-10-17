import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import type { User } from "@supabase/supabase-js";
import { companiesQuery, fiscalYearsQuery, profileQuery, updateProfile, type Company, type FiscalYear, type Profile } from "@/lib/data/queries";

interface Workspace {
  user: User;
  profile: Profile | null | undefined;
  companies: Company[];
  activeCompanies: Company[];
  activeCompany: Company | null;
  setActiveCompany: (id: string) => Promise<void>;
  fiscalYears: FiscalYear[];
  activeFiscalYear: FiscalYear | null;
  setActiveFiscalYearId: (id: string) => void;
  loading: boolean;
}

const Ctx = createContext<Workspace | null>(null);

export function WorkspaceProvider({ user, children }: { user: User; children: ReactNode }) {
  const qc = useQueryClient();
  const profileQ = useQuery(profileQuery(user.id));
  const companiesQ = useQuery(companiesQuery());
  const companies = companiesQ.data ?? [];
  const activeCompanies = companies.filter((c) => !c.archived_at);

  const activeCompany =
    activeCompanies.find((c) => c.id === profileQ.data?.active_company_id) ?? activeCompanies[0] ?? null;

  const fyQ = useQuery(fiscalYearsQuery(activeCompany?.id));
  const fiscalYears = activeCompany ? (fyQ.data ?? []) : [];
  const [fyId, setFyId] = useState<string | null>(null);
  useEffect(() => setFyId(null), [activeCompany?.id]);
  const activeFiscalYear = fiscalYears.find((f) => f.id === fyId) ?? fiscalYears[0] ?? null;

  const setActiveCompany = useCallback(
    async (id: string) => {
      await updateProfile(user.id, { active_company_id: id });
      await qc.invalidateQueries({ queryKey: ["profile", user.id] });
    },
    [qc, user.id],
  );

  const value = useMemo<Workspace>(
    () => ({
      user,
      profile: profileQ.data,
      companies,
      activeCompanies,
      activeCompany,
      setActiveCompany,
      fiscalYears,
      activeFiscalYear,
      setActiveFiscalYearId: setFyId,
      loading: profileQ.isLoading || companiesQ.isLoading,
    }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [user, profileQ.data, companiesQ.data, fyQ.data, fyId, profileQ.isLoading, companiesQ.isLoading, setActiveCompany],
  );
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useWorkspace() {
  const v = useContext(Ctx);
  if (!v) throw new Error("useWorkspace must be used within WorkspaceProvider");
  return v;
}
