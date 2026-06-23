defmodule Lux.Lenses.MultiChain.Aggregator do
  @moduledoc """
  Multi-chain data aggregation system for collecting and processing blockchain data
  across multiple EVM-compatible networks.

  This module provides a unified lens that queries multiple chains in parallel,
  normalizes results, and handles rate limiting and error recovery.

  ## Supported Chains
  - Ethereum (chainid: 1)
  - BNB Smart Chain (chainid: 56)
  - Polygon (chainid: 137)
  - Arbitrum (chainid: 42161)
  - Optimism (chainid: 10)
  - Avalanche C-Chain (chainid: 43114)
  - Fantom (chainid: 250)
  - Base (chainid: 8453)
  """

  alias Lux.Lens
  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "MultiChain.Aggregator",
    description: "Aggregates blockchain data across multiple EVM-compatible chains in parallel with normalization, rate limiting, and error handling",
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{type: :custom, auth_function: &__MODULE__.add_api_key/1},
    schema: %{
      type: :object,
      properties: %{
        chains: %{type: :array, description: "List of chain IDs to aggregate data from", items: %{type: :integer}, minItems: 1, maxItems: 10},
        data_type: %{type: :string, description: "Type of data to aggregate across chains", enum: ["blocks", "block_rewards", "tx_status", "token_balances", "token_transfers", "event_logs", "gas_prices", "account_balances", "account_transactions"], default: "blocks"},
        limit: %{type: :integer, description: "Maximum records per chain (default: 10)", default: 10},
        rate_limit_per_second: %{type: :integer, description: "Max concurrent chains (default: 3)", default: 3},
        retry_attempts: %{type: :integer, description: "Retries per failed query (default: 2)", default: 2},
        retry_delay_ms: %{type: :integer, description: "Retry delay in ms (default: 1000)", default: 1000}
      },
      required: ["chains", "data_type"]
    }

  @doc "Adds the Etherscan API key to the lens parameters."
  def add_api_key(lens) do
    %{lens | params: Map.put(lens.params, :apikey, Lux.Config.etherscan_api_key())}
  end

  @doc "Prepares parameters before making the API request."
  def before_focus(params) do
    params
    |> Map.put_new(:limit, 10)
    |> Map.put_new(:rate_limit_per_second, 3)
    |> Map.put_new(:retry_attempts, 2)
    |> Map.put_new(:retry_delay_ms, 1000)
    |> validate_chains()
    |> Map.update!(:data_type, &String.downcase/1)
  end

  @spec focus(map()) :: {:ok, map()} | {:error, term()}
  def focus(params) when is_map(params) do
    chains = Map.get(params, :chains, [])
    data_type = Map.get(params, :data_type, "blocks")
    limit = Map.get(params, :limit, 10)
    concurrency = Map.get(params, :rate_limit_per_second, 3)
    retries = Map.get(params, :retry_attempts, 2)
    retry_delay = Map.get(params, :retry_delay_ms, 1000)
    base_lens = Lens.new() |> add_api_key()

    results = chains
      |> Enum.with_index()
      |> Task.async_stream(fn {cid, _idx} ->
        query_chain(base_lens, cid, data_type, limit, _idx, retries, retry_delay)
      end, timeout: 30000, max_concurrency: concurrency)
      |> Enum.map(fn
        {:ok, r} -> r
        {:exit, r} -> {:error, "Worker exited: " <> inspect(r)}
      end)

    {successes, errors} = Enum.split_with(results, fn
      {:ok, _, _} -> true
      _ -> false
    end)

    normalized = successes
      |> Enum.map(fn {:ok, cid, data} ->
        %{chain_id: cid, chain_name: chain_name(cid), data: data}
      end)
      |> Enum.sort_by(fn %{chain_id: id} -> id end)

    %{
      aggregated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      total_chains: length(chains),
      successful_chains: length(normalized),
      failed_chains: length(errors),
      data_type: data_type,
      chains: normalized,
      errors: errors
    } |> then(&{:ok, &1})
  end

  @doc "Queries a single chain with retry logic."
  def query_chain(_bl, _cid, _dt, _l, _i, 0, _d), do: {:error, "Max retries exceeded"}

  def query_chain(bl, cid, dt, l, i, retries, delay) do
    case build_and_execute_query(bl, cid, dt, l, i) do
      {:ok, r} -> {:ok, cid, r}
      {:error, _} when retries > 0 ->
        :timer.sleep(delay)
        query_chain(bl, cid, dt, l, i, retries - 1, delay)
      {:error, reason} -> {:error, cid, reason}
    end
  end

  @doc "Builds and executes the API query."
  def build_and_execute_query(bl, cid, dt, limit, _idx) do
    api_params = bl.params
      |> Map.put(:chainid, cid)
      |> Map.put(:module, mod_for(dt))
      |> Map.put(:action, act_for(dt))
      |> maybe_put_limit(limit)
    url = build_url(bl, cid, api_params)
    case Req.get(url, params: api_params, headers: bl.headers, retry: :transient, max_retries: 2) do
      {:ok, %{status: 200, body: b}} -> {:ok, transform_response(b, dt)}
      {:ok, %{status: s, body: b}} -> {:error, "HTTP " <> to_string(s) <> ": " <> inspect(b)}
      {:error, %Req.TransportError{reason: r}} -> {:error, "Connection error: " <> inspect(r)}
      {:error, r} -> {:error, "Request failed: " <> inspect(r)}
    end
  end

  @doc "Builds the full API URL."
  def build_url(_bl, cid, p), do:
    "https://api.etherscan.io/v2/api?chainid=" <> to_string(cid) <> "&module=" <> to_string(p[:module]) <> "&action=" <> to_string(p[:action]) <> "&apikey=" <> to_string(p[:apikey])

  @doc "Transforms the raw API response."
  def transform_response(response, data_type) do
    case Base.process_response(response) do
      {:ok, %{result: r}} -> {:ok, do_normalize(data_type, r)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_normalize("blocks", r), do: normalize_blocks(r)
  defp do_normalize("block_rewards", r), do: normalize_block_rewards(r)
  defp do_normalize("tx_status", r), do: normalize_tx_status(r)
  defp do_normalize("token_balances", r), do: normalize_token_balances(r)
  defp do_normalize("event_logs", r), do: normalize_event_logs(r)
  defp do_normalize("gas_prices", r), do: normalize_gas_prices(r)
  defp do_normalize("account_balances", r), do: normalize_account_balances(r)
  defp do_normalize("account_transactions", r), do: normalize_account_transactions(r)
  defp do_normalize(_, r), do: r

  defp normalize_blocks(r) when is_list(r), do:
    Enum.map(r, fn b -> %{block_number: Map.get(b,"blockNumber",""), timestamp: Map.get(b,"timeStamp",""), hash: Map.get(b,"hash",""), gas_used: Map.get(b,"gasUsed",""), gas_limit: Map.get(b,"gasLimit","")} end)
  defp normalize_blocks(r) when is_binary(r), do: %{block_number: r}
  defp normalize_blocks(r) when is_map(r), do:
    %{block_number: Map.get(r,"blockNumber",""), timestamp: Map.get(r,"timeStamp","")}

  defp normalize_block_rewards(r) when is_map(r), do:
    %{block_number: Map.get(r,"blockNumber"), timestamp: Map.get(r,"timeStamp"), miner: Map.get(r,"blockMiner"), reward: Map.get(r,"blockReward"), uncles: Map.get(r,"uncles",[])}

  defp normalize_tx_status(r) when is_map(r) do
    s = Map.get(r,"isError","0")
    %{status: s, is_error: s == "1", error_message: Map.get(r,"errDescription","")}
  end

  defp normalize_token_balances(r) when is_list(r), do:
    Enum.map(r, fn i -> %{contract_address: Map.get(i,"contractAddress",""), token_name: Map.get(i,"tokenName",""), token_symbol: Map.get(i,"tokenSymbol",""), balance: Map.get(i,"balance","")} end)

  defp normalize_event_logs(r) when is_list(r), do:
    Enum.map(r, fn l -> %{address: Map.get(l,"address",""), topics: Map.get(l,"topics",[]), data: Map.get(l,"data",""), block_number: Map.get(l,"blockNumber",""), transaction_hash: Map.get(l,"transactionHash","")} end)

  defp normalize_gas_prices(r) when is_map(r), do:
    %{safe_gas_price: Map.get(r,"SafeGasPrice",""), propose_gas_price: Map.get(r,"ProposeGasPrice",""), fast_gas_price: Map.get(r,"FastGasPrice",""), last_block: Map.get(r,"LastBlock","")}

  defp normalize_account_balances(r) when is_binary(r), do: %{balance: r}

  defp normalize_account_transactions(r) when is_list(r), do:
    Enum.map(r, fn t -> %{hash: Map.get(t,"hash",""), block_number: Map.get(t,"blockNumber",""), timestamp: Map.get(t,"timeStamp",""), from: Map.get(t,"from",""), to: Map.get(t,"to",""), value: Map.get(t,"value",""), gas: Map.get(t,"gas",""), gas_price: Map.get(t,"gasPrice",""), tx_status: Map.get(t,"isError","0"), gas_used: Map.get(t,"gasUsed","")} end)

  defp chain_name(1), do: "Ethereum"
  defp chain_name(56), do: "BNB Smart Chain"
  defp chain_name(137), do: "Polygon"
  defp chain_name(42161), do: "Arbitrum"
  defp chain_name(10), do: "Optimism"
  defp chain_name(43114), do: "Avalanche C-Chain"
  defp chain_name(250), do: "Fantom"
  defp chain_name(8453), do: "Base"
  defp chain_name(id), do: "Unknown (chainid: " <> to_string(id) <> ")"

  defp mod_for("blocks"), do: "block"
  defp mod_for("block_rewards"), do: "block"
  defp mod_for("tx_status"), do: "transaction"
  defp mod_for("token_balances"), do: "token"
  defp mod_for("token_transfers"), do: "token"
  defp mod_for("event_logs"), do: "logs"
  defp mod_for("gas_prices"), do: "gastracker"
  defp mod_for("account_balances"), do: "account"
  defp mod_for("account_transactions"), do: "account"
  defp mod_for(_), do: "stats"

  defp act_for("blocks"), do: "getblocks"
  defp act_for("block_rewards"), do: "getblockreward"
  defp act_for("tx_status"), do: "getstatus"
  defp act_for("token_balances"), do: "tokentx"
  defp act_for("token_transfers"), do: "tokentx"
  defp act_for("event_logs"), do: "getLogs"
  defp act_for("gas_prices"), do: "gasoracle"
  defp act_for("account_balances"), do: "balance"
  defp act_for("account_transactions"), do: "txlist"
  defp act_for(_), do: ""

  defp validate_chains(params) do
    chains = Map.get(params, :chains, [])
    valid = [1, 56, 137, 42161, 10, 43114, 250, 8453, 42220, 1329]
    vc = Enum.filter(chains, fn c -> c in valid end)
    if Enum.empty?(vc), do: raise ArgumentError, "No valid chains. Supported: " <> inspect(valid)
    Map.put(params, :chains, vc)
  end

  defp maybe_put_limit(p, l), do: p |> maybe_put_ps(l) |> maybe_put_cnt(l)
  defp maybe_put_ps(p, l), do: case Map.get(p, :module) do "token" -> Map.put(p, :pagesize, l); _ -> p end
  defp maybe_put_cnt(p, l), do: case Map.get(p, :module) do "block" -> Map.put(p, :count, l); _ -> p end
end
