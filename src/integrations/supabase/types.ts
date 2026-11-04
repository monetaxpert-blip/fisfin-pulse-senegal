export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      activity_log: {
        Row: {
          action: string
          company_id: string | null
          created_at: string
          details: Json
          entity: string
          entity_id: string | null
          id: string
          user_id: string
        }
        Insert: {
          action: string
          company_id?: string | null
          created_at?: string
          details?: Json
          entity: string
          entity_id?: string | null
          id?: string
          user_id: string
        }
        Update: {
          action?: string
          company_id?: string | null
          created_at?: string
          details?: Json
          entity?: string
          entity_id?: string | null
          id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "activity_log_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      balance_import_issues: {
        Row: {
          acknowledged_at: string | null
          acknowledged_by: string | null
          acknowledgement_note: string | null
          code: string
          company_id: string
          created_at: string
          details: Json
          id: string
          import_id: string
          message: string
          severity: string
          source_row: number | null
        }
        Insert: {
          acknowledged_at?: string | null
          acknowledged_by?: string | null
          acknowledgement_note?: string | null
          code: string
          company_id: string
          created_at?: string
          details?: Json
          id?: string
          import_id: string
          message: string
          severity: string
          source_row?: number | null
        }
        Update: {
          acknowledged_at?: string | null
          acknowledged_by?: string | null
          acknowledgement_note?: string | null
          code?: string
          company_id?: string
          created_at?: string
          details?: Json
          id?: string
          import_id?: string
          message?: string
          severity?: string
          source_row?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "balance_import_issues_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "balance_import_issues_import_id_fkey"
            columns: ["import_id"]
            isOneToOne: false
            referencedRelation: "balance_imports"
            referencedColumns: ["id"]
          },
        ]
      }
      balance_imports: {
        Row: {
          abandoned_at: string | null
          amount_basis: string
          analysed_at: string | null
          archive_reason: string | null
          archived_at: string | null
          archived_by: string | null
          balance_type: string
          column_mapping: Json
          company_id: string
          content_sha256: string | null
          created_at: string
          created_by: string
          currency: string
          excluded_rows: Json
          file_name: string
          file_path: string | null
          file_sha256: string | null
          file_size: number | null
          fiscal_year_id: string
          header_row: number | null
          id: string
          is_reference: boolean
          parser_version: string | null
          period_end: string
          period_start: string
          replacement_reason: string | null
          sheet_name: string | null
          status: string
          summary: Json
          supersedes_import_id: string | null
          updated_at: string
          validated_at: string | null
          validated_by: string | null
          version: number
        }
        Insert: {
          abandoned_at?: string | null
          amount_basis: string
          analysed_at?: string | null
          archive_reason?: string | null
          archived_at?: string | null
          archived_by?: string | null
          balance_type: string
          column_mapping?: Json
          company_id: string
          content_sha256?: string | null
          created_at?: string
          created_by?: string
          currency?: string
          excluded_rows?: Json
          file_name: string
          file_path?: string | null
          file_sha256?: string | null
          file_size?: number | null
          fiscal_year_id: string
          header_row?: number | null
          id?: string
          is_reference?: boolean
          parser_version?: string | null
          period_end: string
          period_start: string
          replacement_reason?: string | null
          sheet_name?: string | null
          status?: string
          summary?: Json
          supersedes_import_id?: string | null
          updated_at?: string
          validated_at?: string | null
          validated_by?: string | null
          version?: number
        }
        Update: {
          abandoned_at?: string | null
          amount_basis?: string
          analysed_at?: string | null
          archive_reason?: string | null
          archived_at?: string | null
          archived_by?: string | null
          balance_type?: string
          column_mapping?: Json
          company_id?: string
          content_sha256?: string | null
          created_at?: string
          created_by?: string
          currency?: string
          excluded_rows?: Json
          file_name?: string
          file_path?: string | null
          file_sha256?: string | null
          file_size?: number | null
          fiscal_year_id?: string
          header_row?: number | null
          id?: string
          is_reference?: boolean
          parser_version?: string | null
          period_end?: string
          period_start?: string
          replacement_reason?: string | null
          sheet_name?: string | null
          status?: string
          summary?: Json
          supersedes_import_id?: string | null
          updated_at?: string
          validated_at?: string | null
          validated_by?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "balance_imports_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "balance_imports_fiscal_year_id_fkey"
            columns: ["fiscal_year_id"]
            isOneToOne: false
            referencedRelation: "fiscal_years"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "balance_imports_supersedes_import_id_fkey"
            columns: ["supersedes_import_id"]
            isOneToOne: true
            referencedRelation: "balance_imports"
            referencedColumns: ["id"]
          },
        ]
      }
      balance_lines: {
        Row: {
          account_label: string | null
          account_number: string | null
          account_number_raw: string | null
          closing_credit: number | null
          closing_debit: number | null
          company_id: string
          exclusion_reason: string | null
          id: number
          import_id: string
          included: boolean
          opening_credit: number | null
          opening_debit: number | null
          period_credit: number | null
          period_debit: number | null
          raw: Json
          source_row: number
        }
        Insert: {
          account_label?: string | null
          account_number?: string | null
          account_number_raw?: string | null
          closing_credit?: number | null
          closing_debit?: number | null
          company_id: string
          exclusion_reason?: string | null
          id?: never
          import_id: string
          included?: boolean
          opening_credit?: number | null
          opening_debit?: number | null
          period_credit?: number | null
          period_debit?: number | null
          raw?: Json
          source_row: number
        }
        Update: {
          account_label?: string | null
          account_number?: string | null
          account_number_raw?: string | null
          closing_credit?: number | null
          closing_debit?: number | null
          company_id?: string
          exclusion_reason?: string | null
          id?: never
          import_id?: string
          included?: boolean
          opening_credit?: number | null
          opening_debit?: number | null
          period_credit?: number | null
          period_debit?: number | null
          raw?: Json
          source_row?: number
        }
        Relationships: [
          {
            foreignKeyName: "balance_lines_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "balance_lines_import_id_fkey"
            columns: ["import_id"]
            isOneToOne: false
            referencedRelation: "balance_imports"
            referencedColumns: ["id"]
          },
        ]
      }
      companies: {
        Row: {
          activity_start_date: string | null
          address: string | null
          archived_at: string | null
          created_at: string
          currency: string
          fiscal_year_start_month: number
          id: string
          legal_form: string
          name: string
          owner_id: string
          sector: string
          tax_id: string | null
          updated_at: string
        }
        Insert: {
          activity_start_date?: string | null
          address?: string | null
          archived_at?: string | null
          created_at?: string
          currency?: string
          fiscal_year_start_month?: number
          id?: string
          legal_form: string
          name: string
          owner_id?: string
          sector: string
          tax_id?: string | null
          updated_at?: string
        }
        Update: {
          activity_start_date?: string | null
          address?: string | null
          archived_at?: string | null
          created_at?: string
          currency?: string
          fiscal_year_start_month?: number
          id?: string
          legal_form?: string
          name?: string
          owner_id?: string
          sector?: string
          tax_id?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      fiscal_years: {
        Row: {
          closed_at: string | null
          company_id: string
          created_at: string
          created_by: string
          end_date: string
          first_closed_at: string | null
          id: string
          label: string
          reopen_reason: string | null
          reopened_at: string | null
          reopened_by: string | null
          start_date: string
          status: string
          updated_at: string
        }
        Insert: {
          closed_at?: string | null
          company_id: string
          created_at?: string
          created_by?: string
          end_date: string
          first_closed_at?: string | null
          id?: string
          label: string
          reopen_reason?: string | null
          reopened_at?: string | null
          reopened_by?: string | null
          start_date: string
          status?: string
          updated_at?: string
        }
        Update: {
          closed_at?: string | null
          company_id?: string
          created_at?: string
          created_by?: string
          end_date?: string
          first_closed_at?: string | null
          id?: string
          label?: string
          reopen_reason?: string | null
          reopened_at?: string | null
          reopened_by?: string | null
          start_date?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fiscal_years_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          active_company_id: string | null
          created_at: string
          full_name: string | null
          id: string
          job_title: string | null
          phone: string | null
          updated_at: string
        }
        Insert: {
          active_company_id?: string | null
          created_at?: string
          full_name?: string | null
          id: string
          job_title?: string | null
          phone?: string | null
          updated_at?: string
        }
        Update: {
          active_company_id?: string | null
          created_at?: string
          full_name?: string | null
          id?: string
          job_title?: string | null
          phone?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "profiles_active_company_id_fkey"
            columns: ["active_company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      abandon_balance_import: {
        Args: { _import_id: string }
        Returns: {
          abandoned_at: string | null
          amount_basis: string
          analysed_at: string | null
          archive_reason: string | null
          archived_at: string | null
          archived_by: string | null
          balance_type: string
          column_mapping: Json
          company_id: string
          content_sha256: string | null
          created_at: string
          created_by: string
          currency: string
          excluded_rows: Json
          file_name: string
          file_path: string | null
          file_sha256: string | null
          file_size: number | null
          fiscal_year_id: string
          header_row: number | null
          id: string
          is_reference: boolean
          parser_version: string | null
          period_end: string
          period_start: string
          replacement_reason: string | null
          sheet_name: string | null
          status: string
          summary: Json
          supersedes_import_id: string | null
          updated_at: string
          validated_at: string | null
          validated_by: string | null
          version: number
        }
        SetofOptions: {
          from: "*"
          to: "balance_imports"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      acknowledge_balance_issue: {
        Args: { _issue_id: string; _note?: string }
        Returns: {
          acknowledged_at: string | null
          acknowledged_by: string | null
          acknowledgement_note: string | null
          code: string
          company_id: string
          created_at: string
          details: Json
          id: string
          import_id: string
          message: string
          severity: string
          source_row: number | null
        }
        SetofOptions: {
          from: "*"
          to: "balance_import_issues"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      archive_balance_import: {
        Args: { _import_id: string; _reason: string }
        Returns: {
          abandoned_at: string | null
          amount_basis: string
          analysed_at: string | null
          archive_reason: string | null
          archived_at: string | null
          archived_by: string | null
          balance_type: string
          column_mapping: Json
          company_id: string
          content_sha256: string | null
          created_at: string
          created_by: string
          currency: string
          excluded_rows: Json
          file_name: string
          file_path: string | null
          file_sha256: string | null
          file_size: number | null
          fiscal_year_id: string
          header_row: number | null
          id: string
          is_reference: boolean
          parser_version: string | null
          period_end: string
          period_start: string
          replacement_reason: string | null
          sheet_name: string | null
          status: string
          summary: Json
          supersedes_import_id: string | null
          updated_at: string
          validated_at: string | null
          validated_by: string | null
          version: number
        }
        SetofOptions: {
          from: "*"
          to: "balance_imports"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      can_access_company: { Args: { _company_id: string }; Returns: boolean }
      is_company_owner: { Args: { _company_id: string }; Returns: boolean }
      set_reference_balance_import: {
        Args: { _import_id: string }
        Returns: {
          abandoned_at: string | null
          amount_basis: string
          analysed_at: string | null
          archive_reason: string | null
          archived_at: string | null
          archived_by: string | null
          balance_type: string
          column_mapping: Json
          company_id: string
          content_sha256: string | null
          created_at: string
          created_by: string
          currency: string
          excluded_rows: Json
          file_name: string
          file_path: string | null
          file_sha256: string | null
          file_size: number | null
          fiscal_year_id: string
          header_row: number | null
          id: string
          is_reference: boolean
          parser_version: string | null
          period_end: string
          period_start: string
          replacement_reason: string | null
          sheet_name: string | null
          status: string
          summary: Json
          supersedes_import_id: string | null
          updated_at: string
          validated_at: string | null
          validated_by: string | null
          version: number
        }
        SetofOptions: {
          from: "*"
          to: "balance_imports"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      validate_balance_import: {
        Args: {
          _import_id: string
          _make_reference?: boolean
          _reason?: string
          _replace?: boolean
        }
        Returns: {
          abandoned_at: string | null
          amount_basis: string
          analysed_at: string | null
          archive_reason: string | null
          archived_at: string | null
          archived_by: string | null
          balance_type: string
          column_mapping: Json
          company_id: string
          content_sha256: string | null
          created_at: string
          created_by: string
          currency: string
          excluded_rows: Json
          file_name: string
          file_path: string | null
          file_sha256: string | null
          file_size: number | null
          fiscal_year_id: string
          header_row: number | null
          id: string
          is_reference: boolean
          parser_version: string | null
          period_end: string
          period_start: string
          replacement_reason: string | null
          sheet_name: string | null
          status: string
          summary: Json
          supersedes_import_id: string | null
          updated_at: string
          validated_at: string | null
          validated_by: string | null
          version: number
        }
        SetofOptions: {
          from: "*"
          to: "balance_imports"
          isOneToOne: true
          isSetofReturn: false
        }
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
