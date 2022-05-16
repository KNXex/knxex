defmodule KNXexIP.DPT.Decoder do
  @moduledoc false

  # Most of the decoder and encoder code has been verbatim copied
  # from the KNXnet/IP library, so a huge shootout for them.
  # (Basically all, except 21.*+ implementations)

  defmacro __before_compile__(_env) do
    quote do
      def decode(data, dpt), do: unquote(__MODULE__).decode(data, dpt)
    end
  end

  defguardp is_digit(value) when is_integer(value) and value >= 0 and value <= 9

  defguardp is_integer_between(value, min, max)
            when is_integer(value) and value >= min and value <= max

  @doc """
  Decodes the value according to the DPT.
  """
  @spec decode(binary(), String.t()) :: {:ok, term()} | {:error, term()}
  def decode(value, datapoint_type)

  def decode(<<_start::5, 0::1>>, <<"1.", _rest::binary>>), do: {:ok, false}
  def decode(<<_start::5, 1::1>>, <<"1.", _rest::binary>>), do: {:ok, true}
  def decode(<<_start::7, 0::1>>, <<"1.", _rest::binary>>), do: {:ok, false}
  def decode(<<_start::7, 1::1>>, <<"1.", _rest::binary>>), do: {:ok, true}

  def decode(<<_start::4, c::1, v::1>>, <<"2.", _rest::binary>>), do: {:ok, {c, v}}

  def decode(<<_start::2, c::1, stepcode::3>>, <<"3.", _rest::binary>>), do: {:ok, {c, stepcode}}
  def decode(<<_start::4, c::1, stepcode::3>>, <<"3.", _rest::binary>>), do: {:ok, {c, stepcode}}

  def decode(<<_start::1, _char::7>> = byte, "4.001"), do: {:ok, byte}

  def decode(<<_char::8>> = byte, "4.002") do
    utf8_binary = :unicode.characters_to_binary(byte, :latin1)
    {:ok, utf8_binary}
  end

  def decode(<<0::6>>, <<"5.", _rest::binary>>), do: {:ok, 0}
  def decode(<<number::8>>, <<"5.", _rest::binary>>), do: {:ok, number}

  def decode(<<a::1, b::1, c::1, d::1, e::1, f::3>>, "6.020")
      when f === 0 or f === 2 or f === 4 do
    {:ok, {a, b, c, d, e, f}}
  end

  def decode(<<number::8-integer-signed>>, <<"6.", _rest::binary>>), do: {:ok, number}

  def decode(<<number::16>>, <<"7.", _rest::binary>>), do: {:ok, number}

  def decode(<<0::6>>, <<"8.", _rest::binary>>), do: {:ok, 0}
  def decode(<<0::8>>, <<"8.", _rest::binary>>), do: {:ok, 0}
  def decode(<<number::16-integer-signed>>, <<"8.", _rest::binary>>), do: {:ok, number}

  def decode(<<0::6>>, <<"9.", _rest::binary>>), do: {:ok, 0}
  def decode(<<0::8>>, <<"9.", _rest::binary>>), do: {:ok, 0}

  def decode(<<sign::1, exponent::4, mantissa::11>>, <<"9.", _rest::binary>>) do
    <<decoded_mantissa::12-integer-signed>> = <<sign::1, mantissa::11>>
    decoded = 0.01 * decoded_mantissa * :math.pow(2, exponent)
    {:ok, decoded}
  end

  def decode(
        <<day::3, hour::5, _rest::2, minutes::6, _rest2::2, seconds::6>>,
        <<"10.", _rest3::binary>>
      )
      when is_integer_between(day, 0, 7) and is_integer_between(hour, 0, 23) and
             is_integer_between(minutes, 0, 59) and is_integer_between(seconds, 0, 59) do
    {:ok, {day, hour, minutes, seconds}}
  end

  def decode(<<0::3, day::5, 0::4, month::4, 0::1, year::7>>, <<"11.", _rest::binary>>)
      when is_integer_between(day, 1, 31) and is_integer_between(month, 1, 12) and
             is_integer_between(year, 0, 99) do
    century = if year >= 90, do: 1900, else: 2000
    {:ok, {day, month, century + year}}
  end

  def decode(<<0::6>>, <<"12.", _rest::binary>>), do: {:ok, 0}
  def decode(<<0::8>>, <<"12.", _rest::binary>>), do: {:ok, 0}
  def decode(<<number::32>>, <<"12.", _rest::binary>>), do: {:ok, number}

  def decode(<<0::6>>, <<"13.", _rest::binary>>), do: {:ok, 0}
  def decode(<<0::8>>, <<"13.", _rest::binary>>), do: {:ok, 0}
  def decode(<<number::32-integer-signed>>, <<"13.", _rest::binary>>), do: {:ok, number}

  def decode(<<0::6>>, <<"14.", _rest::binary>>), do: {:ok, 0}
  def decode(<<0::8>>, <<"14.", _rest::binary>>), do: {:ok, 0}
  def decode(<<number::32-float>>, <<"14.", _rest::binary>>), do: {:ok, number}

  def decode(
        <<d6::4, d5::4, d4::4, d3::4, d2::4, d1::4, e::1, p::1, d::1, c::1, index::4>>,
        <<"15.", _rest::binary>>
      )
      when is_digit(d6) and is_digit(d5) and is_digit(d4) and is_digit(d3) and is_digit(d2) and
             is_digit(d1) do
    {:ok, {d6, d5, d4, d3, d2, d1, e, p, d, c, index}}
  end

  def decode(<<0::6>>, <<"16.", _rest::binary>>), do: {:ok, ""}
  def decode(<<0::8>>, <<"16.", _rest::binary>>), do: {:ok, ""}

  def decode(characters, "16.000") when byte_size(characters) == 14 do
    case ascii?(characters) do
      true ->
        {:ok, String.trim_trailing(characters, <<0>>)}

      _any ->
        {:error,
         {:datapoint_encode_error, characters, "16.000", "must only contain ASCII characters"}}
    end
  end

  def decode(characters, "16.001") when byte_size(characters) == 14 do
    case :unicode.characters_to_binary(characters, :latin1, :utf8) do
      {:error, _as_utf8, _rest} ->
        {:error,
         {:datapoint_encode_error, characters, "16.001", "could not convert characters to utf8"}}

      {:incomplete, _as_utf8, _rest} ->
        {:error,
         {:datapoint_encode_error, characters, "16.001", "could not convert characters to utf8"}}

      as_utf8 ->
        {:ok, String.trim_trailing(as_utf8, <<0>>)}
    end
  end

  def decode(<<_reserved::2, scene_number::6>>, <<"17.", _rest::binary>>) do
    {:ok, scene_number}
  end

  def decode(<<c::1, _reserved::1, scene_number::6>>, <<"18.", _rest::binary>>) do
    {:ok, {c, scene_number}}
  end

  def decode(
        <<year::8, _reserved::4, month::4, _reserved2::3, day::5, _weekday::3, hour::5,
          _reserved3::2, mins::6, _reserved4::2, secs::6, fault::1, _wd::1, _nwd::1, ny::1, nd::1,
          _ndow::1, nt::1, suti::1, clq::1, _reserved5::bitstring>>,
        <<"19.", _rest::binary>>
      ) do
    datetime =
      if ny == 0 and nd == 0 and nt == 0 do
        case NaiveDateTime.new(year + 1900, month, day, hour, mins, secs) do
          {:ok, ndt} -> ndt
          _else -> :invalid_date_and_time
        end
      else
        :invalid_date_and_time
      end

    {:ok, {{boolify(fault), boolify(suti), boolify(clq)}, datetime}}
  end

  def decode(<<0::6>>, <<"20.", _rest::binary>>), do: {:ok, 0}
  def decode(<<enum::8>>, <<"20.", _rest::binary>>), do: {:ok, enum}

  def decode(<<_any::8>> = bitstr, <<"21.", _rest::binary>>),
    do: {:ok, List.to_tuple(bitstring_to_bits(bitstr))}

  def decode(<<_any::16>> = bitstr, <<"22.", _rest::binary>>),
    do: {:ok, List.to_tuple(bitstring_to_bits(bitstr))}

  def decode(<<_start::4, a::1, b::1>>, <<"23.", _rest::binary>>), do: {:ok, {a, b}}

  def decode(characters, <<"24.", _rest::binary>>),
    do: {:ok, String.trim_trailing(characters, <<0>>)}

  def decode(<<0::6>>, <<"25.", _rest::binary>>), do: {:ok, 0}
  def decode(<<enum::8>>, <<"25.", _rest::binary>>), do: {:ok, enum}

  def decode(<<_reserved::1, active::1, scene_number::6>>, <<"26.", _rest::binary>>),
    do: {:ok, {active, scene_number}}

  def decode(bitstr, <<"27.", _rest::binary>>) when byte_size(bitstr) == 4 do
    {state, mask} =
      bitstr
      |> bitstring_to_bits()
      |> Enum.split(16)

    {:ok, mask_onoff_state(state, mask)}
  end

  def decode(characters, <<"28.", _rest::binary>>),
    do: {:ok, String.trim_trailing(characters, <<0>>)}

  def decode(<<value::64-signed>>, <<"29.", _rest::binary>>), do: {:ok, value}

  def decode(
        <<lognum::8, priority::8, app_area::8, error_class::8, attributes::8, alstatus_attr::8>>,
        <<"219.", _rest::binary>>
      ),
      do: {:ok, {lognum, priority, app_area, error_class, attributes, alstatus_attr}}

  def decode(value, datapoint_type) do
    {:error,
     {:datapoint_decode_error, value, datapoint_type, "no match found for given datapoint type"}}
  end

  defp ascii?(bytes) do
    bytes
    |> String.to_charlist()
    |> Enum.any?(fn c -> c > 127 end)
    |> Kernel.not()
  end

  defp boolify(1), do: true
  defp boolify(0), do: false

  defp bitstring_to_bits(bitstr) when is_bitstring(bitstr) do
    for <<bit::1 <- bitstr>> do
      bit
    end
    |> Enum.reverse()
  end

  defp mask_onoff_state([], []), do: []

  defp mask_onoff_state([on_off | tl1], [mask | tl2]),
    do: [{on_off, mask} | mask_onoff_state(tl1, tl2)]
end
