import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@^2";
import Anthropic from "npm:@anthropic-ai/sdk@^0.32.0";

const anthropic = new Anthropic({
  apiKey: Deno.env.get("ANTHROPIC_API_KEY") ?? "",
});

// Admin client — bypasses RLS for usage logging only
const supabaseAdmin = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { question, context, history = [], case_id } = await req.json();

    if (!question || !context) {
      return new Response(
        JSON.stringify({ error: "question and context are required" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 },
      );
    }

    // Extract authenticated user from JWT
    const token = req.headers.get("Authorization")?.replace("Bearer ", "");
    const { data: { user } } = await supabaseAdmin.auth.getUser(token ?? "");

    type MessageParam = { role: "user" | "assistant"; content: string };

    const messages: MessageParam[] = [
      ...(history as MessageParam[]),
      { role: "user", content: question },
    ];

    const response = await anthropic.messages.create({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 1024,
      system: `You are an expert marine surveyor analyst assistant. You have access to the following survey case data assembled from the field:

${context}

Answer questions concisely and professionally based on this case data. Use correct marine survey terminology. If a piece of information is not present in the data, say so clearly rather than guessing. When listing items, use short numbered or bulleted lists. Keep replies focused and practical — the surveyor is typically in the field or under time pressure.`,
      messages,
    });

    const reply = (response.content[0] as { type: string; text: string }).text;

    // Log usage — fire and forget, never block the response
    supabaseAdmin.from("analyst_usage").insert({
      case_id: case_id ?? null,
      user_id: user?.id ?? null,
      model: response.model,
      input_tokens: response.usage.input_tokens,
      output_tokens: response.usage.output_tokens,
    }).then(() => {}).catch(() => {});

    return new Response(
      JSON.stringify({ reply }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: String(error) }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      },
    );
  }
});
