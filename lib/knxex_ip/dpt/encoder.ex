defmodule KNXexIP.DPT.Encoder do
  @moduledoc false

  # Most of the decoder and encoder code has been verbatim copied
  # from the KNXnet/IP library, so a huge shootout for them.
  # (Basically all, except 21.*+ implementations)

  defmacro __before_compile__(_env) do
    quote do
      @doc """
      Encodes the value according to the DPT.
      """
      @spec encode(term(), String.t()) :: {:ok, binary()} | {:error, term()}
      def encode(data, dpt), do: unquote(__MODULE__).encode(data, dpt)
    end
  end

  defguardp is_digit(value) when is_integer(value) and value >= 0 and value <= 9
  defguardp is_bit(value) when value === 0 or value === 1

  defguardp is_integer_between(value, min, max)
            when is_integer(value) and value >= min and value <= max

  defguardp is_float_between(value, min, max)
            when is_float(value) and value >= min and value <= max

  @spec encode(term(), String.t()) :: {:ok, binary()} | {:error, term()}
  def encode(value, datapoint_type)

  def encode(false, <<"1.", _rest::binary>>), do: {:ok, <<0::5, 0::1>>}
  def encode(true, <<"1.", _rest::binary>>), do: {:ok, <<0::5, 1::1>>}

  def encode({c, v}, <<"2.", _rest::binary>>)
      when is_bit(c) and is_bit(v) do
    {:ok, <<0::4, c::1, v::1>>}
  end

  def encode({c, stepcode}, <<"3.", _rest::binary>>)
      when is_bit(c) and is_integer_between(stepcode, 0, 7) do
    {:ok, <<0::2, c::1, stepcode::3>>}
  end

  def encode(<<0::1, _char::7>> = byte, "4.001") do
    {:ok, byte}
  end

  def encode(<<char::utf8>> = bytes, "4.002")
      when char <= 255 do
    as_latin1 = :unicode.characters_to_binary(bytes, :utf8, :latin1)
    {:ok, as_latin1}
  end

  def encode(number, <<"5.", _rest::binary>>)
      when is_integer_between(number, 0, 255) do
    {:ok, <<number::8>>}
  end

  def encode({a, b, c, d, e, f}, "6.020")
      when is_bit(a) and is_bit(b) and is_bit(c) and is_bit(d) and is_bit(e) and
             (f === 0 or f === 2 or f === 4) do
    {:ok, <<a::1, b::1, c::1, d::1, e::1, f::3>>}
  end

  def encode(number, <<"6.", _rest::binary>>)
      when is_integer_between(number, -128, 127) do
    {:ok, <<number::8-integer-signed>>}
  end

  def encode(number, <<"7.", _rest::binary>>)
      when is_integer_between(number, 0, 65_535) do
    {:ok, <<number::16>>}
  end

  def encode(number, <<"8.", _rest::binary>>)
      when is_integer_between(number, -32_768, 32_767) do
    {:ok, <<number::16-integer-signed>>}
  end

  def encode(number, <<"9.", _rest::binary>>)
      when is_float_between(number, -671_088.64, 670_760.96) do
    encoded = encode_16bit_float(number * 100, 0)
    {:ok, encoded}
  end

  def encode({day, hour, minutes, seconds}, <<"10.", _rest::binary>>)
      when is_integer_between(day, 0, 7) and is_integer_between(hour, 0, 23) and
             is_integer_between(minutes, 0, 59) and is_integer_between(seconds, 0, 59) do
    {:ok, <<day::3, hour::5, 0::2, minutes::6, 0::2, seconds::6>>}
  end

  def encode({day, month, year}, <<"11.", _rest::binary>>)
      when is_integer_between(day, 1, 31) and is_integer_between(month, 1, 12) and
             is_integer_between(year, 1990, 2089) do
    century = if year < 2000, do: 1900, else: 2000
    year = year - century
    {:ok, <<0::3, day::5, 0::4, month::4, 0::1, year::7>>}
  end

  def encode(number, <<"12.", _rest::binary>>)
      when is_integer_between(number, 0, 4_294_967_295) do
    {:ok, <<number::32>>}
  end

  def encode(number, <<"13.", _rest::binary>>)
      when is_integer_between(number, -2_147_483_648, 2_147_483_647) do
    {:ok, <<number::32-integer-signed>>}
  end

  def encode(number, <<"14.", _rest::binary>>)
      when is_number(number) do
    {:ok, <<number::32-float>>}
  end

  def encode({d6, d5, d4, d3, d2, d1, e, p, d, c, index}, <<"15.", _rest::binary>>)
      when is_digit(d6) and is_digit(d5) and is_digit(d4) and is_digit(d3) and is_digit(d2) and
             is_digit(d1) and is_bit(p) and is_bit(d) and is_bit(c) and
             is_integer_between(index, 0, 15) do
    {:ok, <<d6::4, d5::4, d4::4, d3::4, d2::4, d1::4, e::1, p::1, d::1, c::1, index::4>>}
  end

  def encode(characters, "16.000")
      when is_binary(characters) and byte_size(characters) <= 14 do
    case ascii?(characters) do
      true ->
        null_bits = (14 - byte_size(characters)) * 8
        {:ok, <<characters::binary, 0::size(null_bits)>>}

      _any ->
        {:error,
         {:datapoint_encode_error, characters, "16.000", "must only contain ASCII characters"}}
    end
  end

  def encode(characters, "16.001")
      when is_binary(characters) and byte_size(characters) <= 28 do
    case :unicode.characters_to_binary(characters, :utf8, :latin1) do
      {:error, _as_latin1, _rest} ->
        {:error,
         {:datapoint_encode_error, characters, "16.001", "could not convert characters to latin1"}}

      {:incomplete, _as_latin1, _rest} ->
        {:error,
         {:datapoint_encode_error, characters, "16.001", "could not convert characters to latin1"}}

      as_latin1 ->
        null_bits = (14 - byte_size(as_latin1)) * 8
        {:ok, <<as_latin1::binary, 0::size(null_bits)>>}
    end
  end

  def encode(scene_number, <<"17.", _rest::binary>>)
      when is_integer_between(scene_number, 0, 63) do
    {:ok, <<0::2, scene_number::6>>}
  end

  def encode({c, scene_number}, <<"18.", _rest::binary>>)
      when is_bit(c) and is_integer_between(scene_number, 0, 63) do
    {:ok, <<c::1, 0::1, scene_number::6>>}
  end

  def encode({{fault, suti, clq}, :invalid_date_and_time}, <<"19.", _rest::binary>>)
      when is_boolean(fault) and is_boolean(suti) and is_boolean(clq) do
    {:ok, <<0::48, intify(fault)::1, 1::6, intify(suti)::1, intify(clq)::1, 0::7>>}
  end

  def encode({{fault, suti, clq}, %NaiveDateTime{} = ndt}, <<"19.", _rest::binary>>)
      when is_boolean(fault) and is_boolean(suti) and is_boolean(clq) do
    weekday =
      ndt
      |> NaiveDateTime.to_date()
      |> Date.day_of_week()

    {:ok,
     <<ndt.year - 1900::8, 0::4, ndt.month::4, 0::3, ndt.day::5, weekday::3, ndt.hour::5, 0::2,
       ndt.minute::6, 0::2, ndt.second::6, intify(fault)::1, 1::1, 0::5, intify(suti)::1,
       intify(clq)::1, 0::7>>}
  end

  def encode({{fault, suti, clq} = header, %DateTime{} = dt}, <<"19.", _rest::binary>>)
      when is_boolean(fault) and is_boolean(suti) and is_boolean(clq) do
    encode({header, DateTime.to_naive(dt)}, "19.")
  end

  def encode(%NaiveDateTime{} = ndt, <<"19.", _rest::binary>>) do
    encode({{false, false, false}, ndt}, "19.")
  end

  def encode(%DateTime{} = dt, <<"19.", _rest::binary>>) do
    encode({{false, false, false}, DateTime.to_naive(dt)}, "19.")
  end

  def encode(:invalid_date_and_time, <<"19.", _rest::binary>>) do
    encode({{false, false, false}, :invalid_date_and_time}, "19.")
  end

  def encode(0, <<"20.", _rest::binary>>), do: {:ok, <<0::6>>}

  def encode(enum, <<"20.", _rest::binary>>)
      when is_integer_between(enum, 1, 255) do
    {:ok, <<enum::8>>}
  end

  def encode(bittup, <<"21.", _rest::binary>>)
      when is_tuple(bittup) and tuple_size(bittup) == 8 do
    {:ok, bits_to_bitstring(bittup)}
  end

  def encode(bittup, <<"22.", _rest::binary>>)
      when is_tuple(bittup) and tuple_size(bittup) == 16 do
    {:ok, bits_to_bitstring(bittup)}
  end

  def encode({a, b}, <<"23.", _rest::binary>>)
      when is_bit(a) and is_bit(b) do
    {:ok, <<0::4, a::1, b::1>>}
  end

  def encode(characters, <<"24.", _rest::binary>>) when is_binary(characters) do
    str = <<String.trim_trailing(characters, <<0>>)::binary, 0>>
    {:ok, str}
  end

  def encode(0, <<"25.", _rest::binary>>), do: {:ok, <<0::6>>}

  def encode(enum, <<"25.", _rest::binary>>)
      when is_integer_between(enum, 1, 255) do
    {:ok, <<enum::8>>}
  end

  def encode({active, scene_number}, <<"26.", _rest::binary>>)
      when is_integer_between(active, 0, 1) and is_integer_between(scene_number, 0, 63) do
    {:ok, <<0::1, active::1, scene_number::6>>}
  end

  def encode(list, <<"27.", _rest::binary>>) when is_list(list) and length(list) == 16 do
    {state, mask} =
      Enum.reduce(list, {<<>>, <<>>}, fn {state, mask}, {st_acc, ma_acc} ->
        {<<state::1, st_acc::bitstring>>, <<mask::1, ma_acc::bitstring>>}
      end)

    {:ok, <<mask::bitstring, state::bitstring>>}
  end

  def encode(characters, <<"28.", _rest::binary>>) when is_binary(characters) do
    str = <<String.trim_trailing(characters, <<0>>)::binary, 0>>
    {:ok, str}
  end

  def encode(value, <<"29.", _rest::binary>>)
      when is_integer_between(value, -9_223_372_036_854_775_808, 9_223_372_036_854_775_807) do
    {:ok, <<value::64-signed>>}
  end

  def encode(
        {lognum, priority, app_area, error_class, attributes, alstatus_attr},
        <<"219.", _rest::binary>>
      )
      when is_integer_between(lognum, 0, 255) and is_integer_between(priority, 0, 3) and
             is_integer_between(app_area, 0, 255) and is_integer_between(error_class, 0, 255) and
             is_integer_between(attributes, 0, 15) and is_integer_between(alstatus_attr, 0, 7),
      do:
        {:ok,
         <<lognum::8, priority::8, app_area::8, error_class::8, attributes::8, alstatus_attr::8>>}

  def encode(value, datapoint_type) do
    {:error,
     {:datapoint_encode_error, value, datapoint_type, "no match found for given datapoint type"}}
  end

  defp encode_16bit_float(_number, exponent)
       when exponent < 0 or exponent > 15 do
    <<0x7F, 0xFF>>
  end

  defp encode_16bit_float(number, exponent) do
    mantissa = trunc(number / :math.pow(2, exponent))

    if mantissa >= -2048 and mantissa < 2047 do
      <<sign::1, coded_mantissa::11>> = <<mantissa::12-integer-signed>>
      <<sign::1, exponent::4, coded_mantissa::11>>
    else
      encode_16bit_float(number, exponent + 1)
    end
  end

  defp ascii?(bytes) do
    bytes
    |> String.to_charlist()
    |> Enum.any?(fn c -> c > 127 end)
    |> Kernel.not()
  end

  defp intify(true), do: 1
  defp intify(false), do: 0

  defp bits_to_bitstring(bits) when is_tuple(bits) do
    bits
    |> Tuple.to_list()
    |> Enum.reduce(<<>>, fn bit, acc ->
      <<intify(bit)::1, acc::bitstring>>
    end)
  end
end
