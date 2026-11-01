import { createFileRoute, Link } from "@tanstack/react-router";
import { useState, type FormEvent } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { CalendarRange, Lock, LockOpen, Pencil, Plus, Trash2 } from "lucide-react";
import { useWorkspace } from "@/lib/workspace";
import { closeFiscalYear, createFiscalYear, deleteFiscalYear, reopenFiscalYear, updateFiscalYear, type FiscalYear } from "@/lib/data/queries";
import { defaultFiscalYear, fiscalYearDeletion, fiscalYearEditable, fiscalYearSchema, reopenReasonSchema } from "@/lib/validation";
import { formatDate } from "@/lib/format";
import { PageHeader, Panel } from "@/components/layout/PageHeader";
import { ActivityList } from "@/components/ActivityList";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from "@/components/ui/alert-dialog";

export const Route = createFileRoute("/_authenticated/exercices")({
  head: () => ({ meta: [{ title: "Exercices comptables | FISFIN" }, { name: "description", content: "Gérez les exercices comptables." }, { property: "og:title", content: "Exercices comptables | FISFIN" }, { property: "og:description", content: "Exercices comptables." }] }),
  component: FiscalYears,
});

function DisabledIcon({ reason, children }: { reason: string; children: React.ReactNode }) {
  return (
    <span title={reason} className="inline-flex">
      <Button size="icon" variant="ghost" disabled aria-label={reason}>{children}</Button>
    </span>
  );
}

function FiscalYears() {
  const ws = useWorkspace();
  const qc = useQueryClient();
  const [editing, setEditing] = useState<FiscalYear | "new" | null>(null);
  const [toDelete, setToDelete] = useState<FiscalYear | null>(null);
  const [toClose, setToClose] = useState<FiscalYear | null>(null);
  const [toReopen, setToReopen] = useState<FiscalYear | null>(null);
  const refresh = () => Promise.all([qc.invalidateQueries({ queryKey: ["fiscal_years"] }), qc.invalidateQueries({ queryKey: ["activity"] })]);

  if (!ws.activeCompany)
    return (
      <div className="rounded-2xl border bg-card p-10 text-center shadow-card">
        <p className="font-semibold text-navy">Aucune entreprise active</p>
        <Button asChild variant="brand" className="mt-4"><Link to="/entreprises">Créer une entreprise</Link></Button>
      </div>
    );

  return (
    <div className="space-y-6">
      <PageHeader title="Exercices comptables" subtitle={ws.activeCompany.name} actions={<Button variant="brand" onClick={() => setEditing("new")}><Plus />Nouvel exercice</Button>} />
      <Panel>
        {ws.fiscalYears.length === 0 ? (
          <div className="py-8 text-center"><CalendarRange className="mx-auto h-10 w-10 text-primary" /><p className="mt-3 text-muted-foreground">Aucun exercice. Créez-en un pour pouvoir importer une balance.</p></div>
        ) : (
          <div className="overflow-x-auto">
            <p className="mb-3 text-xs text-muted-foreground">Un exercice clôturé n'est plus modifiable. Il peut être rouvert pour une correction, avec un motif conservé dans l'historique, mais il ne pourra jamais être supprimé.</p>
            <table className="w-full text-sm">
              <thead><tr className="border-b text-left text-muted-foreground"><th className="py-2 pr-4 font-medium">Libellé</th><th className="py-2 pr-4 font-medium">Début</th><th className="py-2 pr-4 font-medium">Fin</th><th className="py-2 pr-4 font-medium">Statut</th><th className="py-2 text-right font-medium">Actions</th></tr></thead>
              <tbody>
                {ws.fiscalYears.map((f) => {
                  const del = fiscalYearDeletion(f);
                  const edit = fiscalYearEditable(f);
                  return (
                    <tr key={f.id} className="border-b last:border-0">
                      <td className="py-3 pr-4 font-semibold text-navy">{f.label}</td>
                      <td className="py-3 pr-4 tabular">{formatDate(f.start_date)}</td>
                      <td className="py-3 pr-4 tabular">{formatDate(f.end_date)}</td>
                      <td className="py-3 pr-4">
                        {f.status === "cloture" ? (
                          <span className="rounded-full bg-muted px-2 py-0.5 text-xs">Clôturé</span>
                        ) : f.first_closed_at ? (
                          <span className="rounded-full bg-accent px-2 py-0.5 text-xs text-primary" title={f.reopen_reason ? `Motif : ${f.reopen_reason}` : undefined}>Rouvert</span>
                        ) : (
                          <span className="rounded-full bg-accent px-2 py-0.5 text-xs text-primary">Ouvert</span>
                        )}
                      </td>
                      <td className="py-3 text-right whitespace-nowrap">
                        {edit.allowed ? (
                          <Button size="icon" variant="ghost" aria-label="Modifier" onClick={() => setEditing(f)}><Pencil /></Button>
                        ) : (
                          <DisabledIcon reason={`Modification impossible : ${edit.reason}`}><Pencil /></DisabledIcon>
                        )}
                        {f.status === "ouvert" ? (
                          <Button size="icon" variant="ghost" aria-label="Clôturer" onClick={() => setToClose(f)}><Lock /></Button>
                        ) : (
                          <Button size="icon" variant="ghost" aria-label="Rouvrir" onClick={() => setToReopen(f)}><LockOpen /></Button>
                        )}
                        {del.allowed ? (
                          <Button size="icon" variant="ghost" aria-label="Supprimer" onClick={() => setToDelete(f)}><Trash2 className="text-destructive" /></Button>
                        ) : (
                          <DisabledIcon reason={`Suppression impossible : ${del.reason}`}><Trash2 /></DisabledIcon>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </Panel>
      <Panel title="Historique des opérations"><ActivityList companyId={ws.activeCompany.id} limit={15} /></Panel>
      <FyDialog value={editing} onClose={() => setEditing(null)} onSaved={refresh} />
      <ReopenDialog value={toReopen} onClose={() => setToReopen(null)} onSaved={refresh} />
      <AlertDialog open={!!toClose} onOpenChange={(o) => !o && setToClose(null)}>
        <AlertDialogContent>
          <AlertDialogHeader><AlertDialogTitle>Clôturer l'exercice {toClose?.label} ?</AlertDialogTitle><AlertDialogDescription>Une fois clôturé, l'exercice n'est plus modifiable et ne pourra jamais être supprimé, même après une réouverture. La clôture est tracée dans l'historique.</AlertDialogDescription></AlertDialogHeader>
          <AlertDialogFooter><AlertDialogCancel>Annuler</AlertDialogCancel>
            <AlertDialogAction onClick={async () => { try { await closeFiscalYear(toClose!.id); await refresh(); toast.success("Exercice clôturé."); } catch (e) { toast.error((e as Error).message); } }}>Clôturer</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
      <AlertDialog open={!!toDelete} onOpenChange={(o) => !o && setToDelete(null)}>
        <AlertDialogContent>
          <AlertDialogHeader><AlertDialogTitle>Supprimer l'exercice {toDelete?.label} ?</AlertDialogTitle><AlertDialogDescription>Cette opération est définitive et sera tracée dans l'historique.</AlertDialogDescription></AlertDialogHeader>
          <AlertDialogFooter><AlertDialogCancel>Annuler</AlertDialogCancel>
            <AlertDialogAction onClick={async () => { try { await deleteFiscalYear(toDelete!.id); await refresh(); toast.success("Exercice supprimé."); } catch (e) { toast.error((e as Error).message); } }}>Supprimer</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}

function ReopenDialog({ value, onClose, onSaved }: { value: FiscalYear | null; onClose: () => void; onSaved: () => Promise<unknown> }) {
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const parsed = reopenReasonSchema.safeParse(new FormData(e.currentTarget).get("reason") ?? "");
    if (!parsed.success) return toast.error(parsed.error.issues[0]!.message);
    setBusy(true);
    try {
      await reopenFiscalYear(value!.id, parsed.data);
      await onSaved(); toast.success("Exercice rouvert. Le motif est enregistré dans l'historique."); onClose();
    } catch (err) { toast.error((err as Error).message); } finally { setBusy(false); }
  }

  return (
    <Dialog open={!!value} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Rouvrir l'exercice {value?.label}</DialogTitle>
          <DialogDescription>La réouverture est réservée à une correction comptable justifiée. Le motif, la date et l'auteur sont conservés dans l'historique. L'exercice restera non supprimable.</DialogDescription>
        </DialogHeader>
        <form key={value?.id ?? "none"} onSubmit={onSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="reason">Motif de la réouverture</Label>
            <Textarea id="reason" name="reason" required minLength={10} maxLength={500} rows={4} placeholder="Exemple : correction d'une écriture d'inventaire constatée après la clôture." />
          </div>
          <div className="flex justify-end gap-2"><Button type="button" variant="outline" onClick={onClose}>Annuler</Button><Button type="submit" variant="brand" disabled={busy}>Rouvrir l'exercice</Button></div>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function FyDialog({ value, onClose, onSaved }: { value: FiscalYear | "new" | null; onClose: () => void; onSaved: () => Promise<unknown> }) {
  const ws = useWorkspace();
  const [busy, setBusy] = useState(false);
  const f = value && value !== "new" ? value : null;
  const def = defaultFiscalYear(new Date().getFullYear(), ws.activeCompany?.fiscal_year_start_month ?? 1);

  async function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const parsed = fiscalYearSchema.safeParse({ ...Object.fromEntries(new FormData(e.currentTarget)), status: f?.status ?? "ouvert" });
    if (!parsed.success) return toast.error(parsed.error.issues[0]!.message);
    setBusy(true);
    try {
      if (f) await updateFiscalYear(f.id, parsed.data); else await createFiscalYear(ws.activeCompany!.id, parsed.data);
      await onSaved(); toast.success(f ? "Exercice modifié." : "Exercice créé."); onClose();
    } catch (err) { toast.error((err as Error).message); } finally { setBusy(false); }
  }

  return (
    <Dialog open={!!value} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader><DialogTitle>{f ? "Modifier l'exercice" : "Nouvel exercice"}</DialogTitle><DialogDescription>Les exercices d'une même entreprise ne peuvent pas se chevaucher.</DialogDescription></DialogHeader>
        <form key={f?.id ?? "new"} onSubmit={onSubmit} className="space-y-4">
          <div className="space-y-1.5"><Label htmlFor="label">Libellé</Label><Input id="label" name="label" defaultValue={f?.label ?? def.label} required maxLength={50} /></div>
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5"><Label htmlFor="start_date">Début</Label><Input id="start_date" name="start_date" type="date" defaultValue={f?.start_date ?? def.start_date} required /></div>
            <div className="space-y-1.5"><Label htmlFor="end_date">Fin</Label><Input id="end_date" name="end_date" type="date" defaultValue={f?.end_date ?? def.end_date} required /></div>
          </div>
          <div className="flex justify-end gap-2"><Button type="button" variant="outline" onClick={onClose}>Annuler</Button><Button type="submit" variant="brand" disabled={busy}>Enregistrer</Button></div>
        </form>
      </DialogContent>
    </Dialog>
  );
}
