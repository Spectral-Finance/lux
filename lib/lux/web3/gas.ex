defmodule Lux.Web3.Gas do
  @moduledoc """
  Gas optimization and transaction management for EVM chains.

  Provides:
  - `estimate_gas/3` — estimate gas for a transaction via `eth_estimateGas`
  - `gas_price/2` — get current gas price in wei and gwei via `eth_gasPrice`
  - `gas_price_hex/1` — get current gas price as raw hex string (JSON-RPC compatible)
  - `optimize_gas/4` — check if estimated gas is within a max budget
  - `hex_to_int/1` — parse hex-encoded quantities (e.g. `0x5208` → 21000)
  """

  @doc """
  Parse a hex-encoded JSON-RPC quantity into an integer.

  Handles both `0x`-prefixed hex strings and plain decimal strings.
  Returns `{:ok, integer}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> Lux.Web3.Gas.hex_to_int("0x5208")
      {:ok, 21000}

      iex> Lux.Web3.Gas.hex_to_int("21000")
      {:ok, 21000}

      iex> Lux.Web3.Gas.hex_to_int("0xinvalid")
      {:error, "invalid hex string: 0xinvalid"}
  """
  def hex_to_int(hex_str) when is_binary(hex_str) do
    cleaned =
      if String.starts_with?(hex_str, "0x") or String.starts_with?(hex_str, "0X"),
        do: String.slice(hex_str, 2..-1//1),
        else: hex_str

    case Integer.parse(cleaned, 16) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "invalid hex string: #{hex_str}"}
    end
  end

  def hex_to_int(_), do: {:error, "input must be a binary string"}

  @doc """
  Estimate gas for a transaction.

  Returns `{:ok, %{gas: integer, chain: atom}}` on success.

  Uses `eth_estimateGas` JSON-RPC call. The hex result is parsed via `hex_to_int/1`.

  ## Examples

      iex> Lux.Web3.Gas.estimate_gas("0xabc", "0x1234")
      {:ok, %{gas: 21000, chain: :ethereum}}
  """
  def estimate_gas(to, data, chain \\ :ethereum) do
    rpc = rpc_url(chain)
    params = [%{to: to, data: data}, "latest"]

    case json_rpc(rpc, "eth_estimateGas", params) do
      {:ok, result} ->
        case hex_to_int(result) do
          {:ok, gas} -> {:ok, %{gas: gas, chain: chain}}
          error -> error
        end

      error ->
        error
    end
  end

  @doc """
  Get current gas price in wei and gwei.

  Returns `{:ok, %{wei: integer, gwei: float, chain: atom}}` on success.

  Uses `eth_gasPrice` JSON-RPC call. The hex result is parsed via `hex_to_int/1`.

  ## Examples

      iex> Lux.Web3.Gas.gas_price()
      {:ok, %{wei: 20_000_000_000, gwei: 20.0, chain: :ethereum}}
  """
  def gas_price(chain \\ :ethereum) do
    case json_rpc(rpc_url(chain), "eth_gasPrice", []) do
      {:ok, result} ->
        case hex_to_int(result) do
          {:ok, wei} ->
            {:ok, %{wei: wei, gwei: wei / 1_000_000_000, chain: chain}}

          error ->
            error
        end

      error ->
        error
    end
  end

  @doc """
  Get current gas price as a raw hex string.

  Useful for forwarding the raw JSON-RPC response downstream without conversion.

  Returns `{:ok, %{hex: binary, chain: atom}}` on success.

  ## Examples

      iex> Lux.Web3.Gas.gas_price_hex()
      {:ok, %{hex: "0x4a817c800", chain: :ethereum}}
  """
  def gas_price_hex(chain \\ :ethereum) do
    case json_rpc(rpc_url(chain), "eth_gasPrice", []) do
      {:ok, result} -> {:ok, %{hex: result, chain: chain}}
      error -> error
    end
  end

  @doc """
  Check if a transaction can be executed within a maximum gas budget.

  Estimates gas for the transaction and fetches current gas price,
  then reports whether the transaction is feasible within the given `max_gas`.

  Returns `{:ok, map}` with details:

    * `estimated` — estimated gas units
    * `price_gwei` — current gas price in gwei
    * `total_eth` — estimated total cost in ETH (estimated * price_gwei / 1e9)
    * `feasible` — boolean, true if `estimated <= max_gas`
    * `overshoot` — only present when not feasible: `estimated - max_gas`

  ## Examples

      iex> Lux.Web3.Gas.optimize_gas("0xabc", "0x1234", 50_000)
      {:ok, %{estimated: 21000, price_gwei: 20.0, total_eth: 4.2e-7, feasible: true}}
  """
  def optimize_gas(to, data, max_gas, chain \\ :ethereum) do
    with {:ok, %{gas: estimated}} <- estimate_gas(to, data, chain),
         {:ok, %{gwei: price}} <- gas_price(chain) do
      if estimated <= max_gas,
        do:
          {:ok,
           %{
             estimated: estimated,
             price_gwei: price,
             total_eth: estimated * price / 1_000_000_000,
             feasible: true
           }},
        else:
          {:ok,
           %{
             estimated: estimated,
             price_gwei: price,
             feasible: false,
             overshoot: estimated - max_gas
           }}
    end
  end

  # ── private helpers ──────────────────────────────────────────────

  defp rpc_url(:ethereum), do: Application.get_env(:lux, :ethereum_rpc) || "https://eth.llamarpc.com"
  defp rpc_url(:polygon), do: Application.get_env(:lux, :polygon_rpc) || "https://polygon.llamarpc.com"
  defp rpc_url(:arbitrum), do: Application.get_env(:lux, :arbitrum_rpc) || "https://arbitrum.llamarpc.com"

  defp json_rpc(url, method, params) do
    body = %{jsonrpc: "2.0", id: 1, method: method, params: params}

    case Req.post(url, json: body, headers: [{"Content-Type", "application/json"}]) do
      {:ok, %{status: 200, body: %{"result" => r}}} -> {:ok, r}
      {:ok, %{status: 200, body: %{"error" => e}}} -> {:error, e}
      {:error, err} -> {:error, inspect(err)}
    end
  end
end
