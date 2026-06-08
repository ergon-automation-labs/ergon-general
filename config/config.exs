import Config

# Logger with correlation_id support
config :logger,
  level: :info,
  backends: [:console],
  default_formatter: {BotArmyRuntime.LoggerFormatter, []}

config :logger, :console,
  format: {BotArmyRuntime.LoggerFormatter, []},
  metadata: [:correlation_id]

config :bot_army_general, :deployment_status, "experimental"

# After skill work: para.capture.append + synapse.intent.notification.request
config :bot_army_general,
  operator_notify_enabled: true,
  para_capture_timeout_ms: 5_000,
  ask_llm_timeout_ms: 120_000,
  ask_default_model: "ministral-3:3b"

