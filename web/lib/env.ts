function required(name: string, value: string | undefined): string {
  if (!value) throw new Error(`${name} is not set — copy web/.env.example to web/.env.local and fill it in`);
  return value;
}
export const env = {
  supabaseUrl: required("NEXT_PUBLIC_SUPABASE_URL", process.env.NEXT_PUBLIC_SUPABASE_URL),
  supabaseAnonKey: required("NEXT_PUBLIC_SUPABASE_ANON_KEY", process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY),
  siteUrl: process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000",
  devLogin: process.env.NEXT_PUBLIC_PADDLTIR_DEV_LOGIN === "1",
};
