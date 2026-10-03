declare namespace Cloudflare {
  interface Env {
    ANTHROPIC_API_KEY?: string;
    ANTHROPIC_MODEL?: string;
    ANTHROPIC_WORKSPACE_ID?: string;
    DB?: D1Database;
    BUCKET?: R2Bucket;
  }
}
