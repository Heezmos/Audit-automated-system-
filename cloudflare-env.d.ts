declare namespace Cloudflare {
  interface Env {
    AUDIT_SCANNER_URL?:string;
    AUDIT_SCANNER_TOKEN?:string;
    ANTHROPIC_API_KEY?: string;
    ANTHROPIC_MODEL?: string;
    ANTHROPIC_WORKSPACE_ID?: string;
    DB?: D1Database;
    BUCKET?: R2Bucket;
  }
}
