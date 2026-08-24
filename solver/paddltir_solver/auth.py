import httpx

class AuthError(Exception):
    pass

def verify_user(token: str, supabase_url: str, anon_key: str, client: httpx.Client | None = None) -> str:
    """Ask GoTrue who this JWT belongs to. Avoids JWT-secret/JWKS handling entirely; one ~50 ms call per request."""
    c = client or httpx.Client(timeout=5.0)
    r = c.get(f"{supabase_url.rstrip('/')}/auth/v1/user", headers={"apikey": anon_key, "Authorization": f"Bearer {token}"})
    if r.status_code != 200:
        raise AuthError(f"auth failed ({r.status_code})")
    uid = r.json().get("id")
    if not uid:
        raise AuthError("no user id in auth response")
    return uid
