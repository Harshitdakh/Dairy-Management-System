-- ============================================================================
-- FIX: SALES TRIGGER PARTIAL CONFLICT CLAUSE & ROUTE DELETE RLS
-- ============================================================================

-- 1. Add missing DELETE policy for sellers on delivery_routes
DROP POLICY IF EXISTS delivery_routes_seller_delete ON public.delivery_routes;
CREATE POLICY delivery_routes_seller_delete ON public.delivery_routes
    FOR DELETE TO authenticated
    USING (
        (seller_id = get_my_seller_id())
        OR (created_by = auth.uid())
        OR is_admin()
    );

-- 2. Update apply_sale_to_inventory_and_bill trigger to match partial index
--    idx_milk_deliveries_sale_unique ON public.milk_deliveries(sale_id) WHERE (sale_id IS NOT NULL)
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
