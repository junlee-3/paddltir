/** A swallowed PostgREST/RLS error must never be read as "no rows" — throw it instead. */
export function assertNoQueryError(label: string, error: { message: string } | null): void {
  if (error) throw new Error(`viewer: ${label} query failed: ${error.message}`);
}
