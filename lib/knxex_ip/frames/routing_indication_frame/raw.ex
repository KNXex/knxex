defmodule KNXexIP.Frames.RoutingIndicationFrame.Raw do
  @moduledoc """
  This module contains the raw data of `Routing Indication` Frames.
  That is, this struct gets used, when the message code of any other `RoutingIndicationFrame` does not match.
  """

  alias KNXexIP.Constants
  require Constants

  @typedoc """
  Represents a raw service frame.
  """
  @type t :: %__MODULE__{
          raw_data: binary()
        }

  @fields [
    :raw_data
  ]
  @enforce_keys @fields
  defstruct @fields
end
