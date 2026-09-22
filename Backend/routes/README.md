# Routes

HTTP endpoint handlers for the streaming-service backend.

Routes are responsible for translating HTTP requests into validated service calls. They should remain thin: **validate at the HTTP boundary, authenticate and authorize the request, delegate business rules to services, and serialize the response.**

## Responsibilities

Routes should:

* Match HTTP methods and API paths.
* Handle CORS and `OPTIONS` preflight requests where required.
* Authenticate protected requests.
* Enforce route-level authorization requirements.
* Validate query parameters, path parameters, headers, and JSON bodies.
* Enforce reasonable request-size and input-length limits.
* Reject malformed or unsupported input explicitly.
* Delegate business operations to the appropriate service.
* Return consistent HTTP status codes and JSON responses.
* Apply appropriate response security headers.
* Avoid caching authenticated or account-specific responses.
* Log unexpected server-side failures without exposing internal details to clients.

## Security boundary

Authentication should be performed through the shared authentication middleware rather than duplicating token parsing in individual routes.

Routes should never:

* Trust account IDs supplied by an unauthenticated client.
* Trust profile ownership supplied by the client.
* Accept passwords, payment credentials, service-role keys, or other secrets unnecessarily.
* Return stack traces, exception objects, database credentials, tokens, or internal filesystem details.
* Treat client-provided metadata as authoritative security information.
* Log authentication tokens, passwords, payment credentials, or other sensitive values.
* Put Supabase service-role credentials in Flutter/client code.

For account-scoped operations, the authenticated account should be the authoritative identity. Client-provided IDs should be treated as resource selectors and verified against that authenticated account by the service/database layer.

## Validation

Validation should occur at the HTTP boundary before calling a service.

Typical validation includes:

* HTTP method.
* Route/path structure.
* Required parameters.
* Maximum string lengths.
* Numeric ranges.
* Enumerated status values.
* JSON object/array types.
* Request-body size.
* Safe path handling.
* Resource ownership.
* Authentication and authorization requirements.

Routes should reject malformed values rather than silently converting them into potentially dangerous defaults.

Business validation that depends on application state belongs in the service layer.

## Request bodies

JSON request bodies should be bounded before parsing.

Routes handling client-provided JSON should:

1. Enforce a maximum body size.
2. Decode UTF-8 safely.
3. Require the expected JSON structure.
4. Validate required fields and types.
5. Pass only validated data to services.

Large or unexpected payloads should receive an appropriate `4xx` response.

## Responses

JSON API responses should:

* Set `Content-Type: application/json`.
* Use appropriate HTTP status codes.
* Avoid exposing internal exception messages for unexpected failures.
* Use `Cache-Control: no-store` for authenticated/account-specific data.
* Include `X-Content-Type-Options: nosniff`.
* Apply CORS consistently for browser-facing API endpoints.

Successful mutations should not be reported as failed solely because a secondary notification or email operation failed after the primary state change has already succeeded. Such failures should be logged and handled separately.

## Error handling

Expected client errors should return an appropriate `4xx` response with a safe, actionable message.

Unexpected failures should:

* Be logged server-side with diagnostic details.
* Return a generic `500` response.
* Never expose stack traces or implementation details to clients.

Routes should not use exception text as a general-purpose public API contract.

## Services and business logic

Routes should delegate business rules to services.

For example:

```text
HTTP request
    ↓
Route
    ├── authenticate
    ├── validate input
    └── authorize resource
    ↓
Service
    ├── business rules
    ├── persistence
    ├── external providers
    └── transactions
    ↓
Route
    ↓
HTTP response
```

Avoid putting database workflows, payment decisions, recommendation algorithms, metadata matching, media processing, or other domain logic directly inside route handlers.

## Authentication and authorization

Authentication establishes **who** is making the request.

Authorization establishes **whether that authenticated principal may perform the requested operation**.

A route should not assume that successful authentication automatically grants access to every resource.

Examples include:

* A profile must belong to the authenticated account.
* Account media must not be accessible to another account without an explicit sharing rule.
* Group operations must verify group membership and permissions.
* Administrative operations require administrative authorization.
* Private marketplace/media information must remain scoped to its owning server/account.
* Remote-worker operations require the appropriate worker credential and job authorization.

## CORS

Browser-facing routes should handle `OPTIONS` requests and explicitly define the methods and headers they support.

The current development configuration may use permissive CORS where appropriate, but production deployments should prefer a configured allow-list when the service is exposed beyond a trusted environment.

CORS is not an authentication mechanism.

## Self-hosting and reverse proxies

The route layer is designed to operate behind the documented self-hosting architecture:

```text
Internet
   ↓
Cloudflare
   ↓
Firewall
   ↓
NGINX Proxy Manager
   ↓
Streaming Service Backend
```

Routes should not blindly trust forwarded headers such as `X-Forwarded-For` or `X-Forwarded-Proto`. Trusted-proxy configuration must determine which forwarded headers are authoritative.

TLS may terminate at NGINX Proxy Manager or, when configured, at the Dart backend itself.

## Supabase synchronization

Supabase synchronization endpoints are authenticated backend endpoints.

The Flutter application communicates with the backend; it must not receive or use the Supabase service-role credential.

The intended flow is:

```text
Flutter
   ↓ authenticated request
Dart backend
   ↓ authenticate + authorize + sanitize
SupabaseStore
   ↓ server-side service role
Supabase
```

Account and profile identifiers supplied by the client must still be checked against the authenticated account before persistence.

## Administrative endpoints

Administrative endpoints require stronger protection than ordinary authenticated routes.

Examples include:

* Storage administration.
* Platform configuration.
* Server management.
* Worker management.
* Operational maintenance.

High-privilege credentials should not be exposed through Flutter application code. Administrative endpoints should additionally be restricted through the self-hosted private/VPN network or an equivalent administrative authorization mechanism where practical.

## File and media routes

Routes that access filesystem-backed media must treat paths as untrusted input.

They should prevent:

* Path traversal.
* Absolute-path escape.
* Symlink-based escape from approved roots.
* Unauthorized cross-account access.
* Arbitrary filesystem reads.

Filesystem authorization and media ownership should be enforced before opening a file.

## Route organization

Routes are grouped by API responsibility, for example:

```text
auth_routes.dart
group_routes.dart
home_server_routes.dart
legal_routes.dart
library_routes.dart
location_routes.dart
media_intelligence_routes.dart
payment_routes.dart
platform_routes.dart
playback_routes.dart
rating_routes.dart
recommendations_routes.dart
remote_access_routes.dart
review_routes.dart
search_routes.dart
self_hosting_routes.dart
shop_routes.dart
sports_routes.dart
storage_routes.dart
supabase_sync_routes.dart
```

New route files should follow the same pattern:

```dart
class ExampleRoutes {
  final ExampleService service;

  ExampleRoutes({
    required this.service,
  });

  Future<void> handle(HttpRequest request) async {
    // Match route.
    // Authenticate.
    // Validate.
    // Authorize.
    // Delegate to service.
    // Serialize response.
  }
}
```

## Persistence

Routes should not assume that an in-memory model mutation is durable.

When persistence is required, the appropriate service/store should perform the database operation. This is particularly important for:

* Accounts.
* Profiles.
* Media.
* Ratings.
* Reviews.
* Groups.
* Marketplace state.
* ARM/import state.
* Storage requests.
* Remote workers.
* Payment state.

The current development backend may contain in-memory stores, but production persistence must be handled by the configured database/store layer.

## API evolution

When changing an endpoint:

* Preserve existing response contracts when practical.
* Update the corresponding Flutter client.
* Update route documentation when behavior changes.
* Validate backwards compatibility for existing clients.
* Avoid silently changing the meaning of existing fields.
* Prefer explicit versioned changes for incompatible API contracts.

Routes are the HTTP boundary; they should remain predictable, secure, and thin while domain services own the application's business rules.
