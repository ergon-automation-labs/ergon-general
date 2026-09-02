defmodule BotArmyGeneral.MixProject do
  use Mix.Project

  def project do
    [
      app: :bot_army_general,
      version: "0.2.19",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        general_purpose_bot: [
          applications: [bot_army_general: :permanent]
        ],
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
      {:bot_army_library_core, path: "../bot_army_library_core"},
      {:bot_army_library_runtime, path: "../bot_army_library_runtime", override: true},
      {:jason, "~> 1.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
