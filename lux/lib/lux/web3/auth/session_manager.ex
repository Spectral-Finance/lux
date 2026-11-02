defmodule Lux.Web3.Auth.SessionManager do
  @moduledoc """
  Manages Web3 user sessions, cryptographic session token issuance, validation,
  multi-device tracking, sliding expiration, and revocation.
  """

  use GenServer

  @default_ttl_seconds 86_400
  @token_secret "lux_web3_auth_secret_key_fixed_salt_default"

  @type session :: %{
          session_id: String.t(),
          address: String.t(),
          chain_id: pos_integer(),
          roles: list(atom()),
          created_at: DateTime.t(),
          expires_at: DateTime.t(),
          last_active_at: DateTime.t(),
          revoked: boolean(),
          ip: String.t() | nil,
          user_agent: String.t() | nil,
          metadata: map()
        }

  # --- Client API ---

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Creates a new session for an authenticated Web3 address.
  Returns {:ok, %{token: token, session: session}}
  """
  @spec create_session(String.t(), keyword(), atom() | pid()) :: {:ok, map()} | {:error, term()}
  def create_session(address, opts \\ [], server \\ __MODULE__) when is_binary(address) do
    clean_address = String.downcase(address)
    now = Keyword.get(opts, :as_of, DateTime.utc_now())
    ttl = Keyword.get(opts, :ttl, @default_ttl_seconds)
    expires_at = DateTime.add(now, ttl, :second)
    chain_id = Keyword.get(opts, :chain_id, 1)
    roles = Keyword.get(opts, :roles, [:user])
    ip = Keyword.get(opts, :ip)
    user_agent = Keyword.get(opts, :user_agent)
    metadata = Keyword.get(opts, :metadata, %{})

    session_id = generate_session_id()

    session = %{
      session_id: session_id,
      address: clean_address,
      chain_id: chain_id,
      roles: roles,
      created_at: now,
      expires_at: expires_at,
      last_active_at: now,
      revoked: false,
      ip: ip,
      user_agent: user_agent,
      metadata: metadata
    }

    token = generate_signed_token(session)

    if server_alive?(server) do
      GenServer.call(server, {:store_session, session})
    end

    {:ok, %{token: token, session: session}}
  end

  @doc """
  Validates a session token or session ID.
  Checks signature integrity, expiry, and revocation status.
  """
  @spec validate_session(String.t(), keyword(), atom() | pid()) :: {:ok, session()} | {:error, atom()}
  def validate_session(token_or_id, opts \\ [], server \\ __MODULE__) when is_binary(token_or_id) do
    now = Keyword.get(opts, :as_of, DateTime.utc_now())

    with {:ok, payload} <- extract_payload(token_or_id) do
      session_id = payload[:session_id] || payload["session_id"] || token_or_id

      # Fetch stored session from GenServer if available
      session =
        if server_alive?(server) do
          GenServer.call(server, {:get_session, session_id})
        else
          # Fallback reconstruction from token payload
          reconstruct_from_payload(payload, now)
        end

      case session do
        nil ->
          {:error, :session_not_found}

        %{revoked: true} ->
          {:error, :session_revoked}

        %{expires_at: exp} = s ->
          if DateTime.compare(now, exp) == :gt do
            {:error, :session_expired}
          else
            # Update last_active_at
            updated = %{s | last_active_at: now}
            if server_alive?(server), do: GenServer.cast(server, {:update_session, updated})
            {:ok, updated}
          end
      end
    end
  end

  @doc """
  Revokes an active session by its ID.
  """
  @spec revoke_session(String.t(), atom() | pid()) :: :ok
  def revoke_session(session_id, server \\ __MODULE__) when is_binary(session_id) do
    if server_alive?(server) do
      GenServer.call(server, {:revoke_session, session_id})
    else
      :ok
    end
  end

  @doc """
  Revokes all active sessions for a specific wallet address.
  """
  @spec revoke_all_for_address(String.t(), atom() | pid()) :: :ok
  def revoke_all_for_address(address, server \\ __MODULE__) when is_binary(address) do
    clean_addr = String.downcase(address)

    if server_alive?(server) do
      GenServer.call(server, {:revoke_all, clean_addr})
    else
      :ok
    end
  end

  @doc """
  Lists active sessions for a given address.
  """
  @spec list_active_sessions(String.t(), atom() | pid()) :: list(session())
  def list_active_sessions(address, server \\ __MODULE__) when is_binary(address) do
    clean_addr = String.downcase(address)

    if server_alive?(server) do
      GenServer.call(server, {:list_sessions, clean_addr})
    else
      []
    end
  end

  # --- Token Generation & Signature ---

  @doc """
  Generates a cryptographically signed HMAC-SHA256 bearer token from a session.
  """
  @spec generate_signed_token(session()) :: String.t()
  def generate_signed_token(%{session_id: sid, address: addr, chain_id: chain, expires_at: exp, roles: roles}) do
    payload_map = %{
      sid: sid,
      sub: addr,
      cid: chain,
      exp: DateTime.to_unix(exp),
      rol: Enum.map(roles, &to_string/1)
    }

    payload_json = Jason_or_term(payload_map)
    encoded_payload = Base.url_encode64(payload_json, padding: false)
    signature = hmac_sign(encoded_payload)

    "#{encoded_payload}.#{signature}"
  end

  @doc """
  Decodes and verifies a signed bearer token.
  """
  @spec verify_token(String.t()) :: {:ok, map()} | {:error, atom()}
  def verify_token(token) when is_binary(token) do
    case String.split(token, ".") do
      [encoded_payload, signature] ->
        expected_sig = hmac_sign(encoded_payload)

        if secure_compare(signature, expected_sig) do
          case Base.url_decode64(encoded_payload, padding: false) do
            {:ok, json_bytes} ->
              payload = parse_json_or_term(json_bytes)
              {:ok, payload}

            _ ->
              {:error, :invalid_token_encoding}
          end
        else
          {:error, :invalid_token_signature}
        end

      _ ->
        {:error, :invalid_token_format}
    end
  end

  defp extract_payload(token_or_id) do
    if String.contains?(token_or_id, ".") do
      case verify_token(token_or_id) do
        {:ok, p} ->
          {:ok, %{
            session_id: p["sid"] || p[:sid],
            address: p["sub"] || p[:sub],
            chain_id: p["cid"] || p[:cid],
            expires_at: p["exp"] || p[:exp],
            roles: Enum.map(p["rol"] || p[:rol] || [], &String.to_atom/1)
          }}

        {:error, err} ->
          {:error, err}
      end
    else
      {:ok, %{session_id: token_or_id}}
    end
  end

  defp reconstruct_from_payload(payload, _now) do
    case payload[:expires_at] do
      nil ->
        nil

      unix_exp when is_integer(unix_exp) ->
        case DateTime.from_unix(unix_exp) do
          {:ok, exp_dt} ->
            %{
              session_id: payload[:session_id],
              address: payload[:address],
              chain_id: payload[:chain_id] || 1,
              roles: payload[:roles] || [:user],
              created_at: DateTime.utc_now(),
              expires_at: exp_dt,
              last_active_at: DateTime.utc_now(),
              revoked: false,
              ip: nil,
              user_agent: nil,
              metadata: %{}
            }

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(24)
    |> Base.url_encode64(padding: false)
  end

  defp hmac_sign(data) do
    :crypto.mac(:hmac, :sha256, @token_secret, data)
    |> Base.url_encode64(padding: false)
  end

  defp secure_compare(a, b) when is_binary(a) and is_binary(b) do
    byte_size(a) == byte_size(b) and :crypto.hash_equals(a, b)
  end

  defp server_alive?(server) when is_atom(server) do
    Process.whereis(server) != nil
  end

  defp server_alive?(server) when is_pid(server) do
    Process.alive?(server)
  end

  defp server_alive?(_), do: false

  defp Jason_or_term(map) do
    # Deterministic simple JSON serializer for standard map keys
    inner =
      map
      |> Enum.sort_by(fn {k, _} -> to_string(k) end)
      |> Enum.map(fn {k, v} ->
        val_str =
          cond do
            is_integer(v) -> to_string(v)
            is_list(v) -> "[" <> Enum.map_join(v, ",", &~s("#{&1}")) <> "]"
            true -> ~s("#{v}")
          end

        ~s("#{k}":#{val_str})
      end)
      |> Enum.join(",")

    "{" <> inner <> "}"
  end

  defp parse_json_or_term(binary) do
    sid = extract_json_field(binary, "sid")
    sub = extract_json_field(binary, "sub")
    cid = extract_json_int(binary, "cid") || 1
    exp = extract_json_int(binary, "exp") || 0

    rol =
      case String.split(binary, ~s("rol":[), parts: 2) do
        [_, rest] ->
          case String.split(rest, "]", parts: 2) do
            [items, _] ->
              items
              |> String.split(",")
              |> Enum.map(&String.trim(&1, " \""))
              |> Enum.reject(&(&1 == ""))

            _ ->
              ["user"]
          end

        _ ->
          ["user"]
      end

    %{"sid" => sid, "sub" => sub, "cid" => cid, "exp" => exp, "rol" => rol}
  end

  defp extract_json_field(bin, field) do
    pattern = ~s("#{field}":")
    case String.split(bin, pattern, parts: 2) do
      [_, rest] ->
        case String.split(rest, ~s("), parts: 2) do
          [val, _] -> val
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp extract_json_int(bin, field) do
    pattern = ~s("#{field}":)
    case String.split(bin, pattern, parts: 2) do
      [_, rest] ->
        case Regex.run(~r/^\d+/, rest) do
          [val] -> String.to_integer(val)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  # --- GenServer Implementation ---

  @impl true
  def init(_opts) do
    {:ok, %{sessions: %{}}}
  end

  @impl true
  def handle_call({:store_session, session}, _from, state) do
    new_sessions = Map.put(state.sessions, session.session_id, session)
    {:reply, :ok, %{state | sessions: new_sessions}}
  end

  @impl true
  def handle_call({:get_session, session_id}, _from, state) do
    {:reply, Map.get(state.sessions, session_id), state}
  end

  @impl true
  def handle_call({:revoke_session, session_id}, _from, state) do
    new_sessions =
      case Map.get(state.sessions, session_id) do
        nil -> state.sessions
        session -> Map.put(state.sessions, session_id, %{session | revoked: true})
      end

    {:reply, :ok, %{state | sessions: new_sessions}}
  end

  @impl true
  def handle_call({:revoke_all, address}, _from, state) do
    new_sessions =
      state.sessions
      |> Enum.map(fn {sid, sess} ->
        if sess.address == address do
          {sid, %{sess | revoked: true}}
        else
          {sid, sess}
        end
      end)
      |> Enum.into(%{})

    {:reply, :ok, %{state | sessions: new_sessions}}
  end

  @impl true
  def handle_call({:list_sessions, address}, _from, state) do
    active =
      state.sessions
      |> Map.values()
      |> Enum.filter(fn sess -> sess.address == address and not sess.revoked end)

    {:reply, active, state}
  end

  @impl true
  def handle_cast({:update_session, session}, state) do
    new_sessions = Map.put(state.sessions, session.session_id, session)
    {:noreply, %{state | sessions: new_sessions}}
  end
end
