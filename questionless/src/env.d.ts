/// <reference types="@cloudflare/workers-types" />

// Cloudflare Pages environment bindings - extends the interface from @cloudflare/next-on-pages
declare global {
  interface CloudflareEnv {
    DB: D1Database;
  }

  namespace NodeJS {
    interface ProcessEnv {
      // Cloudflare D1 binding is accessed via context, not process.env
    }
  }
}

export {};
