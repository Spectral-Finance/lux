defmodule Lux.Lenses.PancakeSwap.Pools.GetSwapQuote do
  @moduledoc """
  Gets a swap quote from PancakeSwap.

  ## Examples

      iex> GetSwapQuote.focus(%{token_in: "0x...", token_out: "0x...", amount_in: "1000000000000000000"})
      {:ok, %{data: %{...}}}
  """

  alias Lux.Integrations.PancakeSwap
  require Logger

  use Lux.Lens,
    name: "PancakeSwap Get Swap Quote",
    description: "Gets a swap quote from PancakeSwap",
    url: "#{PancakeSwap.base_url()}/swap",
    method: :get,
    headers: PancakeSwap.headers(),
    auth: PancakeSwap.auth(),
    schema: %{
      type: :object,
      properties: %{
        token_in: %{type: :string, description: "The input token address"},
        token_out: %{type: :string, description: "The output token address"},
        amount_in: %{type: :string, description: "The input amount in wei"}
      },
      required: ["token_in", "token_out", "amount_in"]
    }

  def before_focus(params) do
    %{url: "#{Lux.Integrations.PancakeSwap.base_url()}/swap?tokenIn=#{params.token_in}&tokenOut=#{params.token_out}&amountIn=#{params.amount_in}"}
  end

  def after_focus(%{"data" => data}) do
    {:ok, data}
  end

  def after_focus(body) do
    {:error, %{error: "Unexpected response", raw: body}}
  end
end
