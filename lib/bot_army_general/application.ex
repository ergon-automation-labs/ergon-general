defmodule BotArmyGeneral.Application do
  @moduledoc false
  use Application

  @env Mix.env()

  @impl true
  def start(_type, _args) do
    # Load configuration from Salt-deployed config file (not env vars)
    config_data = BotArmyLibraryRuntime.ConfigLoader.load_config()
    Application.put_env(:bot_army_library_runtime, :config_data, config_data)

    children =
      []
      |> maybe_add_consumer()

    opts = [strategy: :one_for_one, name: BotArmyGeneral.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_add_consumer(children) do
    if @env == :test do
      children
    else
      [
        # Leader/standby election for dual-node (air + mini) deployment — must
        # start before the consumer so its first on_role_change call lands
        # while the consumer is still connecting (not yet subscribed either way).
        {BotArmyLibraryRuntime.LeaderElection,
         service: "general",
         node_name: BotArmyLibraryRuntime.ConfigLoader.get("NODE_NAME", "unknown"),
         default_role:
           parse_role(BotArmyLibraryRuntime.ConfigLoader.get("GENERAL_NODE_ROLE", "primary")),
         on_role_change: {BotArmyGeneral.NATS.Consumer, :leader_role_changed, []}},
        BotArmyGeneral.NATS.Consumer
        | children
      ]
    end
  end

  defp parse_role("standby"), do: :standby
  defp parse_role("primary"), do: :primary
  defp parse_role(_), do: :primary
end
