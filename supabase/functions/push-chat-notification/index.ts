import { createClient } from "npm:@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9";

const jsonHeaders = { "Content-Type": "application/json" };

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: jsonHeaders,
    });
  }

  try {
    const authorization = request.headers.get("Authorization");
    if (!authorization) throw new Error("Missing authorization");

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data: authData, error: authError } = await userClient.auth.getUser();
    if (authError || !authData.user) throw new Error("Invalid user session");

    const { conversation_id: conversationId } = await request.json();
    if (typeof conversationId !== "string") {
      throw new Error("Missing conversation_id");
    }

    const { data: conversation, error: conversationError } = await admin
      .from("ephemeral_conversations")
      .select("link_id")
      .eq("id", conversationId)
      .single();
    if (conversationError || !conversation) throw new Error("Conversation unavailable");

    const { data: link, error: linkError } = await admin
      .from("links")
      .select("owner_id,partner_id")
      .eq("id", conversation.link_id)
      .single();
    if (linkError || !link) throw new Error("Pairing unavailable");

    const senderId = authData.user.id;
    if (senderId !== link.owner_id && senderId !== link.partner_id) {
      throw new Error("Conversation unavailable");
    }
    const recipientId = senderId === link.owner_id ? link.partner_id : link.owner_id;
    const { data: devices, error: devicesError } = await admin
      .from("push_tokens")
      .select("token")
      .eq("user_id", recipientId);
    if (devicesError) throw devicesError;
    if (!devices?.length) {
      return Response.json({ delivered: 0 }, { headers: jsonHeaders });
    }

    const serviceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);
    const auth = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
    const credentials = await auth.authorize();
    if (!credentials.access_token) throw new Error("Could not authorize Firebase");

    let delivered = 0;
    for (const device of devices) {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${credentials.access_token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: device.token,
              notification: {
                title: "Mahila Mitr",
                body: "You have a notification",
              },
              data: {
                type: "chat",
                conversation_id: conversationId,
              },
              android: {
                priority: "high",
                notification: {
                  channel_id: "private_room",
                  visibility: "private",
                },
              },
            },
          }),
        },
      );
      if (response.ok) delivered++;
      else console.error("FCM delivery failed", response.status, await response.text());
    }

    return Response.json({ delivered }, { headers: jsonHeaders });
  } catch (error) {
    console.error(error);
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 400,
      headers: jsonHeaders,
    });
  }
});
