# Wasla Engineering Standards

These standards govern the long-term maintainability, architecture, and engineering culture of Wasla. All human developers and AI assistants must adhere to these rules without exception.

## 1. Architectural Philosophy
Wasla strictly adheres to **Feature-First Architecture** inside the Flutter client and **Domain-Driven Design** across the Supabase backend.
- **Rule 1.1:** A feature must be self-contained in `lib/features/<feature_name>/`.
- **Rule 1.2:** Features cannot cross-depend directly on each other's presentation layers. They must communicate via Shared Providers or Core Models.
- **Rule 1.3:** The backend (Edge Functions) must remain stateless and idempotent.

## 2. Naming Standards
- **Folders:** `snake_case` (e.g., `post_ad/`). Maximum depth inside `lib/` is 4.
- **Files:** `snake_case.dart` or `snake-case.ts`.
- **Classes/Models/Widgets:** `PascalCase` (e.g., `AdFormScreen`).
- **Providers:** Always suffixed with `Provider` (e.g., `authProvider`).
- **Database Tables:** Plural `snake_case` (e.g., `categories`, `ads`).
- **Database Columns:** Singular `snake_case` (e.g., `title`, `created_at`).

## 3. Flutter & State Management (Riverpod)
- **Rule 3.1 (State Separation):** UI files (`.dart` inside `screens/` or `widgets/`) MUST NOT contain business logic or direct database queries.
- **Rule 3.2 (Provider Purity):** Providers must use `riverpod_annotation` (`@riverpod`). State must be strictly immutable using the `Freezed` package.
- **Rule 3.3 (Widget Size):** No `build()` method should exceed 100 lines. Break down complex UIs into private widget classes.
- **Rule 3.4 (Rebuild Optimization):** Always use `ref.watch(provider.select((v) => v.property))` when listening to large model changes to prevent unnecessary rebuilds.

## 4. Backend & Database (Supabase)
- **Rule 4.1 (Abstraction):** Direct Supabase client queries (`Supabase.instance.client.from...`) are BANNED inside Flutter Providers. They must be abstracted behind a Repository class (e.g., `AdRepository`).
- **Rule 4.2 (RLS Enforcement):** EVERY table must have Row-Level Security (RLS) enabled. "Public" write access is strictly forbidden.
- **Rule 4.3 (Edge Functions):** Heavy processing (AI image analysis, payment validation) must execute via Edge Functions, NOT on the client device.
- **Rule 4.4 (Foreign Keys):** All foreign keys must include `ON DELETE CASCADE` or `RESTRICT` depending on domain safety to prevent orphaned records.

## 5. Security & Secrets
- **Rule 5.1:** Hardcoded secrets (API keys, service tokens) are grounds for immediate PR rejection. Use `.env` locally and Supabase Vault/Environment secrets in production.
- **Rule 5.2:** Storage buckets must strictly validate MIME types via Storage Policies to prevent malicious executable hosting.

## 6. AI Development Standards
Since Wasla employs AI coding assistants, the following rules apply to all automated agents:
- **Rule 6.1 (Scope Constraint):** Never refactor code outside the explicit scope of the user's request.
- **Rule 6.2 (Consistency):** Always match the existing file's naming conventions and architectural style. Do not introduce BLoC to a Riverpod project.
- **Rule 6.3 (Verification):** Always run `dart format .` and `dart fix --apply` after significant automated modifications.
- **Rule 6.4 (Documentation Sync):** If database schemas or API contracts change, `README.md` and related Markdown documentation must be updated in the same execution.
