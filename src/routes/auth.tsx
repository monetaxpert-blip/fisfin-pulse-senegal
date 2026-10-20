import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useState, type FormEvent } from "react";
import { z } from "zod";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { lovable } from "@/integrations/lovable";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Logo } from "@/components/brand/Logo";
import { passwordSchema, safeRedirect } from "@/lib/validation";

const search = z.object({
  redirect: z.string().optional(),
  mode: z.enum(["signin", "signup", "forgot"]).optional(),
});

export const Route = createFileRoute("/auth")({
  validateSearch: search,
  head: () => ({
    meta: [
      { title: "Connexion | FISFIN" },
      { name: "description", content: "Connectez-vous ou créez votre compte FISFIN." },
      { property: "og:title", content: "Connexion | FISFIN" },
      { property: "og:description", content: "Accédez à votre espace de pilotage financier FISFIN." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: AuthPage,
});

const emailSchema = z.string().trim().email("Adresse e-mail invalide").max(255);

function AuthPage() {
  const { redirect, mode } = Route.useSearch();
  const navigate = useNavigate();
  const target = safeRedirect(redirect);
  const [tab, setTab] = useState<"signin" | "signup" | "forgot">(mode ?? "signin");
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState<string | null>(null);

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => {
      if (data.user) navigate({ to: target, replace: true });
    });
    const { data } = supabase.auth.onAuthStateChange((e, s) => {
      if (e === "SIGNED_IN" && s) navigate({ to: target, replace: true });
    });
    return () => data.subscription.unsubscribe();
  }, [navigate, target]);

  async function onSignIn(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const email = emailSchema.safeParse(f.get("email"));
    if (!email.success) return toast.error(email.error.issues[0]!.message);
    setBusy(true);
    const { error } = await supabase.auth.signInWithPassword({ email: email.data, password: String(f.get("password") ?? "") });
    setBusy(false);
    if (error) toast.error(error.message === "Invalid login credentials" ? "Identifiants incorrects." : error.message === "Email not confirmed" ? "Confirmez d'abord votre adresse e-mail." : error.message);
  }

  async function onSignUp(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const name = z.string().trim().min(2, "Nom complet requis").max(100).safeParse(f.get("full_name"));
    const email = emailSchema.safeParse(f.get("email"));
    const pwd = passwordSchema.safeParse(f.get("password"));
    const err = [name, email, pwd].find((r) => !r.success);
    if (err && !err.success) return toast.error(err.error.issues[0]!.message);
    if (f.get("password") !== f.get("confirm")) return toast.error("Les mots de passe ne correspondent pas.");
    setBusy(true);
    const { data, error } = await supabase.auth.signUp({
      email: email.data!,
      password: pwd.data!,
      options: { emailRedirectTo: window.location.origin + target, data: { full_name: name.data } },
    });
    setBusy(false);
    if (error) return toast.error(error.message);
    if (!data.session) setSent(`Un e-mail de confirmation a été envoyé à ${email.data}. Cliquez sur le lien pour activer votre compte.`);
  }

  async function onForgot(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const email = emailSchema.safeParse(new FormData(e.currentTarget).get("email"));
    if (!email.success) return toast.error(email.error.issues[0]!.message);
    setBusy(true);
    const { error } = await supabase.auth.resetPasswordForEmail(email.data, { redirectTo: `${window.location.origin}/reset-password` });
    setBusy(false);
    if (error) return toast.error(error.message);
    setSent(`Si un compte existe pour ${email.data}, un lien de réinitialisation vient d'être envoyé.`);
  }

  async function onGoogle() {
    const result = await lovable.auth.signInWithOAuth("google", { redirect_uri: window.location.origin + "/auth" });
    if (result.error) toast.error("Connexion Google impossible.");
  }

  return (
    <div className="grid min-h-screen lg:grid-cols-2">
      <aside className="relative hidden overflow-hidden bg-sidebar-gradient p-12 text-sidebar-foreground lg:flex lg:flex-col lg:justify-between">
        <div className="w-fit rounded-xl bg-card px-5 py-4"><Logo className="w-36" /></div>
        <div>
          <p className="font-display text-3xl font-bold leading-snug">Des décisions éclairées<br />pour un avenir solide.</p>
          <p className="mt-4 max-w-md text-sidebar-muted">Analyse financière SYSCOHADA pour les PME sénégalaises.</p>
        </div>
        <p className="text-xs text-sidebar-muted">Vos données restent strictement privées et isolées par entreprise.</p>
      </aside>
      <main className="flex items-center justify-center p-6">
        <div className="w-full max-w-md">
          <div className="mb-8 lg:hidden"><Logo className="mx-auto w-32" /></div>
          {sent ? (
            <div className="rounded-2xl border bg-card p-8 shadow-card">
              <h1 className="text-xl font-bold text-navy">Vérifiez votre boîte e-mail</h1>
              <p className="mt-3 text-sm text-muted-foreground">{sent}</p>
              <Button className="mt-6 w-full" variant="outline" onClick={() => { setSent(null); setTab("signin"); }}>Retour à la connexion</Button>
            </div>
          ) : (
            <div className="rounded-2xl border bg-card p-8 shadow-card">
              <h1 className="text-2xl font-bold text-navy">{tab === "signup" ? "Créer un compte" : tab === "forgot" ? "Mot de passe oublié" : "Connexion"}</h1>
              <p className="mt-1 text-sm text-muted-foreground">
                {tab === "forgot" ? "Recevez un lien pour définir un nouveau mot de passe." : "Accédez à votre espace FISFIN."}
              </p>
              {tab !== "forgot" && (
                <>
                  <Button type="button" variant="outline" className="mt-6 w-full" onClick={onGoogle}>
                    <GoogleIcon /> Continuer avec Google
                  </Button>
                  <div className="my-5 flex items-center gap-3 text-xs text-muted-foreground"><span className="h-px flex-1 bg-border" />ou<span className="h-px flex-1 bg-border" /></div>
                </>
              )}
              <Tabs value={tab} onValueChange={(v) => setTab(v as typeof tab)}>
                {tab !== "forgot" && (
                  <TabsList className="mb-5 grid w-full grid-cols-2">
                    <TabsTrigger value="signin">Connexion</TabsTrigger>
                    <TabsTrigger value="signup">Inscription</TabsTrigger>
                  </TabsList>
                )}
                <TabsContent value="signin">
                  <form onSubmit={onSignIn} className="space-y-4">
                    <Field label="Adresse e-mail" name="email" type="email" autoComplete="email" />
                    <Field label="Mot de passe" name="password" type="password" autoComplete="current-password" />
                    <button type="button" className="text-sm font-medium text-primary hover:underline" onClick={() => setTab("forgot")}>Mot de passe oublié ?</button>
                    <Button type="submit" variant="brand" className="w-full" disabled={busy}>{busy && <Loader2 className="animate-spin" />}Se connecter</Button>
                  </form>
                </TabsContent>
                <TabsContent value="signup">
                  <form onSubmit={onSignUp} className="space-y-4">
                    <Field label="Nom complet" name="full_name" autoComplete="name" />
                    <Field label="Adresse e-mail" name="email" type="email" autoComplete="email" />
                    <Field label="Mot de passe (8 caractères, lettre et chiffre)" name="password" type="password" autoComplete="new-password" />
                    <Field label="Confirmer le mot de passe" name="confirm" type="password" autoComplete="new-password" />
                    <Button type="submit" variant="brand" className="w-full" disabled={busy}>{busy && <Loader2 className="animate-spin" />}Créer mon compte</Button>
                  </form>
                </TabsContent>
                <TabsContent value="forgot">
                  <form onSubmit={onForgot} className="mt-4 space-y-4">
                    <Field label="Adresse e-mail" name="email" type="email" autoComplete="email" />
                    <Button type="submit" variant="brand" className="w-full" disabled={busy}>{busy && <Loader2 className="animate-spin" />}Envoyer le lien</Button>
                    <Button type="button" variant="ghost" className="w-full" onClick={() => setTab("signin")}>Retour à la connexion</Button>
                  </form>
                </TabsContent>
              </Tabs>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}

function Field({ label, name, type = "text", autoComplete }: { label: string; name: string; type?: string; autoComplete?: string }) {
  return (
    <div className="space-y-1.5">
      <Label htmlFor={name}>{label}</Label>
      <Input id={name} name={name} type={type} autoComplete={autoComplete} required />
    </div>
  );
}

function GoogleIcon() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path fill="currentColor" d="M21.35 11.1h-9.17v2.98h5.3c-.23 1.4-1.66 4.1-5.3 4.1-3.19 0-5.8-2.64-5.8-5.9s2.61-5.9 5.8-5.9c1.82 0 3.04.78 3.73 1.44l2.55-2.45C16.84 3.87 14.7 3 12.18 3 7.09 3 3 7.06 3 12.18s4.09 9.18 9.18 9.18c5.3 0 8.8-3.72 8.8-8.97 0-.6-.07-1.06-.15-1.5z" />
    </svg>
  );
}
