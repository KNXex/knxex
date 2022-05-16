defmodule KNXex.Telegram do
  @moduledoc """
  KNX telegram.
  """

  @typedoc """
  Represents a KNX telegram.
  """
  @type t :: %__MODULE__{
          type: :group_read | :group_write | :group_response,
          source: KNXex.IndividualAddress.t(),
          destination: KNXex.GroupAddress.t(),
          value: term()
        }

  @enforce_keys [:type, :source, :destination, :value]
  defstruct [:type, :source, :destination, :value]
end
