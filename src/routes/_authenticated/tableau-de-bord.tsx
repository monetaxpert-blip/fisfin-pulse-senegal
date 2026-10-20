import { createFileRoute, Link } from "@tanstack/react-router";
import { Building2, CalendarRange, Database, Droplet, History, Landmark, LineChart, ShieldCheck, Upload, BarChart3 } from "lucide-react";
import { useWorkspace } from "@/lib/workspace";
import { Button } from "@/components/ui/button";
import { Panel } from "@/components/layout/PageHeader";
import { ActivityList } from "@/components/ActivityList";
import { formatDate } from "@/lib/format";

export const Route = createFileRoute("/_authenticated/tableau-de-bord")({
  head: () => ({ meta: [{ title: "Tableau de bord | FISFIN" }, { name: "description", content: "Vue d'ensemble financière de votre entreprise." }, { property: "og:title", content: "Tableau de bord | FISFIN" }, { property: "og:description", content: "Vue d'ensemble financière." }] }),
  component: Dashboard,
});

const kpis = [
  { label: "Total actif", icon: Database },
  { label: "Résultat net", icon: BarChart3 },
  { label: "Ratio de liquidité", icon: Droplet },
  { label: "Taux d'endettement", icon: ShieldCheck },
];

function Dashboard() {
  const ws = useWorkspace();
  const first = (ws.profile?.full_name || "").split(" ")[0];

  if (ws.loading) return <p className="text-muted-foreground">Chargement…</p>;

  if (!ws.activeCompany)
    return (
      <div className="mx-auto max-w-2xl rounded-2xl border bg-card p-10 text-center shadow-card">
        <span className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-accent text-primary"><Building2 className="h-7 w-7" /></span>
        <h1 className="mt-5 text-2xl font-bold text-navy">Bienvenue{first ? `, ${first}` : ""} sur FISFIN</h1>
        <p className="mt-2 text-muted-foreground">Commencez par créer votre entreprise, puis son exercice comptable. Vous pourrez ensuite importer votre première balance.</p>
        <Button asChild variant="brand" className="mt-6"><Link to="/entreprises">Créer mon entreprise</Link></Button>
      </div>
    );

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-navy md:text-3xl">Bonjour{first ? `, ${first}` : ""}</h1>
        <p className="mt-1 text-muted-foreground">Situation de {ws.activeCompany.name}{ws.activeFiscalYear ? `, exercice ${ws.activeFiscalYear.label}` : ""}.</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {kpis.map((k) => (
          <div key={k.label} className="rounded-2xl border bg-card p-5 shadow-card">
            <span className="flex h-11 w-11 items-center justify-center rounded-full bg-accent text-primary"><k.icon className="h-5 w-5" /></span>
            <p className="mt-4 text-sm text-muted-foreground">{k.label}</p>
            <p className="mt-1 text-xl font-bold text-muted-foreground">Non calculable</p>
            <p className="mt-1 text-xs text-muted-foreground">Données manquantes : aucune balance importée</p>
          </div>
        ))}
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <Panel title="Première balance" icon={<Upload className="h-5 w-5 text-primary" />} className="lg:col-span-2">
          {!ws.activeFiscalYear ? (
            <div className="space-y-3">
              <p className="text-muted-foreground">Créez un exercice comptable pour cette entreprise avant d'importer une balance.</p>
              <Button asChild variant="brand"><Link to="/exercices"><CalendarRange />Créer un exercice</Link></Button>
            </div>
          ) : (
            <div className="space-y-3">
              <p className="text-muted-foreground">
                Exercice {ws.activeFiscalYear.label} : du {formatDate(ws.activeFiscalYear.start_date)} au {formatDate(ws.activeFiscalYear.end_date)}.
              </p>
              <p className="text-sm text-muted-foreground">L'import des balances Excel/CSV, les indicateurs et les diagnostics seront activés dans les prochaines phases. Aucun chiffre n'est affiché tant qu'aucune donnée réelle n'est importée.</p>
              <Button disabled title="Disponible en Phase 2"><Upload />Importer une balance (bientôt)</Button>
            </div>
          )}
        </Panel>
        <Panel title="Dernières activités" icon={<History className="h-5 w-5 text-primary" />}>
          <ActivityList companyId={ws.activeCompany.id} limit={6} />
        </Panel>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        {[{ i: LineChart, t: "Analyse financière", d: "Rentabilité, liquidité, solvabilité, évolution N/N-1/N-2." }, { i: Landmark, t: "Diagnostics et alertes", d: "Règles traçables issues du référentiel FISFIN." }].map((x) => (
          <div key={x.t} className="flex items-start gap-4 rounded-2xl border border-dashed bg-card/60 p-5">
            <x.i className="h-6 w-6 shrink-0 text-muted-foreground" />
            <div><p className="font-semibold text-navy">{x.t} <span className="ml-1 rounded-full bg-secondary px-2 py-0.5 text-xs text-secondary-foreground">Bientôt</span></p><p className="text-sm text-muted-foreground">{x.d}</p></div>
          </div>
        ))}
      </div>
    </div>
  );
}
