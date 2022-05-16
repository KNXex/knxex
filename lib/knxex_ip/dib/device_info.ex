defmodule KNXexIP.DIB.DeviceInfo do
  @moduledoc """
  KNXnet/IP Data Information Block "Device Info".
  """

  alias KNXexIP

  @typedoc """
  KNX medium type. Twisted Pair, IP, Radio Frequency, or Powerline.
  """
  @type medium :: :tp | :ip | :rf | :pl | :unknown

  @typedoc """
  Represents a KNX Device Info.

  The Device Status bitfield only contains the programming mode on bit 0.
  """
  @type t :: %__MODULE__{
          name: String.t(),
          status: non_neg_integer(),
          medium: medium(),
          address: KNXexIP.IndividualAddress.t(),
          project_installation_id: non_neg_integer(),
          serialnum: non_neg_integer(),
          multicast_ip: :inet.ip4_address(),
          mac_addr: [byte()]
        }

  @fields [
    :name,
    :status,
    :medium,
    :address,
    :project_installation_id,
    :serialnum,
    :multicast_ip,
    :mac_addr
  ]
  @enforce_keys @fields
  defstruct @fields
end
