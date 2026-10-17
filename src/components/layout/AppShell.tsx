import { Link, Outlet, useNavigate, useRouterState } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import type { User } from "@supabase/supabase-js";
import {
  LayoutDashboard, Building2, CalendarRange, FileSpreadsheet, LineChart, FileText, UserRound, LogOut, Menu, ChevronDown, CalendarDays,
} from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { WorkspaceProvider, useWorkspace } from "@/lib/workspace";
import { Logo } from "@/components/brand/Logo";
import { Sheet, SheetContent, SheetTitle } from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { formatDate, initials } from "@/lib/format";
import { cn } from "@/lib/utils";
import { toast } from "sonner";

const nav = [
  { to: "/tableau-de-bord", label: "Tableau de bord", icon: LayoutDashboard },
  { to: "/entreprises", label: "Mes entreprises", icon: Building2 },
  { to: "/exercices", label: "Exercices comptables", icon: CalendarRange },
  { to: "/profil", label: "Profil et paramètres", icon: UserRound },
] as const;

const upcoming = [
  { label: "Données comptables", icon: FileSpreadsheet },
  { label: "Analyse financière", icon: LineChart },
  { label: "Rapports", icon: FileText },
];

export function AppShell({ user }: { user: User }) {
  return (
    <WorkspaceProvider user={user}>
      <ShellInner />
    </WorkspaceProvider>
  );
}

function SidebarContentBlock({ onNavigate }: { onNavigate?: () => void }) {
  const path = useRouterState({ select: (s) => s.location.pathname });
  return (
    <div className="flex h-full flex-col bg-sidebar-gradient text-sidebar-foreground">
      <div className="p-5">
        <div className="rounded-xl bg-card px-4 py-3"><Logo className="mx-auto w-32" /></div>
      </div>
      <nav className="flex-1 space-y-1 px-3">
        {nav.map((item) => {
          const active = path === item.to || path.startsWith(item.to + "/");
          return (
            <Link
              key={item.to}
              to={item.to}
              onClick={onNavigate}
              className={cn(
                "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                active ? "bg-sidebar-primary text-sidebar-primary-foreground shadow-card" : "text-sidebar-foreground/85 hover:bg-sidebar-accent",
              )}
            >
              <item.icon className="h-5 w-5" />
              {item.label}
            </Link>
          );
        })}
        <div className="my-4 border-t border-sidebar-border" />
        <p className="px-3 pb-1 text-[11px] font-semibold uppercase tracking-wider text-sidebar-muted">Prochaines phases</p>
        {upcoming.map((u) => (
          <div key={u.label} aria-disabled title="Disponible dans une prochaine phase" className="flex cursor-not-allowed items-center gap-3 rounded-lg px-3 py-2.5 text-sm text-sidebar-muted/80">
            <u.icon className="h-5 w-5" />
            <span className="flex-1">{u.label}</span>
            <span className="rounded-full bg-sidebar-accent px-2 py-0.5 text-[10px]">Bientôt</span>
          </div>
        ))}
      </nav>
      <div className="p-6">
        <p className="font-display text-lg italic leading-snug text-sidebar-foreground/90">Des décisions éclairées<br />pour un avenir solide</p>
        <div className="mt-3 h-0.5 w-10 bg-sidebar-primary" />
      </div>
    </div>
  );
}

function ShellInner() {
  const [open, setOpen] = useState(false);
  const ws = useWorkspace();
  const qc = useQueryClient();
  const navigate = useNavigate();
  const name = ws.profile?.full_name || ws.user.email || "";

  async function signOut() {
    await qc.cancelQueries();
    qc.clear();
    await supabase.auth.signOut();
    navigate({ to: "/auth", replace: true });
  }

  return (
    <div className="flex min-h-screen w-full">
      <aside className="sticky top-0 hidden h-screen w-64 shrink-0 lg:block"><SidebarContentBlock /></aside>
      <Sheet open={open} onOpenChange={setOpen}>
        <SheetContent side="left" className="w-72 border-0 p-0">
          <SheetTitle className="sr-only">Navigation</SheetTitle>
          <SidebarContentBlock onNavigate={() => setOpen(false)} />
        </SheetContent>
      </Sheet>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-20 flex h-16 items-center gap-3 border-b bg-card/95 px-4 backdrop-blur md:px-8">
          <Button variant="ghost" size="icon" className="lg:hidden" onClick={() => setOpen(true)} aria-label="Ouvrir le menu"><Menu /></Button>

          <div className="flex min-w-0 flex-1 items-center gap-2">
            {ws.activeCompanies.length > 0 && (
              <Select
                value={ws.activeCompany?.id}
                onValueChange={(id) => ws.setActiveCompany(id).catch((e) => toast.error(e.message))}
              >
                <SelectTrigger className="h-9 w-full max-w-[220px] bg-card" aria-label="Entreprise active">
                  <Building2 className="h-4 w-4 text-muted-foreground" />
                  <SelectValue placeholder="Entreprise" />
                </SelectTrigger>
                <SelectContent>
                  {ws.activeCompanies.map((c) => <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>)}
                </SelectContent>
              </Select>
            )}
            {ws.fiscalYears.length > 0 && (
              <Select value={ws.activeFiscalYear?.id} onValueChange={ws.setActiveFiscalYearId}>
                <SelectTrigger className="hidden h-9 w-[170px] bg-card sm:flex" aria-label="Période">
                  <CalendarDays className="h-4 w-4 text-muted-foreground" />
                  <SelectValue placeholder="Exercice" />
                </SelectTrigger>
                <SelectContent>
                  {ws.fiscalYears.map((f) => <SelectItem key={f.id} value={f.id}>Exercice {f.label}</SelectItem>)}
                </SelectContent>
              </Select>
            )}
          </div>

          <span className="hidden text-sm text-muted-foreground xl:inline">{formatDate(new Date())}</span>

          <DropdownMenu>
            <DropdownMenuTrigger className="flex items-center gap-2 rounded-full p-1 pr-2 hover:bg-muted">
              <span className="flex h-9 w-9 items-center justify-center rounded-full bg-navy text-sm font-semibold text-primary-foreground">{initials(name)}</span>
              <span className="hidden text-left md:block">
                <span className="block max-w-[160px] truncate text-sm font-semibold">{name}</span>
                <span className="block text-xs text-muted-foreground">{ws.profile?.job_title || "Utilisateur"}</span>
              </span>
              <ChevronDown className="h-4 w-4 text-muted-foreground" />
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-56">
              <DropdownMenuLabel className="truncate">{ws.user.email}</DropdownMenuLabel>
              <DropdownMenuSeparator />
              <DropdownMenuItem asChild><Link to="/profil"><UserRound />Profil et paramètres</Link></DropdownMenuItem>
              <DropdownMenuItem asChild><Link to="/entreprises"><Building2 />Mes entreprises</Link></DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem onClick={signOut} className="text-destructive focus:text-destructive"><LogOut />Se déconnecter</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </header>
        <main className="flex-1 p-4 md:p-8">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
