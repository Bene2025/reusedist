
-- Primeiro, vamos criar algumas tabelas que estão faltando

-- Tabela para armazenar dados específicos de clientes
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
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id)
);

-- Tabela para armazenar dados específicos de vendedores
CREATE TABLE public.seller_data (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  commission_rate DECIMAL(5,2) DEFAULT 5.00,
  sales_target DECIMAL(10,2) DEFAULT 0,
  hire_date DATE DEFAULT CURRENT_DATE,
  is_active BOOLEAN DEFAULT true,
  territory TEXT,
  manager_id UUID REFERENCES public.profiles(id),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id)
);

-- Tabela para comissões de vendedores
CREATE TABLE public.commissions (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  seller_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  commission_amount DECIMAL(10,2) NOT NULL,
  commission_rate DECIMAL(5,2) NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'cancelled')),
  paid_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(order_id)
);

-- Tabela para relatórios personalizados
CREATE TABLE public.reports (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  report_type TEXT NOT NULL CHECK (report_type IN ('sales', 'inventory', 'financial', 'customer', 'seller')),
  parameters JSONB,
  created_by UUID NOT NULL REFERENCES public.profiles(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Tabela para logs de atividades
CREATE TABLE public.activity_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id),
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  old_data JSONB,
  new_data JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Adicionar RLS para todas as novas tabelas
ALTER TABLE public.customer_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seller_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para customer_data
CREATE POLICY "Users can view their own customer data" ON public.customer_data FOR SELECT USING (auth.uid() = user_id OR get_user_role(auth.uid()) = ANY (ARRAY['admin'::text, 'seller'::text]));
CREATE POLICY "Users can update their own customer data" ON public.customer_data FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own customer data" ON public.customer_data FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can manage all customer data" ON public.customer_data FOR ALL USING (get_user_role(auth.uid()) = 'admin'::text);

-- Políticas RLS para seller_data
CREATE POLICY "Sellers can view their own data" ON public.seller_data FOR SELECT USING (auth.uid() = user_id OR get_user_role(auth.uid()) = ANY (ARRAY['admin'::text]));
CREATE POLICY "Admins can manage seller data" ON public.seller_data FOR ALL USING (get_user_role(auth.uid()) = 'admin'::text);

-- Políticas RLS para commissions
CREATE POLICY "Sellers can view their own commissions" ON public.commissions FOR SELECT USING (auth.uid() = seller_id OR get_user_role(auth.uid()) = 'admin'::text);
CREATE POLICY "Admins can manage commissions" ON public.commissions FOR ALL USING (get_user_role(auth.uid()) = 'admin'::text);

-- Políticas RLS para reports
CREATE POLICY "Users can view reports they created" ON public.reports FOR SELECT USING (auth.uid() = created_by OR get_user_role(auth.uid()) = ANY (ARRAY['admin'::text, 'seller'::text]));
CREATE POLICY "Users can manage their own reports" ON public.reports FOR ALL USING (auth.uid() = created_by OR get_user_role(auth.uid()) = 'admin'::text);

-- Políticas RLS para activity_logs
CREATE POLICY "Users can view their own activity logs" ON public.activity_logs FOR SELECT USING (auth.uid() = user_id OR get_user_role(auth.uid()) = 'admin'::text);
CREATE POLICY "System can insert activity logs" ON public.activity_logs FOR INSERT WITH CHECK (true);

-- Triggers para updated_at
CREATE TRIGGER update_customer_data_updated_at BEFORE UPDATE ON public.customer_data FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_seller_data_updated_at BEFORE UPDATE ON public.seller_data FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_reports_updated_at BEFORE UPDATE ON public.reports FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Função para calcular comissões automaticamente
CREATE OR REPLACE FUNCTION public.calculate_commission()
RETURNS TRIGGER AS $$
BEGIN
  -- Inserir comissão quando um pedido for confirmado
  IF NEW.status = 'confirmed' AND (OLD.status IS NULL OR OLD.status != 'confirmed') THEN
    INSERT INTO public.commissions (seller_id, order_id, commission_amount, commission_rate)
    SELECT 
      NEW.seller_id,
      NEW.id,
      NEW.total_amount * (COALESCE(sd.commission_rate, 5.0) / 100),
      COALESCE(sd.commission_rate, 5.0)
    FROM public.seller_data sd
    WHERE sd.user_id = NEW.seller_id
    ON CONFLICT (order_id) DO NOTHING;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para calcular comissões automaticamente
CREATE TRIGGER calculate_commission_trigger
  AFTER UPDATE OF status ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.calculate_commission();

-- Função para registrar logs de atividade
CREATE OR REPLACE FUNCTION public.log_activity()
RETURNS TRIGGER AS $$
BEGIN
  -- Registrar atividade para operações importantes
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.activity_logs (user_id, action, entity_type, entity_id, new_data)
    VALUES (auth.uid(), 'CREATE', TG_TABLE_NAME, NEW.id, to_jsonb(NEW));
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO public.activity_logs (user_id, action, entity_type, entity_id, old_data, new_data)
    VALUES (auth.uid(), 'UPDATE', TG_TABLE_NAME, NEW.id, to_jsonb(OLD), to_jsonb(NEW));
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.activity_logs (user_id, action, entity_type, entity_id, old_data)
    VALUES (auth.uid(), 'DELETE', TG_TABLE_NAME, OLD.id, to_jsonb(OLD));
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Aplicar triggers de log em tabelas importantes
CREATE TRIGGER log_products_activity AFTER INSERT OR UPDATE OR DELETE ON public.products FOR EACH ROW EXECUTE FUNCTION public.log_activity();
CREATE TRIGGER log_orders_activity AFTER INSERT OR UPDATE OR DELETE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.log_activity();
CREATE TRIGGER log_profiles_activity AFTER INSERT OR UPDATE OR DELETE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.log_activity();

-- Inserir dados de exemplo para vendedores
INSERT INTO public.seller_data (user_id, commission_rate, sales_target, territory)
SELECT p.id, 7.5, 50000.00, 'São Paulo'
FROM public.profiles p
WHERE p.role = 'seller'
ON CONFLICT (user_id) DO NOTHING;

-- Inserir alguns produtos de exemplo
INSERT INTO public.products (name, description, price, sku, category_id, stock_quantity, brand, min_stock_level, max_stock_level, is_active) VALUES
('Fio Flexível 2,5mm² Azul', 'Fio flexível para instalações elétricas residenciais', 4.50, 'FF-25-AZ', (SELECT id FROM categories WHERE name = 'Fios e Cabos' LIMIT 1), 500, 'Condumex', 50, 1000, true),
('Disjuntor Bipolar 25A', 'Disjuntor de proteção bipolar 25 ampères', 35.90, 'DJ-BP-25A', (SELECT id FROM categories WHERE name = 'Disjuntores' LIMIT 1), 150, 'Schneider', 20, 300, true),
('Interruptor Simples Branco', 'Interruptor simples de 1 tecla na cor branca', 8.75, 'INT-S-BR', (SELECT id FROM categories WHERE name = 'Interruptores e Tomadas' LIMIT 1), 200, 'Tramontina', 30, 500, true),
('Lâmpada LED 9W Branca', 'Lâmpada LED econômica 9W luz branca', 12.90, 'LED-9W-BR', (SELECT id FROM categories WHERE name = 'Iluminação' LIMIT 1), 300, 'Philips', 40, 600, true),
('Furadeira Elétrica 500W', 'Furadeira elétrica profissional 500W', 189.90, 'FUR-500W', (SELECT id FROM categories WHERE name = 'Ferramentas' LIMIT 1), 25, 'Bosch', 5, 50, true)
ON CONFLICT (sku) DO NOTHING;
