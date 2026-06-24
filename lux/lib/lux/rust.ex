defmodule Lux.Rust do
  @moduledoc """
  Rust NIF bindings for Lux high-performance operations.

  Provides FFI bindings to Rust native code compiled under `priv/rust/`.

  ## Examples

      iex> Lux.Rust.add(1, 2)
      3

      iex> Lux.Rust.string_length("hello")
      5
  """

  @on_load :load_nif

  def load_nif do
    nif_file = Application.app_dir(:lux, "priv/rust/target/release/liblux_nif")
    |> Path.expand()

    case :erlang.load_nif(to_charlist(nif_file), 0) do
      :ok -> :ok
      {:error, {:reload, _}} -> :ok
      {:error, reason} ->
        Logger.warning("Failed to load Rust NIF: #{inspect(reason)}. Rust operations unavailable.")
        :ok
    end
  end

  @doc """
  Adds two integers using Rust native code.
  """
  def add(_a, _b), do: raise("NIF not loaded")

  @doc """
  Returns the length of a string using Rust native code.
  """
  def string_length(_s), do: raise("NIF not loaded")

  @doc """
  Parses a JSON string using Rust's serde library.
  """
  def json_parse(_input), do: raise("NIF not loaded")
end
