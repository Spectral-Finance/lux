defmodule Lux.Web3.Auth.MultiSig do
  @moduledoc """
  Multi-signature authentication support for Web3.

  Enables authentication flows that require multiple wallet signatures,
  supporting use cases like:

  - Multi-sig wallet authentication (e.g., Gnosis Safe)
  - M-of-N signature requirements
  - Sequential or parallel signature collection
  - Threshold-based authentication

  ## Architecture

  Multi-sig requests are stored in ETS and track which signers have
  provided valid signatures. The request is considered complete when
  the threshold of required signatures is met.

  ## Examples

      iex> {:ok, request} = MultiSig.create_request(%{
      ...>   message: "Approve action X",
      ...>   signers: ["0xAAA...", "0xBBB...", "0xCCC..."],
      ...>   threshold: 2
      ...> })
      iex> MultiSig.add_signature(request.id, "0xAAA...", signature_a)
      {:ok, %{complete: false, signatures_count: 1, threshold: 2}}
      iex> MultiSig.add_signature(request.id, "0xBBB...", signature_b)
      {:ok, %{complete: true, signatures_count: 2, threshold: 2}}
  """

  use GenServer

  alias Lux.Web3.Auth.SignatureVerifier

  require Logger

  @type request :: %{
          id: String.t(),
          message: String.t(),
          signers: [String.t()],
          threshold: pos_integer(),
          signatures: %{String.t() => String.t()},
          created_at: DateTime.t(),
          expires_at: DateTime.t(),
          complete: boolean(),
          metadata: map()
        }

  @default_ttl 3600
  @table_name :lux_web3_multisig

  # Client API

  @doc """
  Starts the multi-sig manager.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Creates a new multi-signature request.

  ## Parameters

    * `attrs` - Map with:
      * `:message` (required) - The message to be signed
      * `:signers` (required) - List of authorized signer addresses
      * `:threshold` (required) - Number of signatures required
      * `:ttl` - Time to live in seconds (defaults to #{@default_ttl})
      * `:metadata` - Additional metadata

  ## Returns

    * `{:ok, request}` on success
    * `{:error, reason}` on validation failure
  """
  @spec create_request(map(), atom()) :: {:ok, request()} | {:error, String.t()}
  def create_request(attrs, server \\ __MODULE__) do
    GenServer.call(server, {:create_request, attrs})
  end

  @doc """
  Adds a signature to a multi-sig request.

  Verifies the signature against the message and the signer's address.

  ## Returns

    * `{:ok, %{complete: boolean(), signatures_count: integer(), threshold: integer()}}` on success
    * `{:error, reason}` on failure
  """
  @spec add_signature(String.t(), String.t(), String.t(), atom()) ::
          {:ok, map()} | {:error, String.t()}
  def add_signature(request_id, signer_address, signature, server \\ __MODULE__) do
    GenServer.call(server, {:add_signature, request_id, signer_address, signature})
  end

  @doc """
  Gets the current status of a multi-sig request.
  """
  @spec get_request(String.t(), atom()) :: {:ok, request()} | {:error, :not_found | :expired}
  def get_request(request_id, server \\ __MODULE__) do
    GenServer.call(server, {:get_request, request_id})
  end

  @doc """
  Cancels a multi-sig request.
  """
  @spec cancel_request(String.t(), atom()) :: :ok
  def cancel_request(request_id, server \\ __MODULE__) do
    GenServer.call(server, {:cancel_request, request_id})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    table = Keyword.get(opts, :table_name, @table_name)
    ^table = :ets.new(table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:create_request, attrs}, _from, state) do
    with :ok <- validate_signers(attrs[:signers]),
         :ok <- validate_threshold(attrs[:threshold], attrs[:signers]),
         :ok <- validate_message(attrs[:message]) do
      now = DateTime.utc_now()
      ttl = Map.get(attrs, :ttl, @default_ttl)

      request = %{
        id: Lux.UUID.generate(),
        message: attrs.message,
        signers: Enum.map(attrs.signers, &String.downcase/1),
        threshold: attrs.threshold,
        signatures: %{},
        created_at: now,
        expires_at: DateTime.add(now, ttl, :second),
        complete: false,
        metadata: Map.get(attrs, :metadata, %{})
      }

      :ets.insert(state.table, {request.id, request})
      Logger.info("Multi-sig request created: #{request.id} (#{attrs.threshold}-of-#{length(attrs.signers)})")
      {:reply, {:ok, request}, state}
    else
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:add_signature, request_id, signer_address, signature}, _from, state) do
    case :ets.lookup(state.table, request_id) do
      [{^request_id, request}] ->
        result = process_signature(request, signer_address, signature, state)
        {:reply, result, state}

      [] ->
        {:reply, {:error, "request not found"}, state}
    end
  end

  @impl true
  def handle_call({:get_request, request_id}, _from, state) do
    result =
      case :ets.lookup(state.table, request_id) do
        [{^request_id, request}] ->
          if DateTime.compare(DateTime.utc_now(), request.expires_at) == :lt do
            {:ok, request}
          else
            :ets.delete(state.table, request_id)
            {:error, :expired}
          end

        [] ->
          {:error, :not_found}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:cancel_request, request_id}, _from, state) do
    :ets.delete(state.table, request_id)
    {:reply, :ok, state}
  end

  # Private helpers

  defp process_signature(request, signer_address, signature, state) do
    normalized_signer = String.downcase(signer_address)

    cond do
      DateTime.compare(DateTime.utc_now(), request.expires_at) != :lt ->
        :ets.delete(state.table, request.id)
        {:error, "request has expired"}

      request.complete ->
        {:error, "request is already complete"}

      normalized_signer not in request.signers ->
        {:error, "address is not an authorized signer"}

      Map.has_key?(request.signatures, normalized_signer) ->
        {:error, "address has already signed"}

      true ->
        verify_and_record(request, normalized_signer, signature, state)
    end
  end

  defp verify_and_record(request, normalized_signer, signature, state) do
    case SignatureVerifier.verify_signature(request.message, signature, normalized_signer) do
      {:ok, true} ->
        updated_sigs = Map.put(request.signatures, normalized_signer, signature)
        sig_count = map_size(updated_sigs)
        complete = sig_count >= request.threshold

        updated = %{request | signatures: updated_sigs, complete: complete}
        :ets.insert(state.table, {request.id, updated})

        Logger.info(
          "Multi-sig signature added: #{request.id} (#{sig_count}/#{request.threshold})"
        )

        {:ok,
         %{
           complete: complete,
           signatures_count: sig_count,
           threshold: request.threshold
         }}

      {:ok, false} ->
        {:error, "signature does not match signer address"}

      {:error, reason} ->
        {:error, "signature verification failed: #{reason}"}
    end
  end

  defp validate_signers(nil), do: {:error, "signers list is required"}
  defp validate_signers([]), do: {:error, "signers list cannot be empty"}
  defp validate_signers(signers) when is_list(signers), do: :ok
  defp validate_signers(_), do: {:error, "signers must be a list"}

  defp validate_threshold(nil, _), do: {:error, "threshold is required"}

  defp validate_threshold(threshold, signers)
       when is_integer(threshold) and is_list(signers) do
    if threshold > 0 and threshold <= length(signers) do
      :ok
    else
      {:error, "threshold must be between 1 and the number of signers"}
    end
  end

  defp validate_threshold(_, _), do: {:error, "threshold must be a positive integer"}

  defp validate_message(nil), do: {:error, "message is required"}
  defp validate_message(""), do: {:error, "message cannot be empty"}
  defp validate_message(m) when is_binary(m), do: :ok
  defp validate_message(_), do: {:error, "message must be a string"}
end
