# LexCore Legal OS

MVP LegalTech B2B independiente para gestión jurídica con clientes, expedientes privados, tareas, evidencia y documentos protegidos por Supabase Row Level Security.

## MVP independiente

- Frontend: GitHub Pages
- Auth: Supabase Auth
- Base de datos: PostgreSQL + RLS
- Vector DB: pgvector + HNSW
- Archivos: Supabase Storage privado
- Public key: publishable key de Supabase; no hay `service_role` en el navegador
- AppDeploy/ChatGPT: **no forman parte del runtime de este MVP**
- IA externa: `NOT_CONFIGURED` hasta desplegar un backend privado/Edge Function con credenciales del lado servidor

## URL

https://hackenmate.github.io/lexcore/

## Seguridad

El acceso a clientes y expedientes depende de membresías y `matter_access`. Los documentos se almacenan en `legal-documents` y las políticas de Storage comprueban el expediente indicado en la primera carpeta de la ruta.

No subir claves secretas, service-role keys, documentos jurídicos reales ni credenciales de proveedores a GitHub.
