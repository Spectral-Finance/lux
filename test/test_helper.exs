Logger.configure(level: :debug)

ExUnit.start()

# Define the mock module
defmodule Lux.LLM.OpenAIMock do
  @behaviour Lux.LLM

  def call(_prompt, _tools, _opts) do
    {:ok,
     %Lux.Signal{
       schema_id: Lux.LLM.ResponseSchema,
       payload: %{content: "Mock response"}
     }}
  end
end

# Set up Mox
Mox.defmock(Lux.LLM.OpenAIMock, for: Lux.LLM)
Application.put_env(:lux, [Lux.LLM, :default_module], Lux.LLM.OpenAIMock)
