defmodule Lux.LLM.MockProvider do
  @moduledoc """
  A very small mock provider used in tests and examples.
  """

  @behaviour Lux.LLM.Provider

  @impl true
  def name, do: :mock

  @impl true
  def generate(prompt, _opts) do
    # Echo the prompt – deterministic and cheap
    {:ok, "Echo: #{prompt}"}
  end

  @impl true
  def cost(_response), do: 1
end
