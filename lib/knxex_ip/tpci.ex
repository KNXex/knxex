defmodule KNXexIP.TPCI do
  @moduledoc """
  KNX Transport Layer Protocol Control Information (TPCI).

  See also <https://support.KNXexIP.org/hc/en-us/articles/115003188529-Payload>.
  """

  alias KNXexIP.Constants
  require Constants

  @typedoc """
  Defines what type of packet it is.
  """
  @type control_data :: :tl_connect | :tl_disconnect | :tl_ack | :tl_nak

  @typedoc """
  Defines the purpose of the packet and whether it contains a sequence number.
  """
  @type type ::
          :unnumbered_data
          | :numbered_data
          | :unnumbered_control
          | :numbered_control

  @typedoc """
  Represents the TPCI.
  """
  @type t :: %__MODULE__{
          type: type(),
          sequence_number: non_neg_integer() | nil,
          control_data: control_data() | nil
        }

  @fields [:type, :sequence_number, :control_data]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Creates a new TPCI struct from the raw TPCI value.
  """
  @spec make(non_neg_integer()) :: t()
  def make(tpci) when is_integer(tpci) do
    <<type::size(1), has_seqnum::size(1), _rest::bitstring>> = <<tpci>>

    seq_num =
      if has_seqnum == 1 do
        Bitwise.bsr(Bitwise.band(tpci, 0x3C), 2)
      end

    control =
      if type == 1 do
        case Bitwise.band(tpci, 0x03) do
          0x00 -> :tl_connect
          0x01 -> :tl_disconnect
          0x02 -> :tl_ack
          0x03 -> :tl_nak
        end
      else
        nil
      end

    %__MODULE__{
      type: Constants.by_value(:frame_tpci, Bitwise.band(tpci, 0x03)),
      sequence_number: seq_num,
      control_data: control
    }
  end

  @doc """
  Calculates the integer value for the given TPCI struct.
  """
  @spec to_integer(t()) :: non_neg_integer()
  def to_integer(%__MODULE__{} = tpci) do
    control =
      case tpci.control_data do
        nil -> 0x00
        :tl_connect -> 0x00
        :tl_disconnect -> 0x01
        :tl_ack -> 0x02
        :tl_nak -> 0x03
      end

    seqnum =
      if is_integer(tpci.sequence_number) do
        tpci.sequence_number
      else
        0
      end

    <<tpci_num::size(8)>> =
      <<Constants.by_name(:frame_tpci, tpci.type)::size(2), seqnum::size(4), control::size(2)>>

    tpci_num
  end
end
