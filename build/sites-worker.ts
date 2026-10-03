import {limitRequest,securityEvent} from '../lib/defence';
import handler from "vinext/server/fetch-handler";
import { runWithConnectorBinding } from "../lib/connector-context";
import type { ConnectorBinding } from "../lib/connector-contract.mjs";

import { secureAPIRequest, secureResponse, securityCSP } from "../lib/security";

export default {
  async fetch(request: Request, env: Cloudflare.Env, ctx: ExecutionContext<{ CONNECTORS?: ConnectorBinding }>) {
    const guarded = await secureAPIRequest(request);
    if (guarded instanceof Response){try{await securityEvent(request,'Request guard rejection',guarded.status)}catch{}return secureResponse(guarded,request);}
    if(new URL(request.url).pathname.startsWith('/api/')){try{const limited=await limitRequest(request);if(limited){await securityEvent(request,'Request rate exceeded',429);return secureResponse(limited,request)}}catch{return secureResponse(Response.json({error:'Security controls are unavailable. Please retry.'},{status:503}),request);}}
    request = guarded;
    const nonce = import.meta.env.DEV ? undefined : crypto.randomUUID().replaceAll('-','');
    const trustedHeaders = new Headers(request.headers);
    // Overwrite incoming CSP so a caller cannot choose the script nonce.
    trustedHeaders.set('Content-Security-Policy',securityCSP(nonce,import.meta.env.DEV));
    request = new Request(request,{headers:trustedHeaders});
    let binding = ctx.props?.CONNECTORS;
    // Local preview emulates the same request-scoped capability. This branch and
    // the auxiliary service binding are absent from production builds.
    if (import.meta.env.DEV && !binding && env.CONNECTORS) {
      const preview = env.CONNECTORS;
      const expiresAt = Date.now() + 60_000;
      binding = {
        async getContext() {
          if (Date.now() >= expiresAt) return { status: "request_context_expired" };
          return preview.getContext?.() ?? { status: "binding_unavailable" };
        },
        async invoke(connectorId, actionName, args) {
          if (Date.now() >= expiresAt) {
            return { status: "request_context_expired", message: "This request has expired. Please try again." };
          }
          return preview.invoke(connectorId, actionName, args);
        },
      };
    }
    const response = await runWithConnectorBinding(binding, () => handler.fetch(request, env, ctx));
    if([401,403,409,413,423,429].includes(response.status)&&new URL(request.url).pathname.startsWith('/api/')){try{await securityEvent(request,'Access or workflow rejection',response.status)}catch{}}
    return secureResponse(response,request,nonce,import.meta.env.DEV);
  },
};
