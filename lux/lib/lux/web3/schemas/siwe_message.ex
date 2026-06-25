defmodule Lux.Web3.Schemas.SIWEMessage do
  @moduledoc """
  EIP-4361 (Sign-In with Ethereum) message builder and parser.

  SIWE messages follow the format:
  <domain> wants you to sign in with your Ethereum account:
  <address>

  I accept the Service Agreement at: <uri>

  ---
  VERSION: <version>
  STATE: <state>
  ISSUED AT: <issued_at>
  EXPIRES IN: <expires_in>
  NOT BEFORE: <not_before>
  REQUEST ID: <request_id>
  ---
  RESOURCES: <resource_uri_1>
  <resource_uri_2>
  ...
  """

  alias Lux.Web3.Schemas.AuditLog

  @type t :: %__MODULE__{
          domain: String.t(),
          address: String.t(),
          uri: String.t(),
          version: String.t(),
          statement: String.t() | nil,
          issued_at: String.t(),
          expiration_time: String.t() | nil,
          not_before: String.t() | nil,
          request_id: String.t() | nil,
          resources: [String.t()]
        }

  defstruct [
    :domain,
    :address,
    :uri,
    :version,
    :statement,
    :issued_at,
    :expiration_time,
    :not_before,
    :request_id,
    resources: []
  ]

  @doc """
  Build a SIWE message string from its components.
  """
  @spec build_message(t()) :: String.t()
  def build_message(%__MODULE__{} = msg) do
    header = build_header(msg)
    fields = build_fields(msg)
    [header, fields] |> Enum.join("\n")
  end

  @doc """
  Parse a SIWE message string into a struct.
  """
  @spec parse_message(String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse_message(message) when is_binary(message) do
    lines = String.split(message, "\n", trim: true)

    with {:ok, header_lines, rest} <- split_header(lines),
         {:ok, parsed} <- parse_fields(rest) do
      # Validate required fields
      required = [:domain, :address, :uri, :version, :issued_at]
      missing = required -- Map.keys(parsed)

      if length(missing) > 0 do
        {:error, "Missing required fields: #{inspect(missing)}"}
      else
        msg = struct!(__MODULE__, parsed)
        {:ok, msg}
      end
    end
  end

  @doc """
  Verify the temporal constraints of a SIWE message.
  """
  @spec verify_temporal_constraints(t()) :: {:ok, t()} | {:error, String.t()}
  def verify_temporal_constraints(%__MODULE__{} = msg) do
    now = DateTime.utc_now()

    with :ok <- check_not_before(msg, now),
         :ok <- check_expiration(msg, now) do
      {:ok, msg}
    end
  end

  # Internal helpers

  defp build_header(%__MODULE__{domain: d, address: a, uri: u}) do
    "#{d} wants you to sign in with your Ethereum account:\n#{a}\n\nI accept the Service Agreement at: #{u}"
  end

  defp build_fields(%__MODULE__{
         version: v,
         statement: s,
         issued_at: i,
         expiration_time: e,
         not_before: n,
         request_id: r,
         resources: res
       }) do
    parts = [
      "---\nVERSION: #{v}",
      "ISSUED AT: #{i}"
      | concat_if(s, "STATE: #{s}") ++
          concat_if(e, "EXPIRES IN: #{e}") ++
          concat_if(n, "NOT BEFORE: #{n}") ++
          concat_if(r, "REQUEST ID: #{r}") ++
          build_resources(res)
    ]

    Enum.join(parts, "\n")
  end

  defp concat_if(nil, _val), do: []
  defp concat_if(_, val), do: [val]

  defp build_resources([]), do: []
  defp build_resources(resources), do: ["RESOURCES:\n" | Enum.map(resources, & &1)]

  defp split_header(lines) do
    case lines do
      [h1, h2, "", rest | _] ->
        header = [h1, h2]
        {:ok, header, rest}

      _ ->
        {:error, "Invalid SIWE header format"}
    end
  end

  defp parse_fields(lines) do
    fields_map = %{}

    parsed =
      Enum.reduce(lines, {fields_map, false}, fn line, {acc, in_resources} ->
        cond ->
          in_resources ->
            # Accumulate resource URIs
            {Map.update!(acc, :resources, &[line | &1]), true}

          line =~ "---" ->
            {acc, true}

          line =~ "RESOURCES:" ->
            {%{acc | resources: []}, true}

          true ->
            case String.split(line, ": ", parts: 2) do
              [key, value] ->
                acc = parse_field(acc, key, value)
                {acc, false}

              _ ->
                {acc, in_resources}
            end
      end)

    case parsed do
      {acc, _} ->
        acc = Map.update!(acc, :resources, &Enum.reverse(&1))
        {:ok, acc}
    end
  rescue
    _ -> {:error, "Failed to parse SIWE message fields"}
  end

  defp parse_field(acc, "VERSION", v), do: Map.put(acc, :version, v)
  defp parse_field(acc, "STATE", s), do: Map.put(acc, :statement, s)
  defp parse_field(acc, "ISSUED AT", i), do: Map.put(acc, :issued_at, i)
  defp parse_field(acc, "EXPIRES IN", e), do: Map.put(acc, :expiration_time, e)
  defp parse_field(acc, "NOT BEFORE", n), do: Map.put(acc, :not_before, n)
  defp parse_field(acc, "REQUEST ID", r), do: Map.put(acc, :request_id, r)
  defp parse_field(acc, _, _), do: acc

  defp check_not_before(%__MODULE__{not_before: nil}, _now), do: :ok

  defp check_not_before(%__MODULE__{not_before: not_before}, now) do
    case DateTime.parse(not_before) do
      {:ok, dt} when dt.after?(now) ->
        {:error, "Message is not yet valid (Not Before: #{not_before})"}

      _ ->
        :ok
    end
  end

  defp check_expiration(%__MODULE__{expiration_time: nil}, _now), do: :ok

  defp check_expiration(%__MODULE__{expiration_time: expiration_time}, now) do
    case DateTime.parse(expiration_time) do
      {:ok, dt} when dt.before?(now) ->
        {:error, "Message has expired (Expires: #{expiration_time})"}

      _ ->
        :ok
    end
  end

  defp check_expiration(%__MODULE__{not_before: nil}, _now), do: :ok

  defp check_expiration(%__MODULE__{not_before: not_before}, now) do
    case DateTime.parse(not_before) do
      {:ok, dt} when dt.after?(now) ->
        {:error, "Message is not yet valid (Not Before: #{not_before})"}

      _ ->
        :ok
    end
  end
end
