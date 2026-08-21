create extension if not exists vector with schema extensions;
create extension if not exists pgcrypto with schema extensions;

create type public.membership_role as enum ('OWNER','PARTNER','LAWYER','PARALEGAL','VIEWER','AUDITOR');
create type public.ai_run_status as enum ('VERIFIED','PARTIALLY_SUPPORTED','INSUFFICIENT_EVIDENCE','CONFLICTING_AUTHORITIES','OUTDATED_SOURCE','HUMAN_REVIEW_REQUIRED','PRIVACY_GATE_BLOCKED');

create table public.tenants(id uuid primary key default gen_random_uuid(),name text not null,created_at timestamptz not null default now());
create table public.profiles(id uuid primary key references auth.users(id) on delete cascade,email text,display_name text,created_at timestamptz not null default now());
create table public.memberships(tenant_id uuid not null references public.tenants(id) on delete cascade,user_id uuid not null references public.profiles(id) on delete cascade,role public.membership_role not null,created_at timestamptz not null default now(),primary key(tenant_id,user_id));
create table public.clients(id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id) on delete cascade,name text not null,document_number text,email text,phone text,classification text,created_at timestamptz not null default now());
create table public.matters(id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id) on delete cascade,case_number text,title text not null,client_id uuid references public.clients(id) on delete set null,client_name text,practice_area text,status text not null default 'ACTIVE',ethical_wall boolean not null default true,ai_external_allowed boolean not null default false,confidentiality_level text not null default 'CONFIDENTIAL',created_at timestamptz not null default now());
create table public.matter_access(matter_id uuid not null references public.matters(id) on delete cascade,user_id uuid not null references public.profiles(id) on delete cascade,role public.membership_role not null,created_at timestamptz not null default now(),primary key(matter_id,user_id));
create table public.documents(id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id) on delete cascade,matter_id uuid not null references public.matters(id) on delete cascade,title text not null,mime_type text not null,sha256 text not null check(sha256 ~ '^[a-f0-9]{64}$'),storage_key text not null,indexing_status text not null,classification text not null default 'CONFIDENTIAL',created_at timestamptz not null default now());
create table public.document_versions(id uuid primary key default gen_random_uuid(),document_id uuid not null references public.documents(id) on delete cascade,version integer not null check(version>0),sha256 text not null check(sha256 ~ '^[a-f0-9]{64}$'),storage_key text not null,created_at timestamptz not null default now(),unique(document_id,version));
create table public.evidence(id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id) on delete cascade,matter_id uuid not null references public.matters(id) on delete cascade,document_version_id uuid references public.document_versions(id) on delete set null,title text not null,page integer,content text not null,source_type text not null,review_required boolean not null default false,created_at timestamptz not null default now());
create table public.document_chunks(id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id) on delete cascade,matter_id uuid not null references public.matters(id) on delete cascade,evidence_id uuid not null references public.evidence(id) on delete cascade,content text not null,embedding extensions.vector(1536),created_at timestamptz not null default now());
create index chunks_embedding_hnsw on public.document_chunks using hnsw(embedding vector_cosine_ops);
create table public.tasks(id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id) on delete cascade,matter_id uuid not null references public.matters(id) on delete cascade,title text not null,due_date date,priority text not null default 'NORMAL',done boolean not null default false,completed_at timestamptz,created_at timestamptz not null default now());
create table public.deadlines(id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id) on delete cascade,matter_id uuid not null references public.matters(id) on delete cascade,label text not null,event_date date not null,business_days integer not null check(business_days between 1 and 365),excluded_dates date[] not null default '{}',computed_date date not null,rule_source text not null,calculation_basis text not null,status text not null default 'HUMAN_REVIEW_REQUIRED',created_at timestamptz not null default now());
create table public.ai_runs(id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id) on delete cascade,matter_id uuid not null references public.matters(id) on delete cascade,user_id uuid not null references public.profiles(id),status public.ai_run_status not null,question_hash text,model_alias text,source_count integer not null default 0,created_at timestamptz not null default now());
create table public.audit_events(id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id) on delete cascade,actor_user_id uuid references public.profiles(id),matter_id uuid references public.matters(id) on delete set null,action text not null,resource_type text,resource_id uuid,request_id text,created_at timestamptz not null default now());

alter table public.tenants enable row level security;
alter table public.profiles enable row level security;
alter table public.memberships enable row level security;
alter table public.clients enable row level security;
alter table public.matters enable row level security;
alter table public.matter_access enable row level security;
alter table public.documents enable row level security;
alter table public.document_versions enable row level security;
alter table public.evidence enable row level security;
alter table public.document_chunks enable row level security;
alter table public.tasks enable row level security;
alter table public.deadlines enable row level security;
alter table public.ai_runs enable row level security;
alter table public.audit_events enable row level security;

create policy profiles_self_select on public.profiles for select to authenticated using(id=(select auth.uid()));
create policy memberships_self_select on public.memberships for select to authenticated using(user_id=(select auth.uid()));
create policy tenants_member_select on public.tenants for select to authenticated using(exists(select 1 from public.memberships m where m.tenant_id=tenants.id and m.user_id=(select auth.uid())));
create policy matters_access_select on public.matters for select to authenticated using(exists(select 1 from public.matter_access ma where ma.matter_id=matters.id and ma.user_id=(select auth.uid())));
create policy matter_access_self_select on public.matter_access for select to authenticated using(user_id=(select auth.uid()));
create policy documents_matter_select on public.documents for select to authenticated using(exists(select 1 from public.matter_access ma where ma.matter_id=documents.matter_id and ma.user_id=(select auth.uid())));
create policy evidence_matter_select on public.evidence for select to authenticated using(exists(select 1 from public.matter_access ma where ma.matter_id=evidence.matter_id and ma.user_id=(select auth.uid())));
create policy chunks_matter_select on public.document_chunks for select to authenticated using(exists(select 1 from public.matter_access ma where ma.matter_id=document_chunks.matter_id and ma.user_id=(select auth.uid())));
create policy tasks_matter_select on public.tasks for select to authenticated using(exists(select 1 from public.matter_access ma where ma.matter_id=tasks.matter_id and ma.user_id=(select auth.uid())));
create policy deadlines_matter_select on public.deadlines for select to authenticated using(exists(select 1 from public.matter_access ma where ma.matter_id=deadlines.matter_id and ma.user_id=(select auth.uid())));
create policy audit_privileged_select on public.audit_events for select to authenticated using(exists(select 1 from public.memberships m where m.tenant_id=audit_events.tenant_id and m.user_id=(select auth.uid()) and m.role in ('OWNER','PARTNER','AUDITOR')));

create index matter_access_user_idx on public.matter_access(user_id,matter_id);
create index documents_matter_idx on public.documents(matter_id,created_at desc);
create index evidence_matter_idx on public.evidence(matter_id,created_at);
create index tasks_matter_idx on public.tasks(matter_id,due_date);
create index deadlines_matter_idx on public.deadlines(matter_id,computed_date);
create index ai_runs_matter_idx on public.ai_runs(matter_id,created_at desc);
create index audit_tenant_created_idx on public.audit_events(tenant_id,created_at desc);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('legal-documents','legal-documents',false,26214400,array['application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document','text/plain','image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

-- Production project created and reviewed in sa-east-1 on 2026-08-21.
-- Do not put service-role keys, database passwords or LLM credentials in this migration or repository.
