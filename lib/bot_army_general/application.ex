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
    if @env == :test, do: children, else: [BotArmyGeneral.NATS.Consumer | children]
  end
end
