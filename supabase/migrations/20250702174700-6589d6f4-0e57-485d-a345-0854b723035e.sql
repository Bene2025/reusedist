
-- Criar tabela para dados de clientes
CREATE TABLE public.customer_data (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  company_name TEXT,
  cpf_cnpj TEXT,
  phone TEXT,
  address_street TEXT,
  address_number TEXT,
  address_complement TEXT,
  address_neighborhood TEXT,
  address_city TEXT,
  address_state TEXT,
  address_zipcode TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Criar tabela para dados de vendedores
CREATE TABLE public.seller_data (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  commission_rate NUMERIC DEFAULT 5.0,
  sales_target NUMERIC,
  territory TEXT,
  hire_date DATE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Criar tabela para contas a pagar
CREATE TABLE public.accounts_payable (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  supplier_id UUID REFERENCES public.suppliers(id),
  description TEXT NOT NULL,
  amount NUMERIC NOT NULL,
  due_date DATE NOT NULL,
  payment_date DATE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'overdue', 'cancelled')),
  category TEXT,
  reference_number TEXT,
  notes TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Criar tabela para contas a receber
CREATE TABLE public.accounts_receivable (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id UUID REFERENCES public.profiles(id),
  order_id UUID REFERENCES public.orders(id),
  description TEXT NOT NULL,
  amount NUMERIC NOT NULL,
  due_date DATE NOT NULL,
  payment_date DATE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'overdue', 'cancelled')),
  category TEXT,
  reference_number TEXT,
  notes TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Criar triggers para updated_at
CREATE TRIGGER update_customer_data_updated_at
  BEFORE UPDATE ON public.customer_data
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_seller_data_updated_at
  BEFORE UPDATE ON public.seller_data
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_accounts_payable_updated_at
  BEFORE UPDATE ON public.accounts_payable
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_accounts_receivable_updated_at
  BEFORE UPDATE ON public.accounts_receivable
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Habilitar RLS
ALTER TABLE public.customer_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seller_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts_payable ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts_receivable ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para customer_data
CREATE POLICY "Users can view their own customer data" ON public.customer_data
  FOR SELECT USING (auth.uid() = user_id OR get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Users can insert their own customer data" ON public.customer_data
  FOR INSERT WITH CHECK (auth.uid() = user_id OR get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Users can update their own customer data" ON public.customer_data
  FOR UPDATE USING (auth.uid() = user_id OR get_user_role(auth.uid()) = 'admin');

-- Políticas RLS para seller_data
CREATE POLICY "Sellers can view their own data" ON public.seller_data
  FOR SELECT USING (auth.uid() = user_id OR get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admins can manage seller data" ON public.seller_data
  FOR ALL USING (get_user_role(auth.uid()) = 'admin');

-- Políticas RLS para accounts_payable
CREATE POLICY "Admins and sellers can manage accounts payable" ON public.accounts_payable
  FOR ALL USING (get_user_role(auth.uid()) IN ('admin', 'seller'));

-- Políticas RLS para accounts_receivable
CREATE POLICY "Admins and sellers can manage accounts receivable" ON public.accounts_receivable
  FOR ALL USING (get_user_role(auth.uid()) IN ('admin', 'seller'));

-- Inserir alguns dados de exemplo para teste
INSERT INTO public.categories (name, description) VALUES 
  ('Materiais Elétricos', 'Fios, cabos, disjuntores e materiais elétricos em geral'),
  ('Tintas e Vernizes', 'Tintas, vernizes e produtos para pintura'),
  ('Ferramentas', 'Ferramentas manuais e elétricas'),
  ('Material Hidráulico', 'Tubos, conexões e materiais hidráulicos');

-- Inserir alguns produtos de exemplo
INSERT INTO public.products (name, sku, price, cost_price, category_id, stock_quantity, description, is_active) 
SELECT 
  'Fio Elétrico 2,5mm² - 100m', 
  'FIO-25-100', 
  45.99, 
  32.50, 
  c.id, 
  100, 
  'Fio elétrico flexível 2,5mm² para instalações residenciais', 
  true
FROM public.categories c WHERE c.name = 'Materiais Elétricos'
UNION ALL
SELECT 
  'Tinta Acrílica Branca 18L', 
  'TINTA-ACR-18L', 
  89.90, 
  65.00, 
  c.id, 
  50, 
  'Tinta acrílica premium para paredes internas e externas', 
  true
FROM public.categories c WHERE c.name = 'Tintas e Vernizes'
UNION ALL
SELECT 
  'Furadeira Elétrica 500W', 
  'FUR-500W', 
  159.90, 
  120.00, 
  c.id, 
  25, 
  'Furadeira elétrica com mandril de 10mm e velocidade variável', 
  true
FROM public.categories c WHERE c.name = 'Ferramentas';
