const dateFmt = new Intl.DateTimeFormat("fr-FR", { day: "numeric", month: "long", year: "numeric" });
const dateTimeFmt = new Intl.DateTimeFormat("fr-FR", { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" });

export const formatDate = (v: string | Date | null | undefined) => (v ? dateFmt.format(new Date(v)) : "Non renseignée");
export const formatDateTime = (v: string | Date | null | undefined) => (v ? dateTimeFmt.format(new Date(v)) : "Non renseignée");

export const MONTHS_FR = ["Janvier", "Février", "Mars", "Avril", "Mai", "Juin", "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"];

export function initials(name: string | null | undefined, fallback = "?") {
  if (!name) return fallback;
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map((p) => p[0]!.toUpperCase()).join("") || fallback;
}
