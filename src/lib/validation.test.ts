import { describe, expect, it } from "vitest";
import { companySchema, dbErrorMessage, defaultFiscalYear, fiscalYearDeletion, fiscalYearEditable, fiscalYearSchema, passwordSchema, rangesOverlap, reopenReasonSchema, safeRedirect } from "./validation";

describe("entreprise", () => {
  it("exige la raison sociale", () => {
    const r = companySchema.safeParse({ name: " ", legal_form: "SARL", sector: "Commerce", currency: "XOF", fiscal_year_start_month: 1 });
    expect(r.success).toBe(false);
  });
  it("accepte NINEA et adresse facultatifs et normalise en null", () => {
    const r = companySchema.parse({ name: "AKS", legal_form: "SARL", sector: "Commerce", currency: "xof", tax_id: "", address: "", fiscal_year_start_month: 1 });
    expect(r.tax_id).toBeNull();
    expect(r.address).toBeNull();
    expect(r.currency).toBe("XOF");
  });
});

describe("exercice comptable", () => {
  it("refuse une date de fin antérieure au début", () => {
    expect(fiscalYearSchema.safeParse({ label: "2025", start_date: "2025-12-31", end_date: "2025-01-01", status: "ouvert" }).success).toBe(false);
  });
  it("refuse un exercice de plus de 24 mois", () => {
    expect(fiscalYearSchema.safeParse({ label: "X", start_date: "2024-01-01", end_date: "2026-01-31", status: "ouvert" }).success).toBe(false);
  });
  it("accepte un exercice civil de 12 mois", () => {
    expect(fiscalYearSchema.safeParse({ label: "2025", start_date: "2025-01-01", end_date: "2025-12-31", status: "ouvert" }).success).toBe(true);
  });
  it("calcule l'exercice par défaut (janvier → 31 décembre)", () => {
    expect(defaultFiscalYear(2025, 1)).toEqual({ label: "2025", start_date: "2025-01-01", end_date: "2025-12-31" });
    expect(defaultFiscalYear(2025, 7)).toEqual({ label: "2025-2026", start_date: "2025-07-01", end_date: "2026-06-30" });
  });
  it("détecte le chevauchement de deux exercices", () => {
    expect(rangesOverlap("2025-01-01", "2025-12-31", "2025-12-31", "2026-12-31")).toBe(true);
    expect(rangesOverlap("2025-01-01", "2025-12-31", "2026-01-01", "2026-12-31")).toBe(false);
  });
});

describe("suppression d'exercice", () => {
  it("refuse la suppression d'un exercice clôturé", () => {
    expect(fiscalYearDeletion({ status: "cloture" }).allowed).toBe(false);
  });
  it("refuse la suppression d'un exercice rouvert après une clôture", () => {
    expect(fiscalYearDeletion({ status: "ouvert", first_closed_at: "2026-01-15T10:00:00Z" }).allowed).toBe(false);
  });
  it("refuse la suppression d'un exercice d'une entreprise archivée", () => {
    expect(fiscalYearDeletion({ status: "ouvert" }, false, true).allowed).toBe(false);
  });
  it("refuse la suppression d'un exercice contenant des données comptables", () => {
    expect(fiscalYearDeletion({ status: "ouvert" }, true).allowed).toBe(false);
  });
  it("autorise la suppression d'un exercice ouvert jamais clôturé et sans données", () => {
    expect(fiscalYearDeletion({ status: "ouvert", first_closed_at: null }, false)).toEqual({ allowed: true, reason: null });
  });
});

describe("clôture et réouverture d'exercice", () => {
  it("un exercice clôturé n'est pas modifiable", () => {
    expect(fiscalYearEditable({ status: "cloture" }).allowed).toBe(false);
    expect(fiscalYearEditable({ status: "ouvert" }).allowed).toBe(true);
  });
  it("la réouverture exige un motif d'au moins 10 caractères", () => {
    expect(reopenReasonSchema.safeParse("   court  ").success).toBe(false);
    expect(reopenReasonSchema.safeParse("Correction d'une écriture de clôture").success).toBe(true);
  });
  it("le motif de réouverture est limité à 500 caractères", () => {
    expect(reopenReasonSchema.safeParse("x".repeat(501)).success).toBe(false);
  });
});

describe("erreurs de la base", () => {
  it("traduit le refus de suppression d'entreprise", () => {
    expect(dbErrorMessage({ code: "FS001", message: "x" })).toContain("archivage");
  });
  it("traduit le refus d'une entreprise active non autorisée", () => {
    expect(dbErrorMessage({ code: "FS004", message: "x" })).toContain("Entreprise active invalide");
  });
  it("traduit les refus liés à la clôture et à l'archivage", () => {
    expect(dbErrorMessage({ code: "FS006", message: "x" })).toContain("déjà été clôturé");
    expect(dbErrorMessage({ code: "FS007", message: "x" })).toContain("Entreprise archivée");
    expect(dbErrorMessage({ code: "FS008", message: "x" })).toContain("ne peut pas être modifié");
    expect(dbErrorMessage({ code: "FS009", message: "x" })).toContain("motif");
  });
});

describe("sécurité", () => {
  it("mot de passe : 8 caractères, lettre et chiffre", () => {
    expect(passwordSchema.safeParse("abcdefgh").success).toBe(false);
    expect(passwordSchema.safeParse("abcd1234").success).toBe(true);
  });
  it("refuse les redirections externes après connexion", () => {
    expect(safeRedirect("https://evil.com")).toBe("/tableau-de-bord");
    expect(safeRedirect("//evil.com")).toBe("/tableau-de-bord");
    expect(safeRedirect("/entreprises")).toBe("/entreprises");
  });
});
