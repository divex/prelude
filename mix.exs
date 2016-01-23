defmodule Prelude.Mixfile do
  use Mix.Project

  def project do
    [app: :prelude,
     version: "0.1.0",
     elixir: "~> 1.0",
     description: "etude compiler",
     deps: deps,
     package: package,
     aliases: aliases]
  end

  def application do
    [applications: [:logger]]
  end

  defp aliases do
    [bench: [&set_bench_env/1, "bench"]]
  end

  defp set_bench_env(_) do
    Mix.env(:bench)
  end

  defp deps do
    [{:excheck, "~> 0.2.3", only: [:dev, :test, :bench]},
     {:triq, github: "krestenkrab/triq", only: [:dev, :test, :bench]},
     {:benchfella, "~> 0.2.0", only: [:dev, :test, :bench]},
     {:parse_trans, "~> 2.9.0", only: [:dev, :test, :bench]},
     {:mix_test_watch, "~> 0.2", only: :dev}]
  end

  defp package do
    [files: ["lib", "mix.exs", "README*"],
     maintainers: ["Cameron Bytheway"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/camshaft/prelude"}]
  end
end