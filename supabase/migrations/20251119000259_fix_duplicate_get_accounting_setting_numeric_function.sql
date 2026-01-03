/*
  # Fix Duplicate get_accounting_setting_numeric Function

  1. Problem
    - Two versions of get_accounting_setting_numeric exist with different signatures
    - Function with 1 parameter: get_accounting_setting_numeric(text)
    - Function with 2 parameters: get_accounting_setting_numeric(text, numeric)
    - This causes "function is not unique" error when calling with 1 parameter

  2. Solution
    - Drop the old single-parameter version
    - Keep the two-parameter version with default value
    - Update all triggers to use the correct function signature
*/

-- Drop the old single-parameter version
DROP FUNCTION IF EXISTS public.get_accounting_setting_numeric(text) CASCADE;

-- Recreate the trigger that was using the old function
CREATE OR REPLACE FUNCTION public.create_invoice_from_ticket() 
RETURNS trigger 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public, pg_temp 
AS $$ 
DECLARE 
  invoice_id uuid; 
  labor_rate numeric; 
  tax_rate numeric; 
  subtotal numeric := 0; 
  tax_amount numeric := 0; 
  total_amount numeric := 0; 
BEGIN 
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN 
    labor_rate := public.get_accounting_setting_numeric('default_labor_rate', 85.00); 
    tax_rate := public.get_accounting_setting_numeric('default_tax_rate', 8.5); 
    
    subtotal := COALESCE(NEW.hours_onsite, 0) * labor_rate; 
    tax_amount := subtotal * (tax_rate / 100); 
    total_amount := subtotal + tax_amount; 
    
    INSERT INTO public.invoices (
      invoice_number, 
      customer_id, 
      ticket_id, 
      issue_date, 
      due_date, 
      status, 
      subtotal, 
      tax_amount, 
      total_amount, 
      created_by
    ) VALUES (
      public.generate_invoice_number(), 
      NEW.customer_id, 
      NEW.id, 
      CURRENT_DATE, 
      CURRENT_DATE + INTERVAL '30 days', 
      'draft', 
      subtotal, 
      tax_amount, 
      total_amount, 
      NEW.assigned_to
    ) RETURNING id INTO invoice_id; 
    
    NEW.invoice_id := invoice_id; 
  END IF; 
  
  RETURN NEW; 
END; 
$$;
