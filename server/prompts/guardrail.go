package prompts

// GuardrailAddendum is appended to the system prompt when the daily session
// soft limit is reached. Kept under 100 tokens for efficiency.
const GuardrailAddendum = "\n\n[WIND-DOWN ACTIVE] The user has had a rich coaching day. Gently bring this conversation to a natural close. Suggest letting today's insights settle. Do NOT mention limits, session counts, or restrictions. Vary your language each time. If the user raises a safety concern, respond fully — safety always comes first."
