import { createFileRoute, Link } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { Area, AreaChart, ResponsiveContainer, XAxis, YAxis, Tooltip, Pie, PieChart, Cell } from "recharts";
import {
  ArrowRight, ArrowDown, FileSpreadsheet, CheckCircle2, AlertTriangle, ShieldCheck, Menu, X, Database, BarChart3, Droplet, Scale, ListChecks, Compass, Lock,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Logo } from "@/components/brand/Logo";
import { Reveal, useInView } from "@/components/landing/Reveal";
import dashboard from "@/assets/fisfin-dashboard-demo.png.asset.json";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "FISFIN | Prenez le contrôle de votre performance financière" },
      { name: "description", content: "FISFIN transforme vos données comptables SYSCOHADA en indicateurs clairs pour piloter la santé financière de votre PME." },
      { property: "og:title", content: "FISFIN | Prenez le contrôle de votre performance financière" },
      { property: "og:description", content: "Vos données comptables transformées en indicateurs clairs, pour les PME sénégalaises." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Landing,
});

const links = [
  { href: "#decouvrir", label: "Découvrir FISFIN" },
  { href: "#fonctionnalites", label: "Fonctionnalités" },
  { href: "#approche", label: "Notre approche" },
];

function Nav() {
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);
  useEffect(() => {
    const on = () => setScrolled(window.scrollY > 24);
    on();
    window.addEventListener("scroll", on, { passive: true });
    return () => window.removeEventListener("scroll", on);
  }, []);
  useEffect(() => {
    if (!open) return;
    const k = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    window.addEventListener("keydown", k);
    return () => window.removeEventListener("keydown", k);
  }, [open]);

  return (
    <header className={cn("fixed inset-x-0 top-0 z-50 transition-[background-color,box-shadow,border-color] duration-300", scrolled || open ? "border-b bg-card/95 shadow-card backdrop-blur" : "border-b border-transparent bg-transparent")}>
      <div className="mx-auto grid h-[72px] max-w-7xl grid-cols-[auto_1fr_auto] items-center gap-4 px-5 md:px-8">
        <LogoLink imgClassName="h-11" className="py-0.5" />
        <nav className="hidden items-center justify-center gap-1 lg:flex" aria-label="Navigation principale">
          {links.map((l) => (
            <a key={l.href} href={l.href} className={cn("inline-flex h-10 items-center rounded-lg px-4 text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring", scrolled ? "text-navy hover:bg-accent hover:text-primary" : "text-sidebar-foreground/90 hover:bg-sidebar-accent hover:text-sidebar-foreground")}>
              {l.label}
            </a>
          ))}
        </nav>
        <div className="hidden items-center justify-end gap-2 lg:flex">
          <Button asChild variant={scrolled ? "outline" : "nav"} className="h-10 px-4"><Link to="/auth">Se connecter</Link></Button>
          <Button asChild variant="brand" className="h-10 px-5"><Link to="/auth" search={{ mode: "signup" }}>Créer un compte</Link></Button>
        </div>
        <button
          type="button"
          className={cn("col-start-3 flex h-11 w-11 items-center justify-center justify-self-end rounded-lg transition-colors lg:hidden focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring", scrolled || open ? "text-navy hover:bg-accent" : "text-sidebar-foreground hover:bg-sidebar-accent")}
          aria-expanded={open}
          aria-controls="mobile-menu"
          aria-label={open ? "Fermer le menu" : "Ouvrir le menu"}
          onClick={() => setOpen((o) => !o)}
        >
          {open ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
        </button>
      </div>
      <div id="mobile-menu" inert={!open} className={cn("grid overflow-hidden transition-[grid-template-rows] duration-300 lg:hidden", open ? "grid-rows-[1fr]" : "grid-rows-[0fr]")}>
        <div className="min-h-0">
          <nav className="flex flex-col gap-1 px-5 pb-5 pt-1" aria-label="Navigation mobile">
            {links.map((l) => (
              <a key={l.href} href={l.href} onClick={() => setOpen(false)} className="flex min-h-12 items-center rounded-lg px-3 text-base font-medium text-navy hover:bg-accent">{l.label}</a>
            ))}
            <div className="mt-3 grid grid-cols-1 gap-2 min-[380px]:grid-cols-2">
              <Button asChild variant="outline" className="h-11"><Link to="/auth">Se connecter</Link></Button>
              <Button asChild variant="brand" className="h-11"><Link to="/auth" search={{ mode: "signup" }}>Créer un compte</Link></Button>
            </div>
          </nav>
        </div>
      </div>
    </header>
  );
}

function Hero() {
  return (
    <section id="top" className="relative overflow-hidden bg-hero pt-32 text-sidebar-foreground md:pt-40">
      <div className="pointer-events-none absolute inset-0 bg-grid-faint [mask-image:linear-gradient(180deg,black,transparent_75%)]" />
      <div className="relative mx-auto max-w-7xl px-5 md:px-8">
        <div className="mx-auto flex max-w-3xl flex-col items-center text-center">
          <p className="animate-rise inline-flex max-w-full items-center gap-2 rounded-full border border-sidebar-border bg-sidebar-accent/60 px-4 py-1.5 text-[11px] font-semibold uppercase tracking-[0.14em] text-sidebar-muted sm:text-xs">
            <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-success" />
            <span>Pilotage financier et échéances fiscales des PME</span>
          </p>
          <h1 className="animate-rise mt-6 max-w-[20ch] text-[2.125rem] font-extrabold leading-[1.1] [animation-delay:80ms] sm:text-5xl lg:text-[3.5rem]">
            Prenez le contrôle de votre performance financière.
          </h1>
          <p className="animate-rise mt-6 max-w-[62ch] text-base leading-relaxed text-sidebar-muted [animation-delay:160ms] md:text-lg">
            FISFIN est une plateforme de pilotage financier et de suivi des échéances fiscales des PME. Elle transforme vos données comptables en indicateurs clairs pour mieux comprendre, suivre et piloter la santé financière de votre entreprise.
          </p>
          <div className="animate-rise mt-9 flex w-full flex-col items-stretch justify-center gap-3 [animation-delay:240ms] sm:w-auto sm:flex-row sm:items-center">
            <Button asChild variant="brand" size="xl"><a href="#decouvrir">Découvrir FISFIN<ArrowRight /></a></Button>
            <Button asChild variant="nav" size="xl"><a href="#approche">Comment ça fonctionne</a></Button>
          </div>
        </div>
        <div id="decouvrir" className="animate-rise relative mx-auto mt-14 max-w-6xl scroll-mt-24 [animation-delay:360ms] md:mt-20">
          <div className="absolute inset-x-6 -top-8 bottom-0 rounded-[3rem] bg-royal/30 blur-3xl" aria-hidden />
          <figure className="relative rounded-t-2xl border border-b-0 border-sidebar-border bg-card p-1.5 pb-0 shadow-elevated md:rounded-t-3xl md:p-2.5 md:pb-0">
            <div className="flex items-center gap-1.5 px-2 py-2 md:px-3">
              <span className="h-2.5 w-2.5 shrink-0 rounded-full bg-border" /><span className="h-2.5 w-2.5 shrink-0 rounded-full bg-border" /><span className="h-2.5 w-2.5 shrink-0 rounded-full bg-border" />
              <span className="ml-2 min-w-0 flex-1 truncate text-xs text-muted-foreground">Tableau de bord FISFIN</span>
              <span className="shrink-0 rounded-full bg-warning px-2.5 py-0.5 text-[10px] font-semibold text-warning-foreground sm:text-[11px]">Données de démonstration</span>
            </div>
            <img src={dashboard.url} alt="Aperçu du tableau de bord FISFIN avec des données de démonstration" className="block h-auto w-full rounded-t-xl" width={1536} height={1024} />
          </figure>
        </div>
      </div>
    </section>
  );
}

function Caveat() {
  return (
    <div className="border-b bg-card">
      <p className="mx-auto max-w-3xl px-5 py-5 text-center text-xs leading-relaxed text-muted-foreground md:text-sm">
        Aperçu illustratif : les montants et les échéances affichés sont fictifs. Le module de suivi des échéances fiscales est en cours de préparation.
      </p>
    </div>
  );
}

function StepLabel({ n, label }: { n: string; label: string }) {
  return (
    <p className="flex items-center gap-3 text-sm font-semibold uppercase tracking-widest text-primary">
      <span className="flex h-8 w-8 items-center justify-center rounded-full bg-accent font-display text-sm">{n}</span>{label}
    </p>
  );
}

/* A — Comprendre */
function Understand() {
  const rows = [
    ["521100", "Banque", "12 450 000", ""],
    ["411000", "Clients", "6 820 000", ""],
    ["401000", "Fournisseurs", "", "4 310 000"],
    ["701000", "Ventes de marchandises", "", "21 900 000"],
  ];
  return (
    <section id="fonctionnalites" className="scroll-mt-24 bg-background py-24 md:py-32">
      <div className="mx-auto grid max-w-7xl items-center gap-14 px-5 md:px-8 lg:grid-cols-[1fr_1.1fr]">
        <Reveal>
          <StepLabel n="1" label="Comprendre" />
          <h2 className="mt-5 text-3xl font-extrabold text-navy md:text-4xl">Votre balance contient déjà les réponses. Encore faut-il les lire.</h2>
          <p className="mt-5 text-lg text-muted-foreground">
            Des centaines de comptes, des soldes débiteurs et créditeurs : la comptabilité décrit l'entreprise, mais rarement de façon directement exploitable pour piloter. FISFIN part de ces données, sans les réécrire.
          </p>
          <ul className="mt-8 space-y-3">
            {["Import Excel et CSV avec association des colonnes", "Contrôle des anomalies avant tout calcul", "Aucune valeur corrigée silencieusement"].map((t) => (
              <li key={t} className="flex items-start gap-3 text-navy"><CheckCircle2 className="mt-0.5 h-5 w-5 shrink-0 text-success" />{t}</li>
            ))}
          </ul>
        </Reveal>
        <Reveal delay={120}>
          <div className="relative">
            <div className="rounded-2xl border bg-card shadow-elevated">
              <div className="flex items-center justify-between gap-3 border-b px-5 py-4">
                <span className="flex min-w-0 items-center gap-2 font-semibold text-navy"><FileSpreadsheet className="h-5 w-5 shrink-0 text-primary" /><span className="truncate">balance_exemple.xlsx</span></span>
                <span className="shrink-0 rounded-full bg-muted px-2.5 py-0.5 text-[11px] font-medium text-muted-foreground">Exemple</span>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full min-w-[420px] text-sm">
                  <thead><tr className="text-left text-xs uppercase tracking-wide text-muted-foreground"><th className="px-5 py-3 font-medium">Compte</th><th className="py-3 font-medium">Libellé</th><th className="py-3 text-right font-medium">Solde D</th><th className="px-5 py-3 text-right font-medium">Solde C</th></tr></thead>
                  <tbody className="tabular">
                    {rows.map((r) => (
                      <tr key={r[0]} className="border-t transition-colors hover:bg-accent/50">
                        <td className="px-5 py-3 font-semibold text-primary">{r[0]}</td><td className="py-3 text-navy">{r[1]}</td><td className="py-3 text-right">{r[2]}</td><td className="px-5 py-3 text-right">{r[3]}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
            <div className="absolute -bottom-6 right-4 flex items-center gap-2 rounded-xl border bg-card px-4 py-3 text-sm shadow-elevated md:-right-6">
              <AlertTriangle className="h-4 w-4 text-warning" /><span className="text-navy">2 avertissements à examiner</span>
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}

/* B — Analyser */
const perf = [
  { m: "T1", ca: 4.2, rn: 0.6 }, { m: "T2", ca: 5.1, rn: 0.8 }, { m: "T3", ca: 5.6, rn: 0.7 }, { m: "T4", ca: 6.9, rn: 1.1 },
];
function Analyze() {
  const { ref, visible } = useInView<HTMLDivElement>(0.3);
  const families = [
    { icon: BarChart3, t: "Rentabilité", d: "Marges, EBE, valeur ajoutée, rentabilité des capitaux." },
    { icon: Droplet, t: "Liquidité", d: "Ratios de liquidité générale, réduite et immédiate." },
    { icon: ShieldCheck, t: "Solvabilité", d: "Autonomie financière, endettement, capacité de remboursement." },
    { icon: Scale, t: "Équilibre financier", d: "FRNG, BFR, trésorerie nette." },
  ];
  return (
    <section className="relative overflow-hidden bg-sidebar-gradient py-24 text-sidebar-foreground md:py-32">
      <div className="pointer-events-none absolute inset-0 bg-grid-faint opacity-60" />
      <div className="relative mx-auto max-w-7xl px-5 md:px-8">
        <Reveal className="max-w-2xl">
          <p className="flex items-center gap-3 text-sm font-semibold uppercase tracking-widest text-sidebar-muted"><span className="flex h-8 w-8 items-center justify-center rounded-full bg-sidebar-accent font-display text-sidebar-foreground">2</span>Analyser</p>
          <h2 className="mt-5 text-3xl font-extrabold md:text-4xl">Des indicateurs calculés, ou honnêtement signalés comme non calculables.</h2>
          <p className="mt-5 text-lg text-sidebar-muted">Chaque indicateur s'appuie sur les comptes réellement importés. Si une donnée manque, FISFIN l'indique au lieu d'afficher un zéro trompeur.</p>
        </Reveal>
        <div className="mt-14 grid gap-6 lg:grid-cols-[1.3fr_1fr]">
          <Reveal>
            <div ref={ref} className="h-full rounded-2xl bg-card p-6 text-card-foreground shadow-elevated">
              <div className="flex items-center justify-between gap-3">
                <h3 className="font-bold text-navy">Évolution de la performance</h3>
                <span className="rounded-full bg-muted px-2.5 py-0.5 text-[11px] text-muted-foreground">Démonstration</span>
              </div>
              <div className="mt-3 flex gap-5 text-xs text-muted-foreground">
                <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded-full bg-chart-1" />Chiffre d'affaires</span>
                <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded-full bg-chart-2" />Résultat net</span>
              </div>
              <div className="mt-4 h-60">
                {visible && (
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={perf} margin={{ left: -20, right: 8, top: 8 }}>
                      <defs>
                        <linearGradient id="gca" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="var(--chart-1)" stopOpacity={0.25} /><stop offset="100%" stopColor="var(--chart-1)" stopOpacity={0} /></linearGradient>
                      </defs>
                      <XAxis dataKey="m" tickLine={false} axisLine={false} tick={{ fill: "var(--muted-foreground)", fontSize: 12 }} />
                      <YAxis tickLine={false} axisLine={false} tick={{ fill: "var(--muted-foreground)", fontSize: 12 }} unit=" M" />
                      <Tooltip contentStyle={{ borderRadius: 12, border: "1px solid var(--border)" }} formatter={(v: number) => `${v} M FCFA`} />
                      <Area type="monotone" dataKey="ca" name="Chiffre d'affaires" stroke="var(--chart-1)" strokeWidth={2.5} fill="url(#gca)" animationDuration={1200} dot={{ r: 3, fill: "var(--chart-1)" }} />
                      <Area type="monotone" dataKey="rn" name="Résultat net" stroke="var(--chart-2)" strokeWidth={2} fill="transparent" animationDuration={1400} dot={{ r: 3, fill: "var(--chart-2)" }} />
                    </AreaChart>
                  </ResponsiveContainer>
                )}
              </div>
            </div>
          </Reveal>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-1">
            {families.map((f, i) => (
              <Reveal key={f.t} delay={i * 80}>
                <div className="group flex items-start gap-4 rounded-2xl border border-sidebar-border bg-sidebar-accent/50 p-5 transition-colors hover:bg-sidebar-accent">
                  <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-sidebar-primary text-sidebar-primary-foreground transition-transform group-hover:scale-105"><f.icon className="h-5 w-5" /></span>
                  <div><p className="font-semibold">{f.t}</p><p className="mt-0.5 text-sm text-sidebar-muted">{f.d}</p></div>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
        <Reveal className="mt-8">
          <p className="text-sm text-sidebar-muted">Le calcul des indicateurs sera activé après validation du référentiel financier FISFIN. Certains indicateurs nécessitent plusieurs exercices ou des données de flux.</p>
        </Reveal>
      </div>
    </section>
  );
}

/* C — Interpréter */
function Interpret() {
  const statuses = [
    { c: "bg-success", l: "Calculé" },
    { c: "bg-muted-foreground", l: "Non calculable : données manquantes" },
    { c: "bg-warning", l: "À vérifier" },
    { c: "bg-destructive", l: "Bloqué par une anomalie" },
  ];
  return (
    <section className="bg-background py-24 md:py-32">
      <div className="mx-auto grid max-w-7xl items-center gap-14 px-5 md:px-8 lg:grid-cols-[1.1fr_1fr]">
        <Reveal className="order-2 lg:order-1">
          <div className="rounded-2xl border bg-card p-6 shadow-elevated">
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Exemple de diagnostic</p>
                <h3 className="mt-1 font-bold text-navy">Tension sur la trésorerie nette</h3>
              </div>
              <span className="shrink-0 rounded-full bg-warning/15 px-3 py-1 text-xs font-semibold text-navy">Attention</span>
            </div>
            <dl className="mt-5 grid gap-x-6 gap-y-4 text-sm sm:grid-cols-2">
              <div><dt className="text-muted-foreground">Règle appliquée</dt><dd className="mt-0.5 font-medium text-navy">Trésorerie nette = FRNG − BFR</dd></div>
              <div><dt className="text-muted-foreground">Données utilisées</dt><dd className="mt-0.5 font-medium text-navy">Classes 1 à 5 de la balance</dd></div>
              <div><dt className="text-muted-foreground">Période</dt><dd className="mt-0.5 font-medium text-navy">Exercice sélectionné</dd></div>
              <div><dt className="text-muted-foreground">Limites</dt><dd className="mt-0.5 font-medium text-navy">Balance de clôture seule</dd></div>
            </dl>
            <p className="mt-5 rounded-xl bg-muted p-4 text-sm text-muted-foreground">Une alerte de gestion n'est pas une conclusion d'audit. Elle invite à examiner un point précis.</p>
          </div>
        </Reveal>
        <Reveal className="order-1 lg:order-2" delay={100}>
          <StepLabel n="3" label="Interpréter" />
          <h2 className="mt-5 text-3xl font-extrabold text-navy md:text-4xl">Des diagnostics traçables, jamais des verdicts.</h2>
          <p className="mt-5 text-lg text-muted-foreground">Chaque alerte indique la règle appliquée, les données mobilisées, la période concernée et les limites de l'analyse. Vous savez toujours d'où vient un résultat.</p>
          <ul className="mt-8 grid gap-3 sm:grid-cols-2">
            {statuses.map((s) => (
              <li key={s.l} className="flex items-center gap-3 rounded-xl border bg-card px-4 py-3 text-sm text-navy"><span className={cn("h-2.5 w-2.5 shrink-0 rounded-full", s.c)} />{s.l}</li>
            ))}
          </ul>
        </Reveal>
      </div>
    </section>
  );
}

/* D — Décider */
const assets = [
  { name: "Immobilisations", v: 42 }, { name: "Stocks", v: 28 }, { name: "Créances", v: 18 }, { name: "Trésorerie", v: 12 },
];
const pieColors = ["var(--chart-3)", "var(--chart-1)", "var(--chart-2)", "var(--chart-4)"];
function Decide() {
  const { ref, visible } = useInView<HTMLDivElement>(0.3);
  return (
    <section className="bg-card py-24 md:py-32">
      <div className="mx-auto max-w-7xl px-5 md:px-8">
        <div className="grid items-center gap-14 lg:grid-cols-2">
          <Reveal>
            <StepLabel n="4" label="Décider" />
            <h2 className="mt-5 text-3xl font-extrabold text-navy md:text-4xl">Une vision claire pour éclairer vos décisions — qui restent les vôtres.</h2>
            <p className="mt-5 text-lg text-muted-foreground">Comparez vos exercices, identifiez les postes qui pèsent sur votre performance et préparez vos échanges avec votre expert-comptable ou votre banquier sur une base structurée.</p>
            <div className="mt-8 flex flex-wrap gap-3">
              {[{ i: Compass, t: "Comparaisons N / N-1 / N-2" }, { i: ListChecks, t: "Recommandations reliées aux indicateurs" }, { i: Database, t: "Rapports Excel et PDF" }].map((x) => (
                <span key={x.t} className="inline-flex items-center gap-2 rounded-full border bg-background px-4 py-2 text-sm text-navy"><x.i className="h-4 w-4 text-primary" />{x.t}</span>
              ))}
            </div>
          </Reveal>
          <Reveal delay={120}>
            <div ref={ref} className="rounded-2xl border bg-soft-gradient p-6 shadow-card">
              <div className="flex items-center justify-between gap-3">
                <h3 className="font-bold text-navy">Répartition de l'actif</h3>
                <span className="rounded-full bg-muted px-2.5 py-0.5 text-[11px] text-muted-foreground">Démonstration</span>
              </div>
              <div className="mt-4 grid items-center gap-6 sm:grid-cols-[180px_1fr]">
                <div className="relative mx-auto h-44 w-44">
                  {visible && (
                    <ResponsiveContainer width="100%" height="100%">
                      <PieChart>
                        <Pie data={assets} dataKey="v" innerRadius={52} outerRadius={80} paddingAngle={2} stroke="none" animationDuration={1100}>
                          {assets.map((a, i) => <Cell key={a.name} fill={pieColors[i]} />)}
                        </Pie>
                      </PieChart>
                    </ResponsiveContainer>
                  )}
                  <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center"><span className="font-display text-lg font-bold text-navy">100 %</span><span className="text-[11px] text-muted-foreground">de l'actif</span></div>
                </div>
                <ul className="space-y-3 text-sm">
                  {assets.map((a, i) => (
                    <li key={a.name} className="flex items-center justify-between gap-3"><span className="flex items-center gap-2 text-navy"><span className="h-2.5 w-2.5 rounded-full" style={{ background: pieColors[i] }} />{a.name}</span><span className="tabular font-semibold text-navy">{a.v} %</span></li>
                  ))}
                </ul>
              </div>
            </div>
          </Reveal>
        </div>
      </div>
    </section>
  );
}

/* Notre approche */
function Approach() {
  const steps = [
    { t: "Créez votre entreprise", d: "Raison sociale, forme juridique, secteur et exercice comptable.", live: true },
    { t: "Importez votre balance", d: "Fichier Excel ou CSV, contrôlé ligne par ligne.", live: false },
    { t: "Consultez vos indicateurs", d: "Tableaux de bord, diagnostics et rapports exportables.", live: false },
  ];
  const principles = [
    { i: Lock, t: "Données isolées", d: "Chaque entreprise n'est accessible qu'aux utilisateurs autorisés, contrôle appliqué côté serveur." },
    { i: ShieldCheck, t: "Aucun chiffre inventé", d: "Pas de valeur affichée sans donnée réelle derrière." },
    { i: ListChecks, t: "Référentiel SYSCOHADA", d: "Formules et seuils issus d'un référentiel documenté et traçable." },
  ];
  return (
    <section id="approche" className="scroll-mt-24 bg-background py-24 md:py-32">
      <div className="mx-auto max-w-7xl px-5 md:px-8">
        <Reveal className="mx-auto max-w-2xl text-center">
          <p className="text-sm font-semibold uppercase tracking-widest text-primary">Notre approche</p>
          <h2 className="mt-4 text-3xl font-extrabold text-navy md:text-4xl">Comment fonctionne FISFIN</h2>
          <p className="mt-4 text-lg text-muted-foreground">Un parcours simple, construit par étapes, et une exigence constante de fiabilité.</p>
        </Reveal>
        <ol className="relative mt-16 grid gap-6 md:grid-cols-3">
          <div className="absolute left-0 right-0 top-6 hidden h-px bg-border md:block" aria-hidden />
          {steps.map((s, i) => (
            <Reveal key={s.t} delay={i * 120}>
              <li className="relative">
                <span className={cn("relative z-10 flex h-12 w-12 items-center justify-center rounded-full font-display text-lg font-bold shadow-card", s.live ? "bg-brand-gradient text-primary-foreground" : "border bg-card text-navy")}>{i + 1}</span>
                <h3 className="mt-5 text-lg font-bold text-navy">{s.t}</h3>
                <p className="mt-2 text-muted-foreground">{s.d}</p>
                <span className={cn("mt-3 inline-block rounded-full px-2.5 py-0.5 text-xs font-medium", s.live ? "bg-success/15 text-navy" : "bg-secondary text-secondary-foreground")}>{s.live ? "Disponible" : "Bientôt disponible"}</span>
              </li>
            </Reveal>
          ))}
        </ol>
        <div className="mt-20 grid gap-px overflow-hidden rounded-2xl border bg-border md:grid-cols-3">
          {principles.map((p, i) => (
            <Reveal key={p.t} delay={i * 80} className="h-full">
              <div className="h-full bg-card p-7">
                <p.i className="h-6 w-6 text-primary" />
                <h3 className="mt-4 font-bold text-navy">{p.t}</h3>
                <p className="mt-2 text-sm text-muted-foreground">{p.d}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

function FinalCta() {
  return (
    <section className="px-5 pb-24 md:px-8">
      <Reveal>
        <div className="relative mx-auto max-w-6xl overflow-hidden rounded-3xl bg-hero px-6 py-16 text-center text-sidebar-foreground shadow-elevated md:px-16">
          <div className="pointer-events-none absolute inset-0 bg-grid-faint opacity-60" />
          <div className="relative">
            <h2 className="text-3xl font-extrabold md:text-4xl">Commencez à structurer votre pilotage financier.</h2>
            <p className="mx-auto mt-4 max-w-xl text-sidebar-muted">Créez votre compte et votre entreprise dès aujourd'hui. Les modules d'import et d'analyse arrivent progressivement.</p>
            <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row">
              <Button asChild variant="brand" size="xl"><Link to="/auth" search={{ mode: "signup" }}>Créer un compte<ArrowRight /></Link></Button>
              <Button asChild variant="nav" size="xl"><Link to="/auth">Se connecter</Link></Button>
            </div>
          </div>
        </div>
      </Reveal>
    </section>
  );
}

function Landing() {
  return (
    <div className="min-h-screen overflow-x-hidden bg-background">
      <Nav />
      <main>
        <Hero />
        <Caveat />
        <div className="flex justify-center bg-background pt-10"><a href="#fonctionnalites" aria-label="Continuer" className="flex h-10 w-10 items-center justify-center rounded-full border bg-card text-primary shadow-card transition-transform hover:translate-y-0.5"><ArrowDown className="h-4 w-4" /></a></div>
        <Understand />
        <Analyze />
        <Interpret />
        <Decide />
        <Approach />
        <FinalCta />
      </main>
      <footer className="border-t bg-card">
        <div className="mx-auto flex max-w-7xl flex-col items-center justify-between gap-4 px-5 py-8 text-center md:flex-row md:px-8 md:text-left">
          <Logo className="w-20" />
          <p className="text-xs text-muted-foreground">© {new Date().getFullYear()} FISFIN. Les analyses produites ne constituent ni un audit ni une certification comptable.</p>
        </div>
      </footer>
    </div>
  );
}
