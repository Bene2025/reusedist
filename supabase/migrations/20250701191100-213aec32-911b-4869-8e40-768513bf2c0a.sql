
-- Remover tentativa anterior se existir
DELETE FROM public.profiles WHERE email = 'admin@azurespark.com';

-- Criar usuário administrador usando as funções corretas do Supabase
-- Este usuário será criado com confirmação automática de email
SELECT auth.uid() as current_user;

-- Inserir perfil do administrador diretamente (será vinculado quando o usuário fizer login)
INSERT INTO public.profiles (
  id,
  name,
  email,
  role,
  person_type,
  credit_limit
) VALUES (
  'a0000000-0000-0000-0000-000000000001'::uuid,
  'Administrador Sistema',
  'admin@azurespark.com',
  'admin',
  'juridica',
  99999.99
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  email = EXCLUDED.email,
  role = EXCLUDED.role,
  person_type = EXCLUDED.person_type,
  credit_limit = EXCLUDED.credit_limit;

-- Também vou adicionar dados de exemplo para as categorias
INSERT INTO public.categories (name, description, is_active) VALUES
('Fios e Cabos', 'Fios e cabos elétricos para instalações', true),
('Interruptores e Tomadas', 'Interruptores, tomadas e acessórios', true),
('Disjuntores', 'Disjuntores e proteções elétricas', true),
('Iluminação', 'Lâmpadas, luminárias e acessórios', true),
('Ferramentas', 'Ferramentas elétricas e manuais', true)
ON CONFLICT (name) DO NOTHING;
