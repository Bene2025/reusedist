
-- Adicionar políticas RLS que estavam faltando
CREATE POLICY "Users can manage their own cart" ON public.cart_items FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Anyone can view active categories" ON public.categories FOR SELECT USING (is_active = true);
CREATE POLICY "Admins can manage categories" ON public.categories FOR ALL USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Anyone can view active products" ON public.products FOR SELECT USING (is_active = true);
CREATE POLICY "Admins and sellers can manage products" ON public.products FOR ALL USING (public.get_user_role(auth.uid()) IN ('admin', 'seller'));

CREATE POLICY "Users can view their own orders" ON public.orders FOR SELECT USING (auth.uid() = user_id OR public.get_user_role(auth.uid()) IN ('admin', 'seller'));
CREATE POLICY "Users can create their own orders" ON public.orders FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins and sellers can update orders" ON public.orders FOR UPDATE USING (public.get_user_role(auth.uid()) IN ('admin', 'seller'));

CREATE POLICY "Users can view order items of their orders" ON public.order_items FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.orders 
    WHERE orders.id = order_items.order_id 
    AND (orders.user_id = auth.uid() OR public.get_user_role(auth.uid()) IN ('admin', 'seller'))
  )
);
CREATE POLICY "System can insert order items" ON public.order_items FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins and sellers can view stock movements" ON public.stock_movements FOR SELECT USING (public.get_user_role(auth.uid()) IN ('admin', 'seller'));
CREATE POLICY "Admins and sellers can create stock movements" ON public.stock_movements FOR INSERT WITH CHECK (public.get_user_role(auth.uid()) IN ('admin', 'seller'));

CREATE POLICY "Users can view their own quotes" ON public.quotes FOR SELECT USING (auth.uid() = customer_id OR public.get_user_role(auth.uid()) IN ('admin', 'seller'));
CREATE POLICY "Sellers and admins can manage quotes" ON public.quotes FOR ALL USING (public.get_user_role(auth.uid()) IN ('admin', 'seller'));

CREATE POLICY "Users can view quote items of their quotes" ON public.quote_items FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.quotes 
    WHERE quotes.id = quote_items.quote_id 
    AND (quotes.customer_id = auth.uid() OR public.get_user_role(auth.uid()) IN ('admin', 'seller'))
  )
);
CREATE POLICY "Sellers and admins can manage quote items" ON public.quote_items FOR ALL USING (public.get_user_role(auth.uid()) IN ('admin', 'seller'));

CREATE POLICY "Admins and sellers can manage suppliers" ON public.suppliers FOR ALL USING (public.get_user_role(auth.uid()) IN ('admin', 'seller'));

CREATE POLICY "Admins can manage system settings" ON public.system_settings FOR ALL USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admins can view all profiles" ON public.profiles FOR SELECT USING (public.get_user_role(auth.uid()) = 'admin');
CREATE POLICY "Admins can insert profiles" ON public.profiles FOR INSERT WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

-- Inserir usuário administrador de teste
INSERT INTO auth.users (
  id,
  instance_id,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  role,
  aud,
  confirmation_token,
  email_change_token_new,
  recovery_token
) VALUES (
  'a0000000-0000-0000-0000-000000000001'::uuid,
  '00000000-0000-0000-0000-000000000000'::uuid,
  'admin@azurespark.com',
  crypt('admin123456', gen_salt('bf')),
  NOW(),
  NOW(),
  NOW(),
  'authenticated',
  'authenticated',
  '',
  '',
  ''
);

-- Inserir perfil do administrador
INSERT INTO public.profiles (
  id,
  name,
  email,
  role,
  person_type
) VALUES (
  'a0000000-0000-0000-0000-000000000001'::uuid,
  'Administrador',
  'admin@azurespark.com',
  'admin',
  'juridica'
);

-- Adicionar alguns produtos de exemplo para o carrinho funcionar
INSERT INTO public.products (name, description, sku, price, cost_price, category_id, stock_quantity, min_stock_level, brand, specifications, images) 
SELECT 
  'Cabo Flexível 4mm² - Rolo 100m',
  'Cabo flexível para instalações elétricas residenciais e comerciais',
  'CABO-FLEX-4MM-100',
  125.90,
  89.00,
  id,
  25,
  5,
  'Prysmian',
  '{"cor": "preto", "secao": "4mm²", "comprimento": "100m", "tensao": "750V", "norma": "NBR NM 247-3"}'::jsonb,
  ARRAY['/placeholder.svg']
FROM public.categories WHERE name = 'Fios e Cabos' LIMIT 1;

INSERT INTO public.products (name, description, sku, price, cost_price, category_id, stock_quantity, min_stock_level, brand, specifications, images)
SELECT 
  'Tomada 2P+T 10A Branca',
  'Tomada padrão brasileiro com terra para uso residencial',
  'TOM-2PT-10A-BR',
  18.90,
  12.50,
  id,
  150,
  30,
  'Tramontina',
  '{"cor": "branca", "corrente": "10A", "tensao": "250V", "tipo": "2P+T", "norma": "NBR 14136"}'::jsonb,
  ARRAY['/placeholder.svg']
FROM public.categories WHERE name = 'Interruptores e Tomadas' LIMIT 1;

INSERT INTO public.products (name, description, sku, price, cost_price, category_id, stock_quantity, min_stock_level, brand, specifications, images)
SELECT 
  'Disjuntor Monopolar 20A',
  'Disjuntor de proteção para circuitos elétricos',
  'DISJ-MONO-20A',
  42.80,
  28.90,
  id,
  80,
  15,
  'Schneider',
  '{"corrente": "20A", "tensao": "220V", "tipo": "monopolar", "capacidade_ruptura": "3kA"}'::jsonb,
  ARRAY['/placeholder.svg']
FROM public.categories WHERE name = 'Disjuntores' LIMIT 1;
