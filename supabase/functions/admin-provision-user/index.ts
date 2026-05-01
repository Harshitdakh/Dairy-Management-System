import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

type ProvisionRequest = {
  role: "seller" | "customer";
  email: string;
  password: string;
  full_name: string;
  phone: string;
  route_name?: string;
  location?: string;
  seller_id?: string;
  milk_type?: "cow" | "buffalo" | "mixed";
  rate_per_liter?: number;
  daily_quantity_liters?: number;
  daily_quantity_ml?: number;
};

const json = (payload: unknown, status = 200) =>
  new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "Server is not configured" }, 500);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ error: "Missing auth token" }, 401);
  }

  const jwt = authHeader.replace("Bearer ", "").trim();

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data: actorData, error: actorError } = await adminClient.auth.getUser(jwt);
  if (actorError || !actorData.user) {
    return json({ error: "Unauthorized" }, 401);
  }

  const actorId = actorData.user.id;
  const { data: actorProfile, error: actorProfileError } = await adminClient
    .from("profiles")
    .select("role")
    .eq("id", actorId)
    .maybeSingle();

  if (actorProfileError || actorProfile?.role !== "admin") {
    return json({ error: "Only admin can provision users" }, 403);
  }

  let body: ProvisionRequest;
  try {
    body = (await req.json()) as ProvisionRequest;
  } catch (_e) {
    return json({ error: "Invalid JSON payload" }, 400);
  }

  if (!body.email || !body.password || !body.full_name || !body.phone || !body.role) {
    return json({ error: "Missing required fields" }, 400);
  }

  if (!["seller", "customer"].includes(body.role)) {
    return json({ error: "Invalid role" }, 400);
  }

  if (body.password.length < 6) {
    return json({ error: "Password must be at least 6 characters" }, 400);
  }

  if (body.role === "seller" && !body.route_name) {
    return json({ error: "route_name is required for seller" }, 400);
  }

  let createdUserId: string | null = null;

  try {
    const { data: createdAuthUser, error: createUserError } = await adminClient.auth.admin.createUser({
      email: body.email.trim().toLowerCase(),
      password: body.password,
      email_confirm: true,
      user_metadata: {
        full_name: body.full_name.trim(),
        phone: body.phone.trim(),
        role: body.role,
      },
      app_metadata: {
        role: body.role,
      },
    });

    if (createUserError || !createdAuthUser.user) {
      return json(
        { error: createUserError?.message ?? "Failed to create auth user" },
        400,
      );
    }

    createdUserId = createdAuthUser.user.id;

    const { error: profileError } = await adminClient.from("profiles").upsert(
      {
        id: createdUserId,
        full_name: body.full_name.trim(),
        phone: body.phone.trim(),
        role: body.role,
      },
      { onConflict: "id" },
    );

    if (profileError) {
      throw new Error(profileError.message);
    }

    if (body.role === "seller") {
      const { data: sellerRow, error: sellerError } = await adminClient
        .from("sellers")
        .insert({
          user_id: createdUserId,
          route_name: body.route_name?.trim(),
          location: body.location?.trim() || null,
          status: "active",
        })
        .select("id")
        .single();

      if (sellerError) {
        throw new Error(sellerError.message);
      }

      return json({
        message: "Seller provisioned successfully",
        user_id: createdUserId,
        seller_id: sellerRow.id,
      });
    }

    let routeName: string | null = null;
    if (body.seller_id) {
      const { data: seller, error: sellerLookupError } = await adminClient
        .from("sellers")
        .select("route_name")
        .eq("id", body.seller_id)
        .maybeSingle();
      if (sellerLookupError) {
        throw new Error(sellerLookupError.message);
      }
      routeName = seller?.route_name ?? null;
    }

    const { data: customerRow, error: customerError } = await adminClient
      .from("customers")
      .insert({
        user_id: createdUserId,
        seller_id: body.seller_id ?? null,
        route_name: routeName,
        location: body.location?.trim() || null,
        milk_type: body.milk_type ?? "cow",
        rate_per_liter: body.rate_per_liter ?? 0,
        daily_quantity_liters: body.daily_quantity_liters ?? 1,
        daily_quantity_ml: body.daily_quantity_ml ?? 0,
        status: "active",
      })
      .select("id")
      .single();

    if (customerError) {
      throw new Error(customerError.message);
    }

    return json({
      message: "Customer provisioned successfully",
      user_id: createdUserId,
      customer_id: customerRow.id,
    });
  } catch (e) {
    if (createdUserId) {
      await adminClient.auth.admin.deleteUser(createdUserId);
    }
    const message = e instanceof Error ? e.message : "Provisioning failed";
    return json({ error: message }, 400);
  }
});
