import { createFileRoute } from "@tanstack/react-router";
import { useState, type FormEvent } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { z } from "zod";
import { supabase } from "@/integrations/supabase/client";
import { useWorkspace } from "@/lib/workspace";
import { updateProfile } from "@/lib/data/queries";
import { passwordSchema } from "@/lib/validation";
import { PageHeader, Panel } from "@/components/layout/PageHeader";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export const Route = createFileRoute("/_authenticated/profil")({
  head: () => ({ meta: [{ title: "Profil — FISFIN" }, { name: "description", content: "Votre profil FISFIN." }, { property: "og:title", content: "Profil — FISFIN" }, { property: "og:description", content: "Profil utilisateur." }] }),
  component: ProfilePage,
});

const profileSchema = z.object({
  full_name: z.string().trim().min(2, "Nom requis").max(100),
  job_title: z.string().trim().max(100).transform((v) => v || null),
  phone: z.string().trim().max(30).regex(/^[+0-9 ()-]*$/, "Numéro invalide").transform((v) => v || null),
});

function ProfilePage() {
  const ws = useWorkspace();
  const qc = useQueryClient();
  const [busy, setBusy] = useState(false);

  async function onProfile(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const p = profileSchema.safeParse(Object.fromEntries(new FormData(e.currentTarget)));
    if (!p.success) return toast.error(p.error.issues[0]!.message);
    setBusy(true);
    try { await updateProfile(ws.user.id, p.data); await qc.invalidateQueries({ queryKey: ["profile"] }); toast.success("Profil enregistré."); }
    catch (err) { toast.error((err as Error).message); } finally { setBusy(false); }
  }

  async function onPassword(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    const f = new FormData(form);
    const p = passwordSchema.safeParse(f.get("password"));
    if (!p.success) return toast.error(p.error.issues[0]!.message);
    if (f.get("password") !== f.get("confirm")) return toast.error("Les mots de passe ne correspondent pas.");
    const { error } = await supabase.auth.updateUser({ password: p.data, current_password: String(f.get("current") ?? "") } as never);
    if (error) return toast.error(error.message);
    form.reset(); toast.success("Mot de passe modifié.");
  }

  return (
    <div className="space-y-6">
      <PageHeader title="Profil et paramètres" subtitle={ws.user.email ?? ""} />
      <div className="grid gap-6 lg:grid-cols-2">
        <Panel title="Informations personnelles">
          <form key={ws.profile?.updated_at} onSubmit={onProfile} className="space-y-4">
            <div className="space-y-1.5"><Label htmlFor="full_name">Nom complet</Label><Input id="full_name" name="full_name" defaultValue={ws.profile?.full_name ?? ""} required /></div>
            <div className="space-y-1.5"><Label htmlFor="job_title">Fonction</Label><Input id="job_title" name="job_title" defaultValue={ws.profile?.job_title ?? ""} placeholder="Ex. Directeur financier" /></div>
            <div className="space-y-1.5"><Label htmlFor="phone">Téléphone</Label><Input id="phone" name="phone" defaultValue={ws.profile?.phone ?? ""} placeholder="+221 …" /></div>
            <Button type="submit" variant="brand" disabled={busy}>Enregistrer</Button>
          </form>
        </Panel>
        <Panel title="Sécurité">
          <form onSubmit={onPassword} className="space-y-4">
            <div className="space-y-1.5"><Label htmlFor="current">Mot de passe actuel</Label><Input id="current" name="current" type="password" autoComplete="current-password" required /></div>
            <div className="space-y-1.5"><Label htmlFor="password">Nouveau mot de passe</Label><Input id="password" name="password" type="password" autoComplete="new-password" required /></div>
            <div className="space-y-1.5"><Label htmlFor="confirm">Confirmer</Label><Input id="confirm" name="confirm" type="password" autoComplete="new-password" required /></div>
            <Button type="submit" variant="outline">Changer le mot de passe</Button>
          </form>
        </Panel>
      </div>
    </div>
  );
}
