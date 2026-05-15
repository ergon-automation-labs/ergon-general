import Config

# After skill work: para.capture.append + synapse.intent.notification.request
config :bot_army_general,
  operator_notify_enabled: true,
  para_capture_timeout_ms: 5_000,
  ask_llm_timeout_ms: 120_000
