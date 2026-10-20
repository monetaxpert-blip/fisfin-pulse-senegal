import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useState, type FormEvent } from "react";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Logo } from "@/components/brand/Logo";
import { passwordSchema } from "@/lib/validation";

export const Route = createFileRoute("/reset-password")({
  head: () => ({
    meta: [
      { title: "Nouveau mot de passe | FISFIN" },
      { name: "description", content: "Définissez un nouveau mot de passe pour votre compte FISFIN." },
      { property: "og:title", content: "Nouveau mot de passe | FISFIN" },
      { property: "og:description", content: "Réinitialisation du mot de passe FISFIN." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: ResetPassword,
});

function ResetPassword() {
  const navigate = useNavigate();
  const [ready, setReady] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const isRecovery = window.location.hash.includes("type=recovery");
    const { data } = supabase.auth.onAuthStateChange((e) => {
      if (e === "PASSWORD_RECOVERY") setReady(true);
    });
    supabase.auth.getSession().then(({ data }) => { if (data.session && isRecovery) setReady(true); });
    return () => data.subscription.unsubscribe();
  }, []);

  async function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const pwd = passwordSchema.safeParse(f.get("password"));
    if (!pwd.success) return toast.error(pwd.error.issues[0]!.message);
    if (f.get("password") !== f.get("confirm")) return toast.error("Les mots de passe ne correspondent pas.");
    setBusy(true);
    const { error } = await supabase.auth.updateUser({ password: pwd.data });
    setBusy(false);
    if (error) return toast.error(error.message);
    toast.success("Mot de passe mis à jour.");
    navigate({ to: "/tableau-de-bord", replace: true });
  }

  return (
    <div className="flex min-h-screen items-center justify-center p-6">
      <div className="w-full max-w-md rounded-2xl border bg-card p-8 shadow-card">
        <Logo className="mx-auto mb-6 w-28" />
        <h1 className="text-xl font-bold text-navy">Nouveau mot de passe</h1>
        {!ready ? (
          <p className="mt-3 text-sm text-muted-foreground">Ouvrez cette page depuis le lien reçu par e-mail. Si le lien a expiré, demandez-en un nouveau depuis la page de connexion.</p>
        ) : (
          <form onSubmit={onSubmit} className="mt-6 space-y-4">
            <div className="space-y-1.5"><Label htmlFor="password">Nouveau mot de passe</Label><Input id="password" name="password" type="password" autoComplete="new-password" required /></div>
            <div className="space-y-1.5"><Label htmlFor="confirm">Confirmer</Label><Input id="confirm" name="confirm" type="password" autoComplete="new-password" required /></div>
            <Button type="submit" variant="brand" className="w-full" disabled={busy}>Enregistrer</Button>
          </form>
        )}
      </div>
    </div>
  );
}
