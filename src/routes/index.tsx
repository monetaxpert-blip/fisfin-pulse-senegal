import { createFileRoute, Link } from "@tanstack/react-router";
import { BarChart3, FileSpreadsheet, ShieldCheck, Activity } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Logo } from "@/components/brand/Logo";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "FISFIN — Pilotage financier des PME sénégalaises" },
      { name: "description", content: "Importez vos balances SYSCOHADA, suivez vos indicateurs financiers et prenez des décisions éclairées avec FISFIN." },
      { property: "og:title", content: "FISFIN — Pilotage financier des PME sénégalaises" },
      { property: "og:description", content: "Importez vos balances SYSCOHADA, suivez vos indicateurs financiers et prenez des décisions éclairées." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Landing,
});

const features = [
  { icon: FileSpreadsheet, title: "Import de balances", text: "Excel et CSV, avec contrôle des anomalies avant tout calcul." },
  { icon: BarChart3, title: "Indicateurs SYSCOHADA", text: "Rentabilité, liquidité, solvabilité et structure financière." },
  { icon: Activity, title: "Diagnostics traçables", text: "Chaque alerte cite la règle appliquée et les données utilisées." },
  { icon: ShieldCheck, title: "Données isolées", text: "Chaque entreprise n'est visible que par les utilisateurs autorisés." },
];

function Landing() {
  return (
    <div className="min-h-screen bg-background">
      <header className="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
        <Logo className="w-28" />
        <Button asChild variant="outline">
          <Link to="/auth">Se connecter</Link>
        </Button>
      </header>
      <main className="mx-auto max-w-6xl px-6 pb-20 pt-10 md:pt-20">
        <div className="max-w-3xl">
          <p className="text-sm font-semibold uppercase tracking-widest text-primary">Votre gestion simplifiée</p>
          <h1 className="mt-4 text-4xl font-extrabold leading-tight text-navy md:text-6xl">
            Le pilotage financier de votre PME, à partir de vos données comptables.
          </h1>
          <p className="mt-6 max-w-2xl text-lg text-muted-foreground">
            FISFIN lit votre balance, contrôle sa cohérence et calcule vos indicateurs selon le référentiel SYSCOHADA — sans jamais
            inventer une donnée manquante.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Button asChild variant="brand" size="lg">
              <Link to="/auth" search={{ mode: "signup" }}>Créer un compte</Link>
            </Button>
            <Button asChild variant="outline" size="lg">
              <Link to="/auth">J'ai déjà un compte</Link>
            </Button>
          </div>
        </div>
        <div className="mt-20 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {features.map((f) => (
            <div key={f.title} className="rounded-2xl border bg-card p-6 shadow-card">
              <div className="flex h-11 w-11 items-center justify-center rounded-full bg-accent text-primary">
                <f.icon className="h-5 w-5" />
              </div>
              <h3 className="mt-4 font-bold text-navy">{f.title}</h3>
              <p className="mt-2 text-sm text-muted-foreground">{f.text}</p>
            </div>
          ))}
        </div>
      </main>
      <footer className="border-t py-6 text-center text-xs text-muted-foreground">
        © {new Date().getFullYear()} FISFIN. Les analyses produites ne constituent ni un audit ni une certification comptable.
      </footer>
    </div>
  );
}
