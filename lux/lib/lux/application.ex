defmodule Lux.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Existing children …
      # Add the LLM provider registry so it is started with the app.
      Lux.LLM.ProviderRegistry
    ]

    opts = [strategy: :one_for_one, name: Lux.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
