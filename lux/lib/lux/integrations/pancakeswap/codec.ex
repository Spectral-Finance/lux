defmodule Lux.Integrations.PancakeSwap.Codec do
  @moduledoc """
  Minimal Solidity ABI encoder/decoder for the PancakeSwap contract calls.

  Supported types: `uint<N>`, `address`, `bool` and one-dimensional dynamic arrays of
  those (`address[]`, `uint256[]`). That is everything the MasterChef, router, factory,
  pair and ERC-20 calls used by the PancakeSwap prisms need.

  ## Examples

      iex> alias Lux.Integrations.PancakeSwap.Codec
      iex> Codec.to_hex(Codec.selector("transfer(address,uint256)"))
      "0xa9059cbb"
  """

  @max_uint Integer.pow(2, 256) - 1

  @doc """
  Returns the 4 byte function selector for a canonical signature.
  """
  @spec selector(String.t()) :: binary()
  def selector(signature) when is_binary(signature) do
    binary_part(ExKeccak.hash_256(signature), 0, 4)
  end

  @doc """
  Encodes a binary as a `0x` prefixed lowercase hex string.
  """
  @spec to_hex(binary()) :: String.t()
  def to_hex(binary) when is_binary(binary), do: "0x" <> Base.encode16(binary, case: :lower)

  @doc """
  Decodes a hex string, with or without the `0x` prefix.
  """
  @spec from_hex(String.t()) :: {:ok, binary()} | {:error, :invalid_hex}
  def from_hex("0x" <> hex), do: from_hex(hex)

  def from_hex(hex) when is_binary(hex) do
    padded = if rem(byte_size(hex), 2) == 1, do: "0" <> hex, else: hex

    case Base.decode16(padded, case: :mixed) do
      {:ok, binary} -> {:ok, binary}
      :error -> {:error, :invalid_hex}
    end
  end

  @doc """
  Returns the argument types of a signature such as `"deposit(uint256,uint256)"`.
  """
  @spec arg_types(String.t()) :: [String.t()]
  def arg_types(signature) do
    [_name, rest] = String.split(signature, "(", parts: 2)

    case String.trim_trailing(rest, ")") do
      "" -> []
      types -> String.split(types, ",")
    end
  end

  @doc """
  Encodes a function call: selector followed by the ABI encoded arguments.

  Raises `ArgumentError` when an argument does not match its type.
  """
  @spec encode_call(String.t(), [term()]) :: binary()
  def encode_call(signature, args) do
    types = arg_types(signature)

    if length(types) != length(args) do
      raise ArgumentError,
            "#{signature} expects #{length(types)} arguments, got #{length(args)}"
    end

    selector(signature) <> encode_args(types, args)
  end

  @doc """
  ABI encodes a list of values for the given types (head/tail layout).
  """
  @spec encode_args([String.t()], [term()]) :: binary()
  def encode_args(types, args) do
    head_size = length(types) * 32

    {heads, tails, _offset} =
      types
      |> Enum.zip(args)
      |> Enum.reduce({[], [], head_size}, fn {type, arg}, {heads, tails, offset} ->
        if dynamic?(type) do
          encoded = encode_dynamic(type, arg)
          {[word(offset) | heads], [encoded | tails], offset + byte_size(encoded)}
        else
          {[encode_static(type, arg) | heads], tails, offset}
        end
      end)

    IO.iodata_to_binary([Enum.reverse(heads), Enum.reverse(tails)])
  end

  @doc """
  Decodes the hex result of an `eth_call` into a list of values.

  Addresses are returned as lowercase `0x` strings, integers as integers and
  booleans as booleans.
  """
  @spec decode([String.t()], String.t()) :: {:ok, [term()]} | {:error, atom()}
  def decode(types, "0x" <> _ = hex) do
    with {:ok, binary} <- from_hex(hex) do
      decode_binary(types, binary)
    end
  end

  def decode(_types, _other), do: {:error, :invalid_response}

  defp decode_binary(types, data) do
    if byte_size(data) < length(types) * 32 do
      {:error, :empty_result}
    else
      types
      |> Enum.with_index()
      |> Enum.reduce_while({:ok, []}, fn {type, index}, {:ok, acc} ->
        head = binary_part(data, index * 32, 32)

        case decode_item(type, head, data) do
          {:ok, value} -> {:cont, {:ok, [value | acc]}}
          :error -> {:halt, {:error, :invalid_response}}
        end
      end)
      |> case do
        {:ok, values} -> {:ok, Enum.reverse(values)}
        error -> error
      end
    end
  end

  defp decode_item(type, head, data) do
    if dynamic?(type) do
      decode_array(String.replace_suffix(type, "[]", ""), head, data)
    else
      {:ok, decode_static(type, head)}
    end
  end

  defp decode_static("address", <<_padding::binary-size(12), address::binary-size(20)>>),
    do: to_hex(address)

  defp decode_static("bool", <<value::unsigned-big-integer-size(256)>>), do: value != 0
  defp decode_static(_uint, <<value::unsigned-big-integer-size(256)>>), do: value

  defp decode_array(base, <<offset::unsigned-big-integer-size(256)>>, data) do
    if offset + 32 <= byte_size(data) do
      <<length::unsigned-big-integer-size(256)>> = binary_part(data, offset, 32)
      decode_array_items(base, length, offset + 32, data)
    else
      :error
    end
  end

  defp decode_array_items(base, length, start, data) do
    if start + length * 32 <= byte_size(data) do
      items =
        for index <- 0..(length - 1)//1 do
          decode_static(base, binary_part(data, start + index * 32, 32))
        end

      {:ok, items}
    else
      :error
    end
  end

  defp dynamic?(type), do: String.ends_with?(type, "[]")

  defp encode_dynamic(type, list) when is_list(list) do
    base = String.replace_suffix(type, "[]", "")
    word(length(list)) <> IO.iodata_to_binary(Enum.map(list, &encode_static(base, &1)))
  end

  defp encode_dynamic(type, value),
    do: raise(ArgumentError, "cannot encode #{inspect(value)} as #{type}")

  defp encode_static("address", value), do: <<0::96>> <> address_bytes(value)
  defp encode_static("bool", true), do: word(1)
  defp encode_static("bool", false), do: word(0)

  defp encode_static("uint" <> _, value)
       when is_integer(value) and value >= 0 and value <= @max_uint,
       do: word(value)

  defp encode_static(type, value),
    do: raise(ArgumentError, "cannot encode #{inspect(value)} as #{type}")

  defp address_bytes("0x" <> hex = value) when byte_size(hex) == 40 do
    case Base.decode16(hex, case: :mixed) do
      {:ok, bytes} -> bytes
      :error -> raise ArgumentError, "invalid address: #{inspect(value)}"
    end
  end

  defp address_bytes(value), do: raise(ArgumentError, "invalid address: #{inspect(value)}")

  defp word(integer), do: <<integer::unsigned-big-integer-size(256)>>
end
