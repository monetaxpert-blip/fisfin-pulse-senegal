import { createFileRoute } from "@tanstack/react-router";
import { useState, type FormEvent } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { Archive, ArchiveRestore, Building2, CheckCircle2, Pencil, Plus } from "lucide-react";
import { useWorkspace } from "@/lib/workspace";
import { createCompany, updateCompany, type Company } from "@/lib/data/queries";
import { companySchema, LEGAL_FORMS, SECTORS } from "@/lib/validation";
import { MONTHS_FR, formatDate } from "@/lib/format";
import { PageHeader } from "@/components/layout/PageHeader";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog";

export const Route = createFileRoute("/_authenticated/entreprises")({
  head: () => ({ meta: [{ title: "Mes entreprises — FISFIN" }, { name: "description", content: "Gérez vos entreprises." }, { property: "og:title", content: "Mes entreprises — FISFIN" }, { property: "og:description", content: "Gestion des entreprises." }] }),
  component: Companies,
});

const sel = "flex h-9 w-full rounded-md border border-input bg-card px-3 text-sm shadow-sm focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring";

function Companies() {
  const ws = useWorkspace();
  const qc = useQueryClient();
  const [editing, setEditing] = useState<Company | "new" | null>(null);

  async function toggleArchive(c: Company) {
    try {
      await updateCompany(c.id, { archived_at: c.archived_at ? null : new Date().toISOString() });
      await qc.invalidateQueries({ queryKey: ["companies"] });
      toast.success(c.archived_at ? "Entreprise restaurée." : "Entreprise archivée.");
    } catch (e) { toast.error((e as Error).message); }
  }

  return (
    <div>
      <PageHeader title="Mes entreprises" subtitle="Créez et gérez les entreprises que vous pilotez." actions={<Button variant="brand" onClick={() => setEditing("new")}><Plus />Nouvelle entreprise</Button>} />
      {ws.companies.length === 0 ? (
        <div className="rounded-2xl border bg-card p-10 text-center shadow-card">
          <Building2 className="mx-auto h-10 w-10 text-primary" />
          <p className="mt-4 font-semibold text-navy">Aucune entreprise</p>
          <p className="text-sm text-muted-foreground">Créez votre première entreprise pour commencer.</p>
        </div>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {ws.companies.map((c) => {
            const active = ws.activeCompany?.id === c.id;
            return (
              <div key={c.id} className={`rounded-2xl border bg-card p-5 shadow-card ${active ? "ring-2 ring-primary" : ""} ${c.archived_at ? "opacity-60" : ""}`}>
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <h3 className="truncate font-bold text-navy">{c.name}</h3>
                    <p className="text-sm text-muted-foreground">{c.legal_form} · {c.sector}</p>
                  </div>
                  {active && <span className="flex shrink-0 items-center gap-1 rounded-full bg-accent px-2 py-0.5 text-xs font-medium text-primary"><CheckCircle2 className="h-3.5 w-3.5" />Active</span>}
                  {c.archived_at && <span className="shrink-0 rounded-full bg-muted px-2 py-0.5 text-xs">Archivée</span>}
                </div>
                <dl className="mt-4 grid grid-cols-2 gap-2 text-sm">
                  <dt className="text-muted-foreground">Devise</dt><dd>{c.currency === "XOF" ? "FCFA (XOF)" : c.currency}</dd>
                  <dt className="text-muted-foreground">NINEA</dt><dd className="truncate">{c.tax_id || "—"}</dd>
                  <dt className="text-muted-foreground">Début d'exercice</dt><dd>{MONTHS_FR[c.fiscal_year_start_month - 1]}</dd>
                  <dt className="text-muted-foreground">Début d'activité</dt><dd>{formatDate(c.activity_start_date)}</dd>
                </dl>
                <div className="mt-4 flex flex-wrap gap-2">
                  {!active && !c.archived_at && <Button size="sm" onClick={() => ws.setActiveCompany(c.id).then(() => toast.success(`${c.name} est l'entreprise active.`)).catch((e) => toast.error(e.message))}>Activer</Button>}
                  <Button size="sm" variant="outline" onClick={() => setEditing(c)}><Pencil />Modifier</Button>
                  <Button size="sm" variant="ghost" onClick={() => toggleArchive(c)}>{c.archived_at ? <><ArchiveRestore />Restaurer</> : <><Archive />Archiver</>}</Button>
                </div>
              </div>
            );
          })}
        </div>
      )}
      <CompanyDialog value={editing} onClose={() => setEditing(null)} />
    </div>
  );
}

function CompanyDialog({ value, onClose }: { value: Company | "new" | null; onClose: () => void }) {
  const qc = useQueryClient();
  const ws = useWorkspace();
  const [busy, setBusy] = useState(false);
  const c = value && value !== "new" ? value : null;

  async function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const parsed = companySchema.safeParse(Object.fromEntries(new FormData(e.currentTarget)));
    if (!parsed.success) return toast.error(parsed.error.issues[0]!.message);
    setBusy(true);
    try {
      if (c) await updateCompany(c.id, parsed.data);
      else {
        const created = await createCompany(parsed.data);
        if (!ws.activeCompany) await ws.setActiveCompany(created.id);
      }
      await qc.invalidateQueries({ queryKey: ["companies"] });
      await qc.invalidateQueries({ queryKey: ["activity"] });
      toast.success(c ? "Entreprise modifiée." : "Entreprise créée.");
      onClose();
    } catch (err) { toast.error((err as Error).message); } finally { setBusy(false); }
  }

  return (
    <Dialog open={!!value} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{c ? "Modifier l'entreprise" : "Nouvelle entreprise"}</DialogTitle>
          <DialogDescription>Les champs marqués * sont obligatoires.</DialogDescription>
        </DialogHeader>
        <form key={c?.id ?? "new"} onSubmit={onSubmit} className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-1.5 sm:col-span-2"><Label htmlFor="name">Raison sociale *</Label><Input id="name" name="name" defaultValue={c?.name} maxLength={200} required /></div>
          <div className="space-y-1.5"><Label htmlFor="legal_form">Forme juridique *</Label>
            <select id="legal_form" name="legal_form" className={sel} defaultValue={c?.legal_form ?? "SARL"}>{LEGAL_FORMS.map((f) => <option key={f}>{f}</option>)}</select></div>
          <div className="space-y-1.5"><Label htmlFor="sector">Secteur d'activité *</Label>
            <select id="sector" name="sector" className={sel} defaultValue={c?.sector ?? "Commerce"}>{SECTORS.map((f) => <option key={f}>{f}</option>)}</select></div>
          <div className="space-y-1.5"><Label htmlFor="tax_id">NINEA (facultatif)</Label><Input id="tax_id" name="tax_id" defaultValue={c?.tax_id ?? ""} maxLength={50} /></div>
          <div className="space-y-1.5"><Label htmlFor="currency">Devise *</Label>
            <select id="currency" name="currency" className={sel} defaultValue={c?.currency ?? "XOF"}><option value="XOF">FCFA (XOF)</option><option value="EUR">Euro (EUR)</option><option value="USD">Dollar (USD)</option></select></div>
          <div className="space-y-1.5 sm:col-span-2"><Label htmlFor="address">Adresse (facultative)</Label><Input id="address" name="address" defaultValue={c?.address ?? ""} maxLength={300} /></div>
          <div className="space-y-1.5"><Label htmlFor="activity_start_date">Début d'activité (facultatif)</Label><Input id="activity_start_date" name="activity_start_date" type="date" defaultValue={c?.activity_start_date ?? ""} /></div>
          <div className="space-y-1.5"><Label htmlFor="fiscal_year_start_month">Mois de début d'exercice *</Label>
            <select id="fiscal_year_start_month" name="fiscal_year_start_month" className={sel} defaultValue={c?.fiscal_year_start_month ?? 1}>{MONTHS_FR.map((m, i) => <option key={m} value={i + 1}>{m}</option>)}</select></div>
          <div className="flex justify-end gap-2 sm:col-span-2">
            <Button type="button" variant="outline" onClick={onClose}>Annuler</Button>
            <Button type="submit" variant="brand" disabled={busy}>{c ? "Enregistrer" : "Créer l'entreprise"}</Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}
