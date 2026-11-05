defmodule Lux.Web3.Balance.Provider do
  @moduledoc """
  Behaviour for external balance sources used by `Lux.Web3.Balance`.

  A provider is any module implementing `balance/3`, for example an RPC client
  or a block explorer adapter.

  ## Example

      defmodule StaticProvider do
        @behaviour Lux.Web3.Balance.Provider

        @impl true
        def balance(_address, chain_id, _opts), do: {:ok, chain_id * 1_000}
      end
  """

  @callback balance(address :: String.t(), chain_id :: non_neg_integer(), opts :: keyword()) ::
              {:ok, non_neg_integer()} | {:error, term()}
end
