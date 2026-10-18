import { useQuery } from "@tanstack/react-query";
import { Building2, CalendarRange, History } from "lucide-react";
import { activityQuery, type Activity } from "@/lib/data/queries";
import { formatDateTime } from "@/lib/format";

const ACTION: Record<string, string> = { creation: "Création", modification: "Modification", suppression: "Suppression", archivage: "Archivage" };

function describe(a: Activity) {
  const d = (a.details ?? {}) as Record<string, string>;
  const entity = a.entity === "entreprise" ? `de l'entreprise ${d.nom ?? ""}` : `de l'exercice ${d.libelle ?? ""}`;
  return `${ACTION[a.action] ?? a.action} ${entity}`.trim();
}

export function ActivityList({ companyId, limit = 8 }: { companyId: string | null | undefined; limit?: number }) {
  const q = useQuery(activityQuery(companyId, limit));
  if (q.isLoading) return <p className="text-sm text-muted-foreground">Chargement…</p>;
  if (q.error) return <p className="text-sm text-destructive">{(q.error as Error).message}</p>;
  if (!q.data?.length)
    return (
      <div className="flex flex-col items-center py-6 text-center text-sm text-muted-foreground">
        <History className="mb-2 h-6 w-6" />Aucune activité enregistrée pour le moment.
      </div>
    );
  return (
    <ul className="divide-y">
      {q.data.map((a) => {
        const Icon = a.entity === "entreprise" ? Building2 : CalendarRange;
        return (
          <li key={a.id} className="flex items-start gap-3 py-3">
            <span className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-accent text-primary"><Icon className="h-4 w-4" /></span>
            <span className="min-w-0 flex-1 text-sm font-medium">{describe(a)}</span>
            <span className="shrink-0 text-xs text-muted-foreground">{formatDateTime(a.created_at)}</span>
          </li>
        );
      })}
    </ul>
  );
}
