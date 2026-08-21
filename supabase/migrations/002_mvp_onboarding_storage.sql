create or replace function public.ensure_workspace(p_name text default 'Mi Estudio')
returns uuid
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_tenant uuid;
  v_email text;
begin
  if v_user is null then raise exception 'authentication_required'; end if;
  v_email := coalesce(auth.jwt()->>'email','');
  insert into public.profiles(id,email,display_name)
  values(v_user,v_email,coalesce(nullif(split_part(v_email,'@',1),''),'Profesional'))
  on conflict(id) do update set email=excluded.email;
  select m.tenant_id into v_tenant from public.memberships m where m.user_id=v_user order by m.created_at limit 1;
  if v_tenant is not null then return v_tenant; end if;
  insert into public.tenants(name) values(coalesce(nullif(trim(p_name),''),'Mi Estudio')) returning id into v_tenant;
  insert into public.memberships(tenant_id,user_id,role) values(v_tenant,v_user,'OWNER');
  return v_tenant;
end;
$$;
revoke all on function public.ensure_workspace(text) from public, anon;
grant execute on function public.ensure_workspace(text) to authenticated;

create or replace function public.create_matter_mvp(p_title text,p_client_name text,p_case_number text default null,p_practice_area text default 'General')
returns uuid
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare v_user uuid:=auth.uid();v_tenant uuid;v_matter uuid;
begin
  if v_user is null then raise exception 'authentication_required'; end if;
  select m.tenant_id into v_tenant from public.memberships m where m.user_id=v_user order by m.created_at limit 1;
  if v_tenant is null then v_tenant:=public.ensure_workspace('Mi Estudio'); end if;
  if nullif(trim(p_title),'') is null or nullif(trim(p_client_name),'') is null then raise exception 'title_and_client_required'; end if;
  insert into public.matters(tenant_id,title,client_name,case_number,practice_area,status,ethical_wall,ai_external_allowed,confidentiality_level)
  values(v_tenant,trim(p_title),trim(p_client_name),nullif(trim(coalesce(p_case_number,'')),''),coalesce(nullif(trim(p_practice_area),''),'General'),'ACTIVE',true,false,'CONFIDENTIAL') returning id into v_matter;
  insert into public.matter_access(matter_id,user_id,role) values(v_matter,v_user,'OWNER');
  return v_matter;
end;
$$;
revoke all on function public.create_matter_mvp(text,text,text,text) from public, anon;
grant execute on function public.create_matter_mvp(text,text,text,text) to authenticated;

create or replace function public.storage_matter_id(object_name text)
returns uuid language plpgsql immutable set search_path=public,storage,pg_temp as $$
begin return (storage.foldername(object_name))[1]::uuid; exception when others then return null; end;
$$;
revoke all on function public.storage_matter_id(text) from public, anon;
grant execute on function public.storage_matter_id(text) to authenticated;

create policy legal_documents_select on storage.objects for select to authenticated using(bucket_id='legal-documents' and exists(select 1 from public.matter_access ma where ma.matter_id=public.storage_matter_id(name) and ma.user_id=(select auth.uid())));
create policy legal_documents_insert on storage.objects for insert to authenticated with check(bucket_id='legal-documents' and exists(select 1 from public.matter_access ma where ma.matter_id=public.storage_matter_id(name) and ma.user_id=(select auth.uid()) and ma.role in ('OWNER','PARTNER','LAWYER','PARALEGAL')));
create policy legal_documents_delete on storage.objects for delete to authenticated using(bucket_id='legal-documents' and exists(select 1 from public.matter_access ma where ma.matter_id=public.storage_matter_id(name) and ma.user_id=(select auth.uid()) and ma.role in ('OWNER','PARTNER','LAWYER')));

grant insert on public.matter_access to authenticated;
