
-- Criar tipos enumerados
CREATE TYPE user_role AS ENUM ('customer', 'seller', 'admin');
CREATE TYPE person_type AS ENUM ('fisica', 'juridica');
CREATE TYPE order_status AS ENUM ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled');

-- Tabela de perfis de usuários
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  role user_role NOT NULL DEFAULT 'customer',
  person_type person_type DEFAULT 'fisica',
  state_registration TEXT,
  municipal_registration TEXT,
  responsible_name TEXT,
  credit_limit DECIMAL(10,2) DEFAULT 0,
  activity_nature TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id)
);

-- Tabela de categorias
CREATE TABLE public.categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  parent_id UUID REFERENCES public.categories(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela de produtos
CREATE TABLE public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  sku TEXT UNIQUE NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  cost_price DECIMAL(10,2),
  category_id UUID REFERENCES public.categories(id),
  stock_quantity INTEGER DEFAULT 0,
  min_stock_level INTEGER DEFAULT 0,
  max_stock_level INTEGER,
  weight DECIMAL(8,3),
  dimensions TEXT,
  brand TEXT,
  model TEXT,
  voltage TEXT,
  power_rating TEXT,
  warranty_months INTEGER,
  images TEXT[],
  specifications JSONB,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id)
);

-- Tabela de carrinho
CREATE TABLE public.cart_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, product_id)
);

-- Tabela de pedidos
CREATE TABLE public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  order_number TEXT UNIQUE NOT NULL,
  status order_status DEFAULT 'pending',
  total_amount DECIMAL(10,2) NOT NULL,
  discount_amount DECIMAL(10,2) DEFAULT 0,
  shipping_cost DECIMAL(10,2) DEFAULT 0,
  tax_amount DECIMAL(10,2) DEFAULT 0,
  payment_method TEXT,
  payment_status TEXT DEFAULT 'pending',
  shipping_address JSONB,
  billing_address JSONB,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  seller_id UUID REFERENCES auth.users(id)
);

-- Tabela de itens do pedido
CREATE TABLE public.order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES public.products(id),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price DECIMAL(10,2) NOT NULL,
  total_price DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela de movimentações de estoque
CREATE TABLE public.stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  movement_type TEXT NOT NULL, -- 'in', 'out', 'adjustment'
  quantity INTEGER NOT NULL,
  previous_stock INTEGER NOT NULL,
  new_stock INTEGER NOT NULL,
  reason TEXT,
  reference_id UUID, -- Pode referenciar order_id ou outro documento
  reference_type TEXT, -- 'order', 'adjustment', 'purchase', etc.
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id)
);

-- Tabela de cotações
CREATE TABLE public.quotes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quote_number TEXT UNIQUE NOT NULL,
  customer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  seller_id UUID REFERENCES auth.users(id),
  total_amount DECIMAL(10,2) NOT NULL,
  discount_percentage DECIMAL(5,2) DEFAULT 0,
  discount_amount DECIMAL(10,2) DEFAULT 0,
  valid_until DATE,
  status TEXT DEFAULT 'draft', -- 'draft', 'sent', 'accepted', 'rejected', 'expired'
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela de itens da cotação
CREATE TABLE public.quote_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quote_id UUID REFERENCES public.quotes(id) ON DELETE CASCADE,
  product_id UUID REFERENCES public.products(id),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price DECIMAL(10,2) NOT NULL,
  total_price DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela de fornecedores
CREATE TABLE public.suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  contact_name TEXT,
  email TEXT,
  phone TEXT,
  address JSONB,
  cnpj TEXT,
  state_registration TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id)
);

-- Configurações do sistema
CREATE TABLE public.system_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  setting_key TEXT UNIQUE NOT NULL,
  setting_value JSONB NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES auth.users(id)
);

-- Função para atualizar o campo updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers para atualizar updated_at automaticamente
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON public.categories FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_cart_items_updated_at BEFORE UPDATE ON public.cart_items FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_quotes_updated_at BEFORE UPDATE ON public.quotes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_suppliers_updated_at BEFORE UPDATE ON public.suppliers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Função para criar perfil automaticamente quando usuário se registra
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, name, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
    NEW.email,
    'customer'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para criar perfil automaticamente
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Habilitar RLS em todas as tabelas
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quote_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;

-- Função auxiliar para verificar papéis de usuário (evita recursão infinita)
CREATE OR REPLACE FUNCTION public.get_user_role(user_uuid UUID)
RETURNS TEXT AS $$
  SELECT role::TEXT FROM public.profiles WHERE id = user_uuid;
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- Políticas RLS para profiles
CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admins can view all profiles" ON public.profiles FOR SELECT USING (public.get_user_role(auth.uid()) = 'admin');
CREATE POLICY "Admins can insert profiles" ON public.profiles FOR INSERT WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

-- Políticas RLS para categories (público para leitura, admin para escrita)
CREATE POLICY "Anyone can view active categories" ON public.categories FOR SELECT USING (is_active = true);
CREATE POLICY "Admins can manage categories" ON public.categories FOR ALL USING (public.get_user_role(auth.uid()) = 'admin');

-- Políticas RLS para products (público para leitura, admin/seller para escrita)
CREATE POLICY "Anyone can view active products" ON public.products FOR SELECT USING (is_active = true);
CREATE POLICY "Admins and sellers can manage products" ON public.products FOR ALL USING (public.get_user_role(auth.uid()) IN ('admin', 'seller'));

-- Políticas RLS para cart_items (usuários só veem seus próprios itens)
CREATE POLICY "Users can manage their own cart" ON public.cart_items FOR ALL USING (auth.uid() = user_id);

-- Políticas RLS para orders
CREATE POLICY "Users can view their own orders" ON public.orders FOR SELECT USING (auth.uid() = user_id OR public.get_user_role(auth.uid()) IN ('admin', 'seller'));
CREATE POLICY "Users can create their own orders" ON public.orders FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins and sellers can update orders" ON public.orders FOR UPDATE USING (public.get_user_role(auth.uid()) IN ('admin', 'seller'));

-- Políticas RLS para order_items
CREATE POLICY "Users can view order items of their orders" ON public.order_items FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.orders 
    WHERE orders.id = order_items.order_id 
    AND (orders.user_id = auth.uid() OR public.get_user_role(auth.uid()) IN ('admin', 'seller'))
  )
);
CREATE POLICY "System can insert order items" ON public.order_items FOR INSERT WITH CHECK (true);

-- Políticas RLS para stock_movements (admin e sellers)
CREATE POLICY "Admins and sellers can view stock movements" ON public.stock_movements FOR SELECT USING (public.get_user_role(auth.uid()) IN ('admin', 'seller'));
CREATE POLICY "Admins and sellers can create stock movements" ON public.stock_movements FOR INSERT WITH CHECK (public.get_user_role(auth.uid()) IN ('admin', 'seller'));

-- Políticas RLS para quotes
CREATE POLICY "Users can view their own quotes" ON public.quotes FOR SELECT USING (auth.uid() = customer_id OR public.get_user_role(auth.uid()) IN ('admin', 'seller'));
CREATE POLICY "Sellers and admins can manage quotes" ON public.quotes FOR ALL USING (public.get_user_role(auth.uid()) IN ('admin', 'seller'));

-- Políticas RLS para quote_items
CREATE POLICY "Users can view quote items of their quotes" ON public.quote_items FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.quotes 
    WHERE quotes.id = quote_items.quote_id 
    AND (quotes.customer_id = auth.uid() OR public.get_user_role(auth.uid()) IN ('admin', 'seller'))
  )
);
CREATE POLICY "Sellers and admins can manage quote items" ON public.quote_items FOR ALL USING (public.get_user_role(auth.uid()) IN ('admin', 'seller'));

-- Políticas RLS para suppliers
CREATE POLICY "Admins and sellers can manage suppliers" ON public.suppliers FOR ALL USING (public.get_user_role(auth.uid()) IN ('admin', 'seller'));

-- Políticas RLS para system_settings
CREATE POLICY "Admins can manage system settings" ON public.system_settings FOR ALL USING (public.get_user_role(auth.uid()) = 'admin');

-- Inserir algumas categorias iniciais
INSERT INTO public.categories (name, description) VALUES
('Fios e Cabos', 'Fios e cabos elétricos para instalações residenciais e industriais'),
('Interruptores e Tomadas', 'Interruptores, tomadas e acessórios para instalações elétricas'),
('Disjuntores', 'Disjuntores e dispositivos de proteção elétrica'),
('Lâmpadas e Iluminação', 'Lâmpadas LED, fluorescentes e acessórios de iluminação'),
('Ferramentas Elétricas', 'Ferramentas e equipamentos para eletricistas'),
('Quadros e Painéis', 'Quadros de distribuição e painéis elétricos'),
('Condutores e Eletrodutos', 'Eletrodutos, canaletas e acessórios para passagem de cabos');

-- Inserir alguns produtos de exemplo
INSERT INTO public.products (name, description, sku, price, cost_price, category_id, stock_quantity, min_stock_level, brand, specifications) 
SELECT 
  'Fio Flexível 2,5mm² - 100m',
  'Fio flexível para instalações elétricas residenciais',
  'FIO-FLEX-2.5-100',
  89.90,
  65.00,
  id,
  50,
  10,
  'Conduflex',
  '{"cor": "azul", "secao": "2.5mm²", "comprimento": "100m", "tensao": "750V"}'::jsonb
FROM public.categories WHERE name = 'Fios e Cabos' LIMIT 1;

INSERT INTO public.products (name, description, sku, price, cost_price, category_id, stock_quantity, min_stock_level, brand, specifications)
SELECT 
  'Interruptor Simples Branco',
  'Interruptor simples 10A para uso residencial',
  'INT-SIMP-BR-10A',
  12.50,
  8.00,
  id,
  100,
  20,
  'Tramontina',
  '{"cor": "branco", "corrente": "10A", "tensao": "250V", "tipo": "simples"}'::jsonb
FROM public.categories WHERE name = 'Interruptores e Tomadas' LIMIT 1;

-- Inserir configurações iniciais do sistema
INSERT INTO public.system_settings (setting_key, setting_value, description) VALUES
('site_name', '"AzureSpark - Elétricos & Materiais"', 'Nome do site'),
('site_description', '"Sua loja completa de materiais elétricos"', 'Descrição do site'),
('contact_email', '"contato@azurespark.com.br"', 'Email de contato'),
('contact_phone', '"(11) 9999-9999"', 'Telefone de contato'),
('company_address', '{"street": "Rua das Flores, 123", "city": "São Paulo", "state": "SP", "zipcode": "01234-567"}', 'Endereço da empresa'),
('default_tax_rate', '0.18', 'Taxa de imposto padrão (18%)'),
('shipping_cost_per_kg', '5.00', 'Custo de frete por kg'),
('minimum_order_value', '50.00', 'Valor mínimo do pedido');
