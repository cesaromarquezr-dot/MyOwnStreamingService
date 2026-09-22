# Middleware

Contains cross-cutting HTTP concerns that apply across backend routes and services.

## Responsibilities

The middleware layer handles concerns such as:

* Authentication.
* Authorization.
* Bearer-token extraction.
* Request-level security checks.
* Shared HTTP request validation that should occur before route-specific business logic.

## Authentication

`authentication.dart` provides `AuthenticationMiddleware`.

It accepts requests using the standard:

text id="6z8q4p"
Authorization: Bearer <token>

header format.

The middleware is responsible for:

1. Extracting the Bearer token.
2. Rejecting missing or malformed authorization headers.
3. Resolving valid tokens through `AuthService`.
4. Returning the authenticated `Account` when the token is valid.
5. Returning `null` when the request cannot be authenticated.

Token parsing is centralized in `extractToken()` so route handlers do not need to duplicate Authorization-header logic.

Authentication does not store passwords or raw authentication tokens.

## Authentication versus authorization

Authentication answers:

> Who is making this request?

Authorization answers:

> Is that authenticated account allowed to perform this operation?

These responsibilities remain separate.

A route can authenticate the request first and then apply account/profile/role/ownership checks appropriate to the operation.

## Request flow

The backend generally follows this boundary:

text id="7k2m1c"
HTTP Request
    │
    ▼
Middleware
    │
    ├── Authentication
    │
    ├── Authorization / security checks
    │
    ▼
Route Handler
    │
    ▼
Service
    │
    ▼
Database / External Service

This keeps authentication and other cross-cutting security concerns out of individual business-logic implementations where practical.

## Security boundary

Middleware should not:

* Store passwords.
* Log raw authentication tokens.
* Store API keys.
* Expose private account data.
* Bypass route-level authorization requirements.

The middleware layer establishes the request security context; services and route handlers remain responsible for enforcing operation-specific permissions.

## Home-server architecture

The middleware operates inside the backend application and is independent of the external network/security infrastructure:

text id="c4q9vy"
Internet
   │
   ▼
Cloudflare
   │
   ▼
Firewall
   │
   ▼
NGINX Proxy Manager
   │
   ▼
Backend Middleware
   │
   ▼
Routes / Services

Cloudflare, the firewall, VPN access, and NGINX Proxy Manager provide infrastructure-level protection and routing. Application middleware provides authentication and authorization for requests that reach the backend.
::
