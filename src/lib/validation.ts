import { z } from "zod";

/** Business validation rules shared by forms and tests. */

export const LEGAL_FORMS = ["SARL", "SARLU", "SA", "SAS", "SASU", "SNC", "SCS", "GIE", "Entreprise individuelle", "Autre"] as const;

export const SECTORS = [
  "Commerce",
  "Industrie",
  "Services",
  "BTP",
  "Agriculture et agro-industrie",
  "Transport et logistique",
  "Technologies et numérique",
  "Hôtellerie et restauration",
  "Santé",
  "Éducation",
  "Autre",
] as const;

const optionalText = (max: number) =>
  z
    .string()
    .trim()
    .max(max, { message: `${max} caractères maximum` })
    .optional()
    .transform((v) => (v ? v : null));

export const companySchema = z.object({
  name: z.string().trim().min(1, { message: "La raison sociale est obligatoire" }).max(200, { message: "200 caractères maximum" }),
  legal_form: z.string().trim().min(1, { message: "La forme juridique est obligatoire" }).max(50),
  sector: z.string().trim().min(1, { message: "Le secteur d'activité est obligatoire" }).max(100),
  tax_id: optionalText(50),
  address: optionalText(300),
  currency: z.string().trim().length(3, { message: "Code devise sur 3 lettres (ex. XOF)" }).toUpperCase(),
  activity_start_date: z
    .string()
    .optional()
    .transform((v) => (v ? v : null))
    .refine((v) => v === null || !Number.isNaN(Date.parse(v)), { message: "Date invalide" }),
  fiscal_year_start_month: z.coerce.number().int().min(1).max(12),
});
export type CompanyInput = z.input<typeof companySchema>;
export type CompanyValues = z.output<typeof companySchema>;

export const fiscalYearSchema = z
  .object({
    label: z.string().trim().min(1, { message: "Le libellé est obligatoire" }).max(50),
    start_date: z.string().min(1, { message: "Date de début obligatoire" }),
    end_date: z.string().min(1, { message: "Date de fin obligatoire" }),
    status: z.enum(["ouvert", "cloture"]),
  })
  .refine((v) => v.end_date > v.start_date, {
    message: "La date de fin doit être postérieure à la date de début",
    path: ["end_date"],
  })
  .refine((v) => monthsBetween(v.start_date, v.end_date) <= 24, {
    message: "Un exercice ne peut pas dépasser 24 mois",
    path: ["end_date"],
  });
export type FiscalYearValues = z.infer<typeof fiscalYearSchema>;

export function monthsBetween(start: string, end: string): number {
  const s = new Date(start);
  const e = new Date(end);
  return (e.getFullYear() - s.getFullYear()) * 12 + (e.getMonth() - s.getMonth()) + 1;
}

/** Overlap check mirrored server-side by a database trigger. */
export function rangesOverlap(aStart: string, aEnd: string, bStart: string, bEnd: string): boolean {
  return aStart <= bEnd && bStart <= aEnd;
}

/** Default 12-month fiscal year starting at the given month of a year. */
export function defaultFiscalYear(year: number, startMonth: number) {
  const start = new Date(Date.UTC(year, startMonth - 1, 1));
  const end = new Date(Date.UTC(year, startMonth - 1 + 12, 0));
  const iso = (d: Date) => d.toISOString().slice(0, 10);
  const label = startMonth === 1 ? `${year}` : `${year}-${year + 1}`;
  return { label, start_date: iso(start), end_date: iso(end) };
}

export const passwordSchema = z
  .string()
  .min(8, { message: "8 caractères minimum" })
  .max(72)
  .regex(/[A-Za-z]/, { message: "Au moins une lettre" })
  .regex(/[0-9]/, { message: "Au moins un chiffre" });

/** Only same-origin relative paths are allowed as post-login redirects. */
export function safeRedirect(value: unknown, fallback = "/tableau-de-bord"): string {
  if (typeof value !== "string") return fallback;
  if (!value.startsWith("/") || value.startsWith("//") || value.startsWith("/\\")) return fallback;
  return value;
}

type FiscalYearState = { status: string; first_closed_at?: string | null };

/**
 * Mirrors the database delete guard on fiscal years (trigger fiscal_years_no_delete).
 * The database stays the authority; this only drives the interface.
 */
export function fiscalYearDeletion(fy: FiscalYearState, hasAccountingData = false, companyArchived = false): { allowed: boolean; reason: string | null } {
  if (fy.status === "cloture") return { allowed: false, reason: "Un exercice clôturé ne peut pas être supprimé." };
  if (fy.first_closed_at) return { allowed: false, reason: "Cet exercice a déjà été clôturé : il reste conservé même après réouverture." };
  if (companyArchived) return { allowed: false, reason: "Entreprise archivée : restaurez-la d'abord." };
  if (hasAccountingData) return { allowed: false, reason: "Cet exercice contient des imports ou des données comptables et ne peut pas être supprimé." };
  return { allowed: true, reason: null };
}

/** Mirrors the database lifecycle guard: a closed fiscal year must be reopened (with a reason) before editing. */
export function fiscalYearEditable(fy: FiscalYearState): { allowed: boolean; reason: string | null } {
  if (fy.status === "cloture") return { allowed: false, reason: "Un exercice clôturé ne peut pas être modifié. Rouvrez-le d'abord avec un motif." };
  return { allowed: true, reason: null };
}

/** Reason required to reopen a closed fiscal year (stored and traced in the history). */
export const reopenReasonSchema = z
  .string()
  .trim()
  .min(10, { message: "Indiquez un motif d'au moins 10 caractères" })
  .max(500, { message: "500 caractères maximum" });

/** Translates database error codes into French user messages. */
export function dbErrorMessage(error: { message: string; code?: string }): string {
  switch (error.code) {
    case "23P01": return "Cet exercice chevauche un exercice existant.";
    case "23505": return "Un exercice porte déjà ce libellé.";
    case "23503": return "Cet élément est lié à d'autres données et ne peut pas être supprimé.";
    case "23514": return "Une valeur saisie ne respecte pas les règles attendues.";
    case "42501": return "Vous n'avez pas les droits nécessaires pour cette opération.";
    case "FS001": return "La suppression définitive d'une entreprise est interdite. Utilisez l'archivage.";
    case "FS002": return "Un exercice clôturé ne peut pas être supprimé.";
    case "FS003": return "Cet exercice contient des imports ou des données comptables et ne peut pas être supprimé.";
    case "FS004": return "Entreprise active invalide : accès non autorisé ou entreprise archivée.";
    case "FS005": return error.message;
    case "FS006": return "Cet exercice a déjà été clôturé : il reste conservé même après réouverture.";
    case "FS007": return "Entreprise archivée : restaurez-la avant de créer, modifier ou supprimer quoi que ce soit.";
    case "FS008": return "Un exercice clôturé ne peut pas être modifié. Rouvrez-le d'abord avec un motif.";
    case "FS009": return "La réouverture d'un exercice clôturé exige un motif d'au moins 10 caractères.";
    default: return error.message;
  }
}
