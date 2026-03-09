/**
 * Determine if the current request is over HTTPS.
 * Checks the actual protocol via headers (X-Forwarded-Proto, etc.)
 * so that HTTP deployments behind no-TLS proxies (e.g. NAS / LAN)
 * don't accidentally set Secure cookies that the browser then refuses to send back.
 */
export function isRequestSecure(request: Request): boolean {
  const url = new URL(request.url);
  if (url.protocol === "https:") return true;

  // Behind a reverse proxy, check forwarded headers
  const forwarded = request.headers.get("x-forwarded-proto");
  if (forwarded?.includes("https")) return true;

  return false;
}
