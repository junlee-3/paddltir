import type { Database } from "./database.types";

export type Tables = Database["public"]["Tables"];
export type Row<T extends keyof Tables> = Tables[T]["Row"];
export type Enums = Database["public"]["Enums"];
export type PaddlerPublic = Database["public"]["Views"]["paddlers_public"]["Row"];
