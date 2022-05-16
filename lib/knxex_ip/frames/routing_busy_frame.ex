defmodule KNXexIP.Frames.RoutingBusyFrame do
  @moduledoc """
  KNX Routing Busy Frame.
  """

  alias KNXexIP
  alias KNXexIP.Constants

  @typedoc """
  Represents a KNX Routing Busy frame.
  """
  @type t :: %__MODULE__{
          device_state: non_neg_integer(),
          busy_wait_time: non_neg_integer(),
          control_field: non_neg_integer()
        }

  @fields [:device_state, :busy_wait_time, :control_field]
  @enforce_keys @fields
  defstruct @fields

  #### Private API ####

  # Inlined into KNXexIP.FrameDecoder
  @doc false
  @spec __using__(any()) :: Macro.t()
  defmacro __using__(_any) do
    quote location: :keep do
      def decode_frame(
            Constants.macro_by_name(:knx, :protocol_version_10),
            Constants.macro_assert_name(:request_type, :routing_busy),
            <<_structure_length::size(8), device_state::size(8), busy_wait_time::size(16),
              control_field::size(16), _rest::binary>>
          ) do
        {:ok,
         %KNXexIP.Frames.RoutingBusyFrame{
           device_state: device_state,
           busy_wait_time: busy_wait_time,
           control_field: control_field
         }}
      end
    end
  end
end
