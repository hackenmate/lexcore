# Security posture

LexCore is designed as a private-by-default legal workspace.

## Active controls in the current application

- Authentication required for private routes.
- Explicit matter membership and role checks.
- Ethical walls between matters.
- Viewer role is read-only and cannot execute AI queries.
- External AI processing is disabled by default per matter.
- Document uploads record SHA-256 hashes.
- AI answers use an evidence-only prompt, Citation Gate and second-pass verification.
- Deadline calculations are deterministic and remain `HUMAN_REVIEW_REQUIRED`.

## Production database

A dedicated Supabase project in `sa-east-1` has PostgreSQL, pgvector, RLS and a private `legal-documents` bucket provisioned. Supabase security advisor reported no findings after the foundation migration.

The running AppDeploy application has **not yet completed the identity/data cutover** to this Supabase project. Do not represent the current runtime as Supabase-RLS-backed until that migration is completed.

## Not yet claimed

- SOC 2 certification.
- Customer-controlled KMS/HSM envelope encryption.
- Contractual LLM Zero Data Retention.
- Automatic authoritative Peruvian procedural holiday calendar.

## Repository policy

Never commit:

- Supabase service-role keys or database passwords.
- LLM provider credentials.
- real case files, client documents or confidential prompts.
- signing keys, private certificates or production secrets.
