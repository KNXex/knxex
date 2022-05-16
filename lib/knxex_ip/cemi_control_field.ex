defmodule KNXexIP.CEMIControlField do
  @moduledoc """
  KNX Common External Message Interface Control Field (cEMI).

  The cEMI control field has the following structure and bit order:
  ```
  +---------------------------------------+---------------------------------------+
  | Control Field 1                       | Control Field 2                       |
  +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
  | 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
  +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
  ```

  The control field 1 has the following structure:
  ```
   Bit  |
  ------+---------------------------------------------------------------
    15  | Frame Type  - 0 = for extended frame
        |               1 = for standard frame
  ------+---------------------------------------------------------------
    14  | Reserved
        |
  ------+---------------------------------------------------------------
    13  | Repeat Flag - 0 = repeat frame on medium in case of an error (or on receive: repeated)
        |               1 = do not repeat (or on receive: not repeated)
  ------+---------------------------------------------------------------
    12  | System Broadcast - 0 = system broadcast
        |                    1 = broadcast
  ------+---------------------------------------------------------------
    11  | Priority    - 0 = system (reserved)
        |               1 = normal (also called alarm priority)
  ------+               2 = urgent (also called high priority)
    10  |               3 = low
        |
  ------+---------------------------------------------------------------
     9  | Acknowledge Request - 0 = no ACK requested
        | (L_Data.req)          1 = ACK requested
  ------+---------------------------------------------------------------
     8  | Confirm      - 0 = no error
        | (L_Data.con) - 1 = error
  ------+---------------------------------------------------------------
  ```

  The control field 2 has the following structure:
  ```
   Bit  |
  ------+---------------------------------------------------------------
     7  | Destination Address Type - 0 = individual address
        |                          - 1 = group address
  ------+---------------------------------------------------------------
   6-4  | Hop Count (0-7)
  ------+---------------------------------------------------------------
   3-0  | Extended Frame Format - 0 = standard frame
  ------+---------------------------------------------------------------
  ```
  """

  @typedoc """
  The KNX cEMI control field. It is a bitfield. See the module doc.
  """
  @type t :: non_neg_integer()

  import KNXexIP.Macro

  defconstant(:bits, :destination_address_type, 7)
  defconstant(:bits, :confirm, 8)
  defconstant(:bits, :ack_requested, 9)
  defconstant(:bits, :system_broadcast, 12)
  defconstant(:bits, :repeat_flag, 13)
  defconstant(:bits, :is_extended_frame, 15)

  # Checks if the value is a struct or an int, and checks if the bit is set (bit as integer value, i.e. bit 0 = 1).
  @spec check_bit(integer(), integer()) :: Macro.t()
  defguardp check_bit(t, value)
            when is_integer(t) and :erlang.band(t, value) > 0

  @doc """
  Checks if the given cEMI Control Field has the extended frame bit set.
  """
  defguard is_extended_frame(value)
           when not check_bit(value, 32_768)

  @doc """
  Checks if the given cEMI Control Field has the destination address type bit set to individual.
  """
  defguard is_destination_individual(value)
           when not check_bit(value, 128)

  @doc """
  Checks if the given cEMI Control Field has the destination address type bit set to group.
  """
  defguard is_destination_group(value)
           when check_bit(value, 128)

  @doc """
  Checks if the given cEMI Control Field has the error bit set (confirm = 1 => error). Only relevant for `L_Data.con` frames.
  """
  defguard has_error_bit(value)
           when check_bit(value, 256)

  @doc """
  Checks if the given cEMI Control Field has the ACK rqeuested bit set. Only relevant for `L_Data.req` frames.
  """
  defguard has_ack_requested_bit(value)
           when check_bit(value, 512)

  @doc """
  Checks if the given cEMI Control Field has the broadcast bit set.
  """
  defguard is_broadcast(value)
           when check_bit(value, 4096)

  @doc """
  Checks if the given cEMI Control Field has the do not repeat flag bit set (do not repeat on medium error).
  """
  defguard has_do_not_repeat(value)
           when check_bit(value, 8192)

  @doc """
  Explains the given control field. This returns an explain string.
  You may want to pipe the string into `IO.puts/2`.

  Example output:
  ```
  Control Field 2:
    Bit   0-3: Extended Frame Format: 0 (used for LTE)
    Bit   4-6: Hop Count: 5
    Bit     7: Destination Address Type: group

  Control Field 1:
    Bit     8: Confirm (L_Data.con): no error
    Bit     9: ACK Requested: no ACK requested
    Bit 10+11: Priority: low
    Bit    12: System Broadcast: no
    Bit    13: Do-Not-Repeat/Original Flag: yes
    Bit    14: -- reserved --
    Bit    15: Frame Type: standard
  ```
  """
  @spec explain(t()) :: String.t()
  def explain(control_field) when is_integer(control_field) do
    priority_field =
      control_field
      |> Bitwise.band(0xC00)
      |> Bitwise.bsr(10)

    priority =
      case priority_field do
        0 -> "system"
        1 -> "normal (alarm priority)"
        2 -> "urgent (high priority)"
        3 -> "low"
      end

    """
    Control Field 2:
      Bit   0-3: Extended Frame Format: #{Bitwise.band(control_field, 0xF)} (used for LTE)
      Bit   4-6: Hop Count: #{Bitwise.bsr(Bitwise.band(control_field, 0x70), 4)}
      Bit     7: Destination Address Type: #{if Bitwise.band(control_field, 128) > 0, do: "group", else: "individual"}

    Control Field 1:
      Bit     8: Confirm (L_Data.con): #{if has_error_bit(control_field), do: "error", else: "no error"}
      Bit     9: ACK Requested: #{if has_ack_requested_bit(control_field), do: "ACK requested", else: "no ACK requested"}
      Bit 10+11: Priority: #{priority}
      Bit    12: System Broadcast: #{if is_broadcast(control_field), do: "no", else: "yes"}
      Bit    13: Do-Not-Repeat/Original Flag: #{if has_do_not_repeat(control_field), do: "yes", else: "no"}
      Bit    14: -- reserved --
      Bit    15: Frame Type: #{if is_extended_frame(control_field), do: "extended", else: "standard"}
    """
  end
end
