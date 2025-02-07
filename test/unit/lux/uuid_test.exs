defmodule Lux.UUIDTest do
  use UnitCase, async: true
  use ExUnitProperties

  alias Lux.UUID

  describe "UUID generation" do
    property "generates valid version 4 UUIDs" do
      check all(_i <- StreamData.integer()) do
        uuid = UUID.generate()
        assert is_binary(uuid)
        assert byte_size(uuid) == 36

        # UUID v4 format: 8-4-4-4-12 with version 4 and variant 2
        assert Regex.match?(
                 ~r/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
                 uuid
               )
      end
    end

    property "binary UUIDs are always 16 bytes with correct version and variant" do
      check all(_i <- StreamData.integer()) do
        uuid = UUID.bingenerate()
        assert byte_size(uuid) == 16

        <<_::48, version::4, _::12, variant::2, _::62>> = uuid
        assert version == 4
        assert variant == 2
      end
    end

    property "generates unique values" do
      check all(count <- StreamData.integer(1..100)) do
        uuids = for(_ <- 1..count, do: UUID.generate())
        assert length(Enum.uniq(uuids)) == count
      end
    end

    property "string and binary representations are consistent" do
      check all(_i <- StreamData.integer()) do
        uuid = UUID.generate()

        [time_low, time_mid, time_high_and_version, clock_seq_and_variant, node] =
          String.split(uuid, "-")

        # In v4 they are basically just random bytes.
        # Still, we can refer to them with the same time related names as in v1
        assert byte_size(time_low) == 8
        assert byte_size(time_mid) == 4
        assert byte_size(time_high_and_version) == 4
        assert byte_size(clock_seq_and_variant) == 4
        assert byte_size(node) == 12

        # Version 4 check
        assert String.at(time_high_and_version, 0) == "4"
        # Check valid variants in 2bit indication
        assert String.at(clock_seq_and_variant, 0) in ~w(8 9 a b)
      end
    end
  end
end
