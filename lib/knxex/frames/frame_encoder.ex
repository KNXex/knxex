defprotocol KNXex.Frames.FrameEncoder do
  @moduledoc """
  Frame Encoder protocol for the Multicast Server.
  """

  @doc """
  Encodes the structure into a bitstring for the request payload.
  """
  @spec encode(t(), protocol_version :: integer()) :: {:ok, bitstring()} | {:error, term()}
  def encode(datatype, protocol_version)

  @doc """
  Returns the correct request type for the given datatype.
  """
  @spec get_request_type(t()) :: KNXex.Frame.request_type()
  def get_request_type(datatype)
end
