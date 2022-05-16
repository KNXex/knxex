defmodule KNXexIP.Telegram do
  @moduledoc """
  KNX telegram.
  """

  @typedoc """
  Represents a KNX telegram.
  """
  @type t :: %__MODULE__{
          type: :group_read | :group_write | :group_response,
          source: KNXexIP.IndividualAddress.t(),
          destination: KNXexIP.GroupAddress.t(),
          value: term()
        }

  @enforce_keys [:type, :source, :destination, :value]
  defstruct [:type, :source, :destination, :value]
end
