ExUnit.start(exclude: [:skip, :integration, :unit])

# Start the Ecto repository
Application.ensure_all_started(:lux)

# Configure the database for testing
Ecto.Adapters.SQL.Sandbox.mode(Lux.Repo, :manual)

defmodule UnitAPICase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Lux.LLM.OpenAI

  using do
    quote do
      @moduletag :unit
    end
  end

  setup do
    Application.put_env(:lux, :req_options, plug: {Req.Test, Lux.Lens})
    Application.put_env(:lux, OpenAI, plug: {Req.Test, OpenAI})

    :ok
  end
end

defmodule IntegrationCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :integration
    end
  end
end
