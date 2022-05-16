defmodule KNXexIP.Frame do
  @moduledoc """
  KNX Frame. This contains a bunch of low level information from the frame.
  """

  @typedoc """
  KNX request types.
  """
  @type request_type() ::
          :search_request
          | :search_response
          | :description_request
          | :description_response
          | :connect_request
          | :connect_response
          | :connection_state_request
          | :connection_state_response
          | :disconnect_request
          | :disconnect_response
          | :device_configuration_request
          | :device_configuration_ack
          | :tunnelling_request
          | :tunnelling_ack
          | :routing_indication
          | :routing_lost_message
          | :routing_busy
          | :remote_diagnostics_request
          | :remote_diagnostics_response
          | :remote_basic_config_request
          | :remote_reset_request
          | :secure_wrapper
          | :secure_session_request
          | :secure_session_response
          | :secure_session_authenticate
          | :secure_session_status
          | :secure_timer_notify
          | :object_server

  @typedoc """
  KNX frame. The `:body` key might be a struct or the binary data, if the frame was not parsed.
  """
  @type t :: %__MODULE__{
          header_size: integer(),
          protocol_version: integer(),
          request_type: request_type(),
          body: struct() | binary()
        }

  @enforce_keys [:header_size, :protocol_version, :request_type, :body]
  defstruct [:header_size, :protocol_version, :request_type, :body]
end
