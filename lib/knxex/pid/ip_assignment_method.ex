defmodule KNXex.PID.IPAssignmentMethod do
  @moduledoc """
  KNXnet/IP Parameter Object "IP Assignment Method".
  """

  import KNXex.Macro

  defconstant(:current, :pid, 54)
  defconstant(:current, :name, "Current IP Assignment Method")

  defconstant(:meta, :pid, 55)
  defconstant(:meta, :name, "IP Assignment Method")

  @typedoc """
  The KNX device's IP assignment method.
  """
  @type method :: :manually | :dhcp | :bootp | :auto_ip

  @doc """
  Turns the given integer into the corresponding atom.
  """
  @spec to_atom(integer()) :: method()
  def to_atom(value)

  def to_atom(1), do: :manually
  def to_atom(2), do: :dhcp
  def to_atom(4), do: :bootp
  def to_atom(8), do: :auto_ip

  @doc """
  Turns the given atom into the correct integer value.
  """
  @spec to_integer(method()) :: integer()
  def to_integer(value)

  def to_integer(:manually), do: 1
  def to_integer(:dhcp), do: 2
  def to_integer(:bootp), do: 4
  def to_integer(:auto_ip), do: 8
end
