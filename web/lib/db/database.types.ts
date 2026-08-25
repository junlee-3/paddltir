export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  public: {
    Tables: {
      availability: {
        Row: {
          note: string | null
          paddler_id: string
          session_id: string
          status: Database["public"]["Enums"]["availability_status"]
          updated_at: string
        }
        Insert: {
          note?: string | null
          paddler_id: string
          session_id: string
          status: Database["public"]["Enums"]["availability_status"]
          updated_at?: string
        }
        Update: {
          note?: string | null
          paddler_id?: string
          session_id?: string
          status?: Database["public"]["Enums"]["availability_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "availability_paddler_id_fkey"
            columns: ["paddler_id"]
            isOneToOne: false
            referencedRelation: "paddlers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "availability_paddler_id_fkey"
            columns: ["paddler_id"]
            isOneToOne: false
            referencedRelation: "paddlers_public"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "availability_paddler_id_fkey"
            columns: ["paddler_id"]
            isOneToOne: false
            referencedRelation: "paddlers_with_power"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "availability_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      category_rules: {
        Row: {
          boat_size: Database["public"]["Enums"]["boat_size"]
          category: Database["public"]["Enums"]["crew_category"]
          club_id: string
          max_men: number | null
          max_women: number | null
          min_men: number | null
          min_women: number | null
          updated_at: string
        }
        Insert: {
          boat_size: Database["public"]["Enums"]["boat_size"]
          category: Database["public"]["Enums"]["crew_category"]
          club_id: string
          max_men?: number | null
          max_women?: number | null
          min_men?: number | null
          min_women?: number | null
          updated_at?: string
        }
        Update: {
          boat_size?: Database["public"]["Enums"]["boat_size"]
          category?: Database["public"]["Enums"]["crew_category"]
          club_id?: string
          max_men?: number | null
          max_women?: number | null
          min_men?: number | null
          min_women?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "category_rules_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      clubs: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          invite_code: string
          name: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          invite_code?: string
          name: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          invite_code?: string
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      crew_members: {
        Row: {
          created_at: string
          crew_id: string
          paddler_id: string
        }
        Insert: {
          created_at?: string
          crew_id: string
          paddler_id: string
        }
        Update: {
          created_at?: string
          crew_id?: string
          paddler_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "crew_members_crew_id_fkey"
            columns: ["crew_id"]
            isOneToOne: false
            referencedRelation: "crews"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "crew_members_paddler_id_fkey"
            columns: ["paddler_id"]
            isOneToOne: false
            referencedRelation: "paddlers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "crew_members_paddler_id_fkey"
            columns: ["paddler_id"]
            isOneToOne: false
            referencedRelation: "paddlers_public"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "crew_members_paddler_id_fkey"
            columns: ["paddler_id"]
            isOneToOne: false
            referencedRelation: "paddlers_with_power"
            referencedColumns: ["id"]
          },
        ]
      }
      crews: {
        Row: {
          age_division: string
          category: Database["public"]["Enums"]["crew_category"]
          club_id: string
          created_at: string
          id: string
          name: string
          updated_at: string
        }
        Insert: {
          age_division: string
          category: Database["public"]["Enums"]["crew_category"]
          club_id: string
          created_at?: string
          id?: string
          name: string
          updated_at?: string
        }
        Update: {
          age_division?: string
          category?: Database["public"]["Enums"]["crew_category"]
          club_id?: string
          created_at?: string
          id?: string
          name?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "crews_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      erg_tests: {
        Row: {
          created_at: string
          id: string
          metres: number
          paddler_id: string
          recorded_by: string | null
          source: Database["public"]["Enums"]["erg_source"]
          tested_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          metres: number
          paddler_id: string
          recorded_by?: string | null
          source: Database["public"]["Enums"]["erg_source"]
          tested_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          metres?: number
          paddler_id?: string
          recorded_by?: string | null
          source?: Database["public"]["Enums"]["erg_source"]
          tested_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "erg_tests_paddler_id_fkey"
            columns: ["paddler_id"]
            isOneToOne: false
            referencedRelation: "paddlers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "erg_tests_paddler_id_fkey"
            columns: ["paddler_id"]
            isOneToOne: false
            referencedRelation: "paddlers_public"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "erg_tests_paddler_id_fkey"
            columns: ["paddler_id"]
            isOneToOne: false
            referencedRelation: "paddlers_with_power"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "erg_tests_recorded_by_fkey"
            columns: ["recorded_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      heat_reserves: {
        Row: {
          created_at: string
          heat_id: string
          paddler_id: string
        }
        Insert: {
          created_at?: string
          heat_id: string
          paddler_id: string
        }
        Update: {
          created_at?: string
          heat_id?: string
          paddler_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "heat_reserves_heat_id_fkey"
            columns: ["heat_id"]
            isOneToOne: false
            referencedRelation: "heats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "heat_reserves_paddler_id_fkey"
            columns: ["paddler_id"]
            isOneToOne: false
            referencedRelation: "paddlers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "heat_reserves_paddler_id_fkey"
            columns: ["paddler_id"]
            isOneToOne: false
            referencedRelation: "paddlers_public"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "heat_reserves_paddler_id_fkey"
            columns: ["paddler_id"]
            isOneToOne: false
            referencedRelation: "paddlers_with_power"
            referencedColumns: ["id"]
          },
        ]
      }
      heats: {
        Row: {
          created_at: string
          drummer_id: string | null
          id: string
          name: string
          race_id: string
          sort_order: number
          sweep_id: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          drummer_id?: string | null
          id?: string
          name: string
          race_id: string
          sort_order?: number
          sweep_id?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          drummer_id?: string | null
          id?: string
          name?: string
          race_id?: string
          sort_order?: number
          sweep_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "heats_drummer_id_fkey"
            columns: ["drummer_id"]
            isOneToOne: false
            referencedRelation: "paddlers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "heats_drummer_id_fkey"
            columns: ["drummer_id"]
            isOneToOne: false
            referencedRelation: "paddlers_public"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "heats_drummer_id_fkey"
            columns: ["drummer_id"]
            isOneToOne: false
            referencedRelation: "paddlers_with_power"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "heats_race_id_fkey"
            columns: ["race_id"]
            isOneToOne: false
            referencedRelation: "races"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "heats_sweep_id_fkey"
            columns: ["sweep_id"]
            isOneToOne: false
            referencedRelation: "paddlers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "heats_sweep_id_fkey"
            columns: ["sweep_id"]
            isOneToOne: false
            referencedRelation: "paddlers_public"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "heats_sweep_id_fkey"
            columns: ["sweep_id"]
            isOneToOne: false
            referencedRelation: "paddlers_with_power"
            referencedColumns: ["id"]
          },
        ]
      }
      optimize_cache: {
        Row: {
          club_id: string | null
          created_at: string
          input_hash: string
          result: Json
        }
        Insert: {
          club_id?: string | null
          created_at?: string
          input_hash: string
          result: Json
        }
        Update: {
          club_id?: string | null
          created_at?: string
          input_hash?: string
          result?: Json
        }
        Relationships: [
          {
            foreignKeyName: "optimize_cache_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      paddlers: {
        Row: {
          archived_at: string | null
          boat_role: Database["public"]["Enums"]["boat_role"]
          club_id: string
          created_at: string
          email: string | null
          gender: Database["public"]["Enums"]["gender"]
          id: string
          name: string
          preferred_side: Database["public"]["Enums"]["side_pref"]
          profile_id: string | null
          seat_preference: Database["public"]["Enums"]["seat_pref"]
          updated_at: string
          weight_kg: number
        }
        Insert: {
          archived_at?: string | null
          boat_role?: Database["public"]["Enums"]["boat_role"]
          club_id: string
          created_at?: string
          email?: string | null
          gender: Database["public"]["Enums"]["gender"]
          id?: string
          name: string
          preferred_side?: Database["public"]["Enums"]["side_pref"]
          profile_id?: string | null
          seat_preference?: Database["public"]["Enums"]["seat_pref"]
          updated_at?: string
          weight_kg: number
        }
        Update: {
          archived_at?: string | null
          boat_role?: Database["public"]["Enums"]["boat_role"]
          club_id?: string
          created_at?: string
          email?: string | null
          gender?: Database["public"]["Enums"]["gender"]
          id?: string
          name?: string
          preferred_side?: Database["public"]["Enums"]["side_pref"]
          profile_id?: string | null
          seat_preference?: Database["public"]["Enums"]["seat_pref"]
          updated_at?: string
          weight_kg?: number
        }
        Relationships: [
          {
            foreignKeyName: "paddlers_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "paddlers_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          club_id: string | null
          created_at: string
          display_name: string | null
          id: string
          role: Database["public"]["Enums"]["user_role"] | null
          updated_at: string
        }
        Insert: {
          avatar_url?: string | null
          club_id?: string | null
          created_at?: string
          display_name?: string | null
          id: string
          role?: Database["public"]["Enums"]["user_role"] | null
          updated_at?: string
        }
        Update: {
          avatar_url?: string | null
          club_id?: string | null
          created_at?: string
          display_name?: string | null
          id?: string
          role?: Database["public"]["Enums"]["user_role"] | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "profiles_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      races: {
        Row: {
          boat_size: Database["public"]["Enums"]["boat_size"]
          created_at: string
          crew_id: string
          distance_m: number | null
          id: string
          name: string
          session_id: string
          sort_order: number
          updated_at: string
        }
        Insert: {
          boat_size?: Database["public"]["Enums"]["boat_size"]
          created_at?: string
          crew_id: string
          distance_m?: number | null
          id?: string
          name: string
          session_id: string
          sort_order?: number
          updated_at?: string
        }
        Update: {
          boat_size?: Database["public"]["Enums"]["boat_size"]
          created_at?: string
          crew_id?: string
          distance_m?: number | null
          id?: string
          name?: string
          session_id?: string
          sort_order?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "races_crew_id_fkey"
            columns: ["crew_id"]
            isOneToOne: false
            referencedRelation: "crews"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "races_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      seats: {
        Row: {
          bench: number
          heat_id: string
          locked: boolean
          paddler_id: string
          side: Database["public"]["Enums"]["boat_side"]
          updated_at: string
        }
        Insert: {
          bench: number
          heat_id: string
          locked?: boolean
          paddler_id: string
          side: Database["public"]["Enums"]["boat_side"]
          updated_at?: string
        }
        Update: {
          bench?: number
          heat_id?: string
          locked?: boolean
          paddler_id?: string
          side?: Database["public"]["Enums"]["boat_side"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "seats_heat_id_fkey"
            columns: ["heat_id"]
            isOneToOne: false
            referencedRelation: "heats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seats_paddler_id_fkey"
            columns: ["paddler_id"]
            isOneToOne: false
            referencedRelation: "paddlers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seats_paddler_id_fkey"
            columns: ["paddler_id"]
            isOneToOne: false
            referencedRelation: "paddlers_public"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seats_paddler_id_fkey"
            columns: ["paddler_id"]
            isOneToOne: false
            referencedRelation: "paddlers_with_power"
            referencedColumns: ["id"]
          },
        ]
      }
      sessions: {
        Row: {
          club_id: string
          created_at: string
          id: string
          kind: Database["public"]["Enums"]["session_kind"]
          notes: string | null
          starts_at: string
          title: string
          updated_at: string
          venue: string | null
        }
        Insert: {
          club_id: string
          created_at?: string
          id?: string
          kind: Database["public"]["Enums"]["session_kind"]
          notes?: string | null
          starts_at: string
          title: string
          updated_at?: string
          venue?: string | null
        }
        Update: {
          club_id?: string
          created_at?: string
          id?: string
          kind?: Database["public"]["Enums"]["session_kind"]
          notes?: string | null
          starts_at?: string
          title?: string
          updated_at?: string
          venue?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "sessions_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      paddlers_public: {
        Row: {
          archived_at: string | null
          boat_role: Database["public"]["Enums"]["boat_role"] | null
          club_id: string | null
          id: string | null
          name: string | null
          preferred_side: Database["public"]["Enums"]["side_pref"] | null
          profile_id: string | null
        }
        Insert: {
          archived_at?: string | null
          boat_role?: Database["public"]["Enums"]["boat_role"] | null
          club_id?: string | null
          id?: string | null
          name?: string | null
          preferred_side?: Database["public"]["Enums"]["side_pref"] | null
          profile_id?: string | null
        }
        Update: {
          archived_at?: string | null
          boat_role?: Database["public"]["Enums"]["boat_role"] | null
          club_id?: string | null
          id?: string | null
          name?: string | null
          preferred_side?: Database["public"]["Enums"]["side_pref"] | null
          profile_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "paddlers_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "paddlers_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      paddlers_with_power: {
        Row: {
          archived_at: string | null
          boat_role: Database["public"]["Enums"]["boat_role"] | null
          club_id: string | null
          created_at: string | null
          email: string | null
          erg_m: number | null
          erg_tested_at: string | null
          gender: Database["public"]["Enums"]["gender"] | null
          id: string | null
          name: string | null
          preferred_side: Database["public"]["Enums"]["side_pref"] | null
          profile_id: string | null
          seat_preference: Database["public"]["Enums"]["seat_pref"] | null
          updated_at: string | null
          weight_kg: number | null
        }
        Relationships: [
          {
            foreignKeyName: "paddlers_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "paddlers_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      auth_club_id: { Args: never; Returns: string }
      claimable_paddlers: {
        Args: { p_code: string }
        Returns: {
          id: string
          name: string
        }[]
      }
      create_club: {
        Args: { p_name: string }
        Returns: {
          created_at: string
          created_by: string | null
          id: string
          invite_code: string
          name: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "clubs"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      crew_club: { Args: { p_crew: string }; Returns: string }
      gen_invite_code: { Args: never; Returns: string }
      heat_club: { Args: { p_heat: string }; Returns: string }
      is_coach: { Args: never; Returns: boolean }
      join_club: {
        Args: { p_code: string; p_paddler_id?: string }
        Returns: string
      }
      link_paddler_by_email: {
        Args: { p_email: string; p_user: string }
        Returns: undefined
      }
      my_paddler_id: { Args: never; Returns: string }
      paddler_club: { Args: { p_paddler: string }; Returns: string }
      race_club: { Args: { p_race: string }; Returns: string }
      regenerate_invite_code: { Args: never; Returns: string }
      session_club: { Args: { p_session: string }; Returns: string }
      session_headcount: {
        Args: { p_session_id: string }
        Returns: {
          n: number
          status: Database["public"]["Enums"]["availability_status"]
        }[]
      }
    }
    Enums: {
      availability_status: "in" | "out" | "maybe"
      boat_role: "paddler" | "drummer" | "sweep"
      boat_side: "left" | "right"
      boat_size: "small" | "standard"
      crew_category: "open" | "women" | "mixed"
      erg_source: "coach" | "self"
      gender: "female" | "male"
      seat_pref: "stroke" | "pace" | "engine" | "sprint" | "none"
      session_kind: "training" | "race_day"
      side_pref: "left" | "right" | "either"
      user_role: "head_coach" | "coach" | "paddler"
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
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
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
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
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
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
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
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
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
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      availability_status: ["in", "out", "maybe"],
      boat_role: ["paddler", "drummer", "sweep"],
      boat_side: ["left", "right"],
      boat_size: ["small", "standard"],
      crew_category: ["open", "women", "mixed"],
      erg_source: ["coach", "self"],
      gender: ["female", "male"],
      seat_pref: ["stroke", "pace", "engine", "sprint", "none"],
      session_kind: ["training", "race_day"],
      side_pref: ["left", "right", "either"],
      user_role: ["head_coach", "coach", "paddler"],
    },
  },
} as const

