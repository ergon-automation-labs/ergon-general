defmodule BotArmyGeneral.Application do
  @moduledoc false
  use Application

  @env Mix.env()

  @impl true
  def start(_type, _args) do
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
         node_name: System.get_env("NODE_NAME", "unknown"),
         default_role: BotArmyLibraryRuntime.LeaderElection.role_from_env("GENERAL_NODE_ROLE"),
         on_role_change: {BotArmyGeneral.NATS.Consumer, :leader_role_changed, []}},
        BotArmyGeneral.NATS.Consumer
        | children
      ]
    end
  end
end
