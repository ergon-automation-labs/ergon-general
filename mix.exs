defmodule BotArmyGeneral.MixProject do
  use Mix.Project

  def project do
    [
      app: :bot_army_general,
      version: "0.1.1",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        general_bot: [
          applications: [bot_army_general: :permanent]
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {BotArmyGeneral.Application, []}
    ]
  end

  defp deps do
    [
      {:bot_army_core, path: "../bot_army_core"},
      {:bot_army_runtime, path: "../bot_army_runtime", override: true},
      {:jason, "~> 1.4"}
    ]
  end
end
