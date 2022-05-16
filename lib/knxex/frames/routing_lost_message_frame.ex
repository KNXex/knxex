defmodule KNXex.Frames.RoutingLostMessageFrame do
  @moduledoc """
  KNX Routing Lost Message Frame.
  """

  alias KNXex
  alias KNXex.Constants

  @typedoc """
  Represents a KNX Routing Lost Message frame.
  """
  @type t :: %__MODULE__{
          device_state: non_neg_integer(),
          num_lost_messages: non_neg_integer()
        }

  @fields [:device_state, :num_lost_messages]
  @enforce_keys @fields
  defstruct @fields

  #### Private API ####

  # Inlined into KNXex.FrameDecoder
  @doc false
  @spec __using__(any()) :: Macro.t()
  defmacro __using__(_any) do
    quote location: :keep do
      def decode_frame(
            Constants.macro_by_name(:knx, :protocol_version_10),
            Constants.macro_assert_name(:request_type, :routing_lost_message),
            <<_structure_length::size(8), device_state::size(8), num_lost_messages::size(16),
              _rest::binary>>
          ) do
        {:ok,
         %KNXex.Frames.RoutingLostMessageFrame{
           device_state: device_state,
           num_lost_messages: num_lost_messages
         }}
      end
    end
  end
end
