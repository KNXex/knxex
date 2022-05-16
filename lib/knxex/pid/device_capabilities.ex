defmodule KNXex.PID.DeviceCapabilities do
  @moduledoc """
  KNXnet/IP Parameter Object "Device Capabilities".
  """

  import KNXex.Macro

  defconstant(:meta, :pid, 68)
  defconstant(:meta, :name, "KNXnet/IP Device Capabilities")

  defconstant(:bits, :device_management, 0)
  defconstant(:bits, :tunneling, 1)
  defconstant(:bits, :routing, 2)
  defconstant(:bits, :remote_logging, 3)
  defconstant(:bits, :remote_conf_and_diagnosis, 4)
  defconstant(:bits, :object_server, 5)

  # Checks if the value is a struct or an int, and checks if the bit is set (bit as integer value, i.e. bit 0 = 1).
  @spec check_bit(integer(), integer()) :: Macro.t()
  defguardp check_bit(t, value)
            when is_integer(t) and :erlang.band(t, value) > 0

  @doc """
  Checks if the given device capabilities has the device management capability bit set.
  """
  defguard has_device_management(value)
           when check_bit(value, 1)

  @doc """
  Checks if the given device capabilities has the tunneling capability bit set.
  """
  defguard has_tunneling(value)
           when check_bit(value, 2)

  @doc """
  Checks if the given device capabilities has the routing capability bit set.
  """
  defguard has_routing(value)
           when check_bit(value, 4)

  @doc """
  Checks if the given device capabilities has the remote logging capability bit set.
  """
  defguard has_remote_logging(value)
           when check_bit(value, 8)

  @doc """
  Checks if the given device capabilities has the remote configuration and diagnosis capability bit set.
  """
  defguard has_remote_conf_and_diag(value)
           when check_bit(value, 16)

  @doc """
  Checks if the given device capabilities has the object server capability bit set.
  """
  defguard has_object_server(value)
           when check_bit(value, 32)
end
