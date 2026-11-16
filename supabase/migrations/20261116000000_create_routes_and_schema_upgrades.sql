-- ============================================================================
-- MILK HUB PRODUCTION MIGRATION: ROUTES, SEQUENCING, SHIFTS & VACATION PAUSES
-- ============================================================================

-- 1. Create delivery_routes table
CREATE TABLE IF NOT EXISTS public.delivery_routes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    seller_id UUID REFERENCES public.sellers(id) ON DELETE SET NULL,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    shift TEXT NOT NULL DEFAULT 'morning' CHECK (shift IN ('morning', 'evening', 'both')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'archived')),
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS on delivery_routes
ALTER TABLE public.delivery_routes ENABLE ROW LEVEL SECURITY;

-- Indexes on delivery_routes
CREATE INDEX IF NOT EXISTS idx_delivery_routes_seller ON public.delivery_routes (seller_id);
CREATE INDEX IF NOT EXISTS idx_delivery_routes_status ON public.delivery_routes (status);
CREATE INDEX IF NOT EXISTS idx_delivery_routes_shift ON public.delivery_routes (shift);

-- RLS policies on delivery_routes
DROP POLICY IF EXISTS delivery_routes_admin_all ON public.delivery_routes;
CREATE POLICY delivery_routes_admin_all ON public.delivery_routes
    FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

DROP POLICY IF EXISTS delivery_routes_seller_select ON public.delivery_routes;
CREATE POLICY delivery_routes_seller_select ON public.delivery_routes
    FOR SELECT TO authenticated
    USING (
        (current_user_role() = 'seller'::text)
        OR (seller_id = get_my_seller_id())
        OR is_admin()
    );

DROP POLICY IF EXISTS delivery_routes_seller_insert ON public.delivery_routes;
CREATE POLICY delivery_routes_seller_insert ON public.delivery_routes
    FOR INSERT TO authenticated
    WITH CHECK (
        (current_user_role() = 'seller'::text)
        OR is_admin()
    );

DROP POLICY IF EXISTS delivery_routes_seller_update ON public.delivery_routes;
CREATE POLICY delivery_routes_seller_update ON public.delivery_routes
    FOR UPDATE TO authenticated
    USING (
        (seller_id = get_my_seller_id())
        OR (created_by = auth.uid())
        OR is_admin()
    )
    WITH CHECK (
        (seller_id = get_my_seller_id())
        OR (created_by = auth.uid())
        OR is_admin()
    );

DROP POLICY IF EXISTS delivery_routes_seller_delete ON public.delivery_routes;
CREATE POLICY delivery_routes_seller_delete ON public.delivery_routes
    FOR DELETE TO authenticated
    USING (
        (seller_id = get_my_seller_id())
        OR (created_by = auth.uid())
        OR is_admin()
    );

-- 2. Alter customers table
ALTER TABLE public.customers
    ADD COLUMN IF NOT EXISTS route_id UUID REFERENCES public.delivery_routes(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS delivery_sequence INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS delivery_shift TEXT NOT NULL DEFAULT 'morning' CHECK (delivery_shift IN ('morning', 'evening', 'both'));

CREATE INDEX IF NOT EXISTS idx_customers_route_sequence ON public.customers (route_id, delivery_sequence ASC);
CREATE INDEX IF NOT EXISTS idx_customers_delivery_shift ON public.customers (delivery_shift);

-- Allow sellers to update customer sequence and route assignment
DROP POLICY IF EXISTS customers_update_seller ON public.customers;
CREATE POLICY customers_update_seller ON public.customers
    FOR UPDATE TO authenticated
    USING (
        (seller_id = get_my_seller_id())
        OR is_admin()
    )
    WITH CHECK (
        (seller_id = get_my_seller_id())
        OR is_admin()
    );

DROP POLICY IF EXISTS customers_insert_seller ON public.customers;
CREATE POLICY customers_insert_seller ON public.customers
    FOR INSERT TO authenticated
    WITH CHECK (
        (seller_id = get_my_seller_id())
        OR is_admin()
    );

-- 3. Alter milk_deliveries table
ALTER TABLE public.milk_deliveries
    ADD COLUMN IF NOT EXISTS shift TEXT NOT NULL DEFAULT 'morning' CHECK (shift IN ('morning', 'evening'));

CREATE INDEX IF NOT EXISTS idx_milk_deliveries_customer_date_shift ON public.milk_deliveries (customer_id, delivery_date, shift);

-- Enable seller update policy on milk_deliveries
DROP POLICY IF EXISTS milk_deliveries_update ON public.milk_deliveries;
CREATE POLICY milk_deliveries_update ON public.milk_deliveries
    FOR UPDATE TO authenticated
    USING (
        (current_user_role() = 'admin'::text)
        OR (seller_id IN (SELECT sellers.id FROM sellers WHERE sellers.user_id = auth.uid()))
    )
    WITH CHECK (
        (current_user_role() = 'admin'::text)
        OR (seller_id IN (SELECT sellers.id FROM sellers WHERE sellers.user_id = auth.uid()))
    );

-- 4. Alter milk_sales table & Update trigger
ALTER TABLE public.milk_sales
    ADD COLUMN IF NOT EXISTS shift TEXT NOT NULL DEFAULT 'morning' CHECK (shift IN ('morning', 'evening'));

CREATE OR REPLACE FUNCTION public.apply_sale_to_inventory_and_bill()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
declare
  sold_ml numeric;
  current_ml numeric;
  updated_ml numeric;
  sold_liters numeric;
  bill_month_value date;
begin
  sold_ml := coalesce(new.quantity_liters, 0) * 1000 + coalesce(new.quantity_ml, 0);

  current_ml := (
    coalesce((select assigned_milk_liters from public.sellers where id = new.seller_id), 0) * 1000
    + coalesce((select assigned_milk_ml from public.sellers where id = new.seller_id), 0)
  );

  updated_ml := greatest(current_ml - sold_ml, 0);

  update public.sellers
  set assigned_milk_liters = floor(updated_ml / 1000),
      assigned_milk_ml = mod(updated_ml, 1000)
  where id = new.seller_id;

  insert into public.milk_deliveries (
    seller_id,
    customer_id,
    sale_id,
    delivery_date,
    milk_type,
    quantity_liters,
    quantity_ml,
    rate,
    amount,
    status,
    shift,
    notes
  )
  values (
    new.seller_id,
    new.customer_id,
    new.id,
    new.sale_date,
    new.milk_type,
    new.quantity_liters,
    new.quantity_ml,
    case
      when (coalesce(new.quantity_liters, 0) + coalesce(new.quantity_ml, 0) / 1000) > 0
      then coalesce(new.total_amount, 0) / (coalesce(new.quantity_liters, 0) + coalesce(new.quantity_ml, 0) / 1000)
      else 0
    end,
    coalesce(new.total_amount, 0),
    'delivered',
    coalesce(new.shift, 'morning'),
    new.notes
  )
  on conflict (sale_id) where (sale_id is not null) do nothing;

  sold_liters := coalesce(new.quantity_liters, 0) + coalesce(new.quantity_ml, 0) / 1000;
  bill_month_value := public.month_start(new.sale_date);

  insert into public.customer_bills (
    customer_id,
    seller_id,
    bill_month,
    total_quantity_liters,
    total_amount,
    paid_amount,
    pending_amount,
    status
  )
  values (
    new.customer_id,
    new.seller_id,
    bill_month_value,
    sold_liters,
    coalesce(new.total_amount, 0),
    0,
    coalesce(new.total_amount, 0),
    'pending'
  )
  on conflict (customer_id, bill_month)
  do update set
    seller_id = excluded.seller_id,
    total_quantity_liters = public.customer_bills.total_quantity_liters + excluded.total_quantity_liters,
    total_amount = public.customer_bills.total_amount + excluded.total_amount,
    pending_amount = greatest((public.customer_bills.total_amount + excluded.total_amount) - public.customer_bills.paid_amount, 0),
    status = case
      when public.customer_bills.paid_amount >= (public.customer_bills.total_amount + excluded.total_amount) then 'paid'
      when public.customer_bills.paid_amount > 0 then 'partial'
      else 'pending'
    end,
    updated_at = now();

  return new;
end;
$function$;

-- 5. Create delivery_pauses table
CREATE TABLE IF NOT EXISTS public.delivery_pauses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    reason TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT check_pause_dates CHECK (end_date >= start_date)
);

ALTER TABLE public.delivery_pauses ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_delivery_pauses_customer_dates ON public.delivery_pauses (customer_id, start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_delivery_pauses_status ON public.delivery_pauses (status);

-- RLS policies for delivery_pauses
DROP POLICY IF EXISTS delivery_pauses_customer_select ON public.delivery_pauses;
CREATE POLICY delivery_pauses_customer_select ON public.delivery_pauses
    FOR SELECT TO authenticated
    USING (
        customer_id IN (SELECT id FROM public.customers WHERE user_id = auth.uid())
        OR (current_user_role() = 'admin'::text)
    );

DROP POLICY IF EXISTS delivery_pauses_customer_insert ON public.delivery_pauses;
CREATE POLICY delivery_pauses_customer_insert ON public.delivery_pauses
    FOR INSERT TO authenticated
    WITH CHECK (
        customer_id IN (SELECT id FROM public.customers WHERE user_id = auth.uid())
        AND status = 'pending'
    );

DROP POLICY IF EXISTS delivery_pauses_customer_update ON public.delivery_pauses;
CREATE POLICY delivery_pauses_customer_update ON public.delivery_pauses
    FOR UPDATE TO authenticated
    USING (
        customer_id IN (SELECT id FROM public.customers WHERE user_id = auth.uid())
        AND status = 'pending'
    )
    WITH CHECK (
        customer_id IN (SELECT id FROM public.customers WHERE user_id = auth.uid())
        AND status = 'cancelled'
    );

DROP POLICY IF EXISTS delivery_pauses_seller_select ON public.delivery_pauses;
CREATE POLICY delivery_pauses_seller_select ON public.delivery_pauses
    FOR SELECT TO authenticated
    USING (
        customer_id IN (SELECT id FROM public.customers WHERE seller_id = get_my_seller_id())
        OR is_admin()
    );

DROP POLICY IF EXISTS delivery_pauses_seller_update ON public.delivery_pauses;
CREATE POLICY delivery_pauses_seller_update ON public.delivery_pauses
    FOR UPDATE TO authenticated
    USING (
        customer_id IN (SELECT id FROM public.customers WHERE seller_id = get_my_seller_id())
        OR is_admin()
    )
    WITH CHECK (
        customer_id IN (SELECT id FROM public.customers WHERE seller_id = get_my_seller_id())
        OR is_admin()
    );

DROP POLICY IF EXISTS delivery_pauses_admin_all ON public.delivery_pauses;
CREATE POLICY delivery_pauses_admin_all ON public.delivery_pauses
    FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

-- 6. Backfill existing live routes and customers
INSERT INTO public.delivery_routes (name, seller_id, shift, status)
SELECT DISTINCT
    s.route_name,
    s.id AS seller_id,
    'morning' AS shift,
    'active' AS status
FROM public.sellers s
WHERE s.route_name IS NOT NULL AND trim(s.route_name) != ''
ON CONFLICT DO NOTHING;

UPDATE public.customers c
SET route_id = r.id
FROM public.delivery_routes r
WHERE (c.route_name = r.name)
   OR (c.seller_id IS NOT NULL AND c.seller_id = r.seller_id AND c.route_id IS NULL);

WITH seq AS (
    SELECT id, ROW_NUMBER() OVER (PARTITION BY route_id ORDER BY created_at ASC) as s
    FROM public.customers
    WHERE route_id IS NOT NULL
)
UPDATE public.customers c
SET delivery_sequence = seq.s
FROM seq
WHERE c.id = seq.id;
