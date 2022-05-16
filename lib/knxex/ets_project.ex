defmodule KNXex.EtsProject do
  @moduledoc """
  KNX ETS project.
  """

  @typedoc """
  KNX completion status.
  """
  @type completion_status ::
          :unknown
          | :editing
          | :finished_design
          | :finished_commissioning
          | :tested
          | :accepted
          | :locked

  @typedoc """
  KNX medium type. Twisted Pair, IP, Radio Frequency, or Powerline.
  """
  @type medium :: :tp | :ip | :rf | :pl | :unknown

  @typedoc """
  Represents a KNX ETS project.

  Locations is currently not supported and ignored.

  `group_addresses` is keyed by the ID or the group address in `x/y/z` notation, depending on the parser setting `:group_addresses_key`.
  """
  @type t :: %__MODULE__{
          project_path: binary(),
          name: String.t(),
          comment: String.t(),
          completion_status: completion_status(),
          last_modified: NaiveDateTime.t() | nil,
          project_start: NaiveDateTime.t() | nil,
          project_end: NaiveDateTime.t() | nil,
          project_number: String.t() | nil,
          contract_number: String.t() | nil,
          bus_access_legacy_mode: boolean(),
          group_addresses: %{
            optional(id_or_address :: String.t()) => KNXex.EtsProject.GroupAddressInfo.t()
          },
          locations: nil,
          topology: %{
            optional(address :: non_neg_integer()) => KNXex.EtsProject.Topology.Area.t()
          },
          unassigned_devices: [KNXex.EtsProject.Topology.Device.t()]
        }

  @enforce_keys [:name, :project_path, :group_addresses, :topology, :unassigned_devices]
  defstruct project_path: "",
            name: "",
            comment: "",
            completion_status: :unknown,
            last_modified: nil,
            project_start: nil,
            project_end: nil,
            project_number: nil,
            contract_number: nil,
            bus_access_legacy_mode: false,
            group_addresses: %{},
            locations: nil,
            topology: %{},
            unassigned_devices: []

  @doc """
  Returns a new empty ETS project struct.
  """
  @spec new(binary()) :: t()
  def new(project_path, name \\ "") when is_binary(project_path) and is_binary(name) do
    %__MODULE__{
      project_path: project_path,
      name: name,
      comment: "",
      completion_status: :unknown,
      last_modified: nil,
      project_start: nil,
      project_end: nil,
      project_number: nil,
      contract_number: nil,
      bus_access_legacy_mode: false,
      group_addresses: %{},
      locations: nil,
      topology: %{},
      unassigned_devices: []
    }
  end

  #####################################################
  # The following modules were for simplicity inlined #
  #####################################################

  defmodule GroupAddressInfo do
    @moduledoc """
    KNX group address information. Includes information about the group address from the ETS project.
    """

    @typedoc """
    Represents a KNX group address.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            address: KNXex.GroupAddress.t(),
            name: String.t(),
            type: String.t() | nil,
            central: boolean(),
            unfiltered: boolean()
          }

    @enforce_keys [:id, :address, :name, :type]
    defstruct [:id, :address, :name, :type, central: false, unfiltered: false]
  end

  defmodule Topology.Area do
    @moduledoc """
    KNX topology area.
    """

    @typedoc """
    Represents a KNX topology area.
    """
    @type t :: %__MODULE__{
            name: String.t(),
            address: non_neg_integer(),
            lines: %{
              optional(address :: non_neg_integer()) => KNXex.EtsProject.Topology.Line.t()
            }
          }

    @enforce_keys [:name, :address]
    defstruct [:name, :address, lines: %{}]
  end

  defmodule Topology.Line do
    @moduledoc """
    KNX topology line.
    """

    @typedoc """
    Represents a KNX topology line.
    """
    @type t :: %__MODULE__{
            name: String.t(),
            medium_type: KNXex.EtsProject.medium(),
            address: {area :: non_neg_integer(), line :: non_neg_integer()},
            devices: %{
              optional(address :: non_neg_integer()) => KNXex.EtsProject.Topology.Device.t()
            }
          }

    @enforce_keys [:name, :medium_type, :address]
    defstruct [:name, :medium_type, :address, devices: %{}]
  end

  defmodule Topology.Device do
    @moduledoc """
    KNX topology device.
    """

    defmodule ComObject do
      @moduledoc """
      KNX topology device communication object.
      """

      @typedoc """
      Represents a KNX topology device communication object.

      The object size is in bits.
      """
      @type t :: %__MODULE__{
              id: String.t(),
              description: String.t() | nil,
              text: String.t() | nil,
              function_text: String.t() | nil,
              number: non_neg_integer() | nil,
              links: group_address_id :: String.t() | nil,
              dpt: datapoint_type :: String.t() | nil,
              object_size: pos_integer() | nil,
              priority: nil,
              communication_flag: boolean() | nil,
              read_flag: boolean() | nil,
              read_on_init_flag: boolean() | nil,
              transmit_flag: boolean() | nil,
              update_flag: boolean() | nil,
              write_flag: boolean() | nil
            }

      defstruct [
        :id,
        :description,
        :text,
        :function_text,
        :number,
        :links,
        :dpt,
        :object_size,
        :priority,
        :communication_flag,
        :read_flag,
        :read_on_init_flag,
        :transmit_flag,
        :update_flag,
        :write_flag
      ]
    end

    defmodule Status do
      @moduledoc """
      KNX device status.
      """

      @typedoc """
      Represents a KNX device status.
      """
      @type t :: %__MODULE__{
              application_program_loaded: boolean(),
              communication_part_loaded: boolean(),
              individual_address_loaded: boolean(),
              medium_config_loaded: boolean(),
              parameters_loaded: boolean()
            }

      defstruct application_program_loaded: false,
                communication_part_loaded: false,
                individual_address_loaded: false,
                medium_config_loaded: false,
                parameters_loaded: false
    end

    @typedoc """
    Represents a KNX topology device.
    """
    @type t :: %__MODULE__{
            name: String.t(),
            address: KNXex.IndividualAddress.t(),
            description: String.t(),
            comment: String.t(),
            product_refid: String.t(),
            hardware2program_refid: String.t(),
            completion_status: KNXex.EtsProject.completion_status(),
            last_modified: NaiveDateTime.t() | nil,
            last_download: NaiveDateTime.t() | nil,
            device_status: Status.t(),
            com_objects: %{optional(refid :: String.t()) => ComObject.t()},
            parameters: %{optional(refid :: String.t()) => value :: String.t()},
            additional_attributes: %{optional(name :: String.t()) => value :: String.t() | map()}
          }

    @enforce_keys [:name, :address]
    defstruct [
      :name,
      :address,
      :description,
      :comment,
      :product_refid,
      :hardware2program_refid,
      :completion_status,
      :last_modified,
      :last_download,
      :device_status,
      com_objects: %{},
      parameters: %{},
      additional_attributes: %{}
    ]
  end

  defmodule Manufacturer.Hardware do
    @moduledoc """
    KNX manufacturer hardware.
    """

    @typedoc """
    Represents KNX manufacturer hardware.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            serialnum: String.t(),
            version: String.t(),
            bus_current: pos_integer() | nil,
            has_individual_address: boolean() | nil,
            has_application_program: boolean() | nil,
            is_coupler: boolean() | nil,
            is_ip_enabled: boolean() | nil,
            is_power_supply: boolean() | nil,
            hardware2programs: Manufacturer.Hardware.Hardware2Program.t(),
            products: Manufacturer.Hardware.Product.t()
          }

    @fields [
      :id,
      :name,
      :serialnum,
      :version,
      :bus_current,
      :has_individual_address,
      :has_application_program,
      :is_coupler,
      :is_ip_enabled,
      :is_power_supply,
      :hardware2programs,
      :products
    ]
    @enforce_keys @fields
    defstruct @fields
  end

  defmodule Manufacturer.Hardware.Product do
    @moduledoc """
    KNX manufacturer hardware product.
    """

    @typedoc """
    Represents a KNX manufacturer hardware product.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            text: String.t(),
            order_number: String.t(),
            is_rail_mounted: boolean() | nil,
            hash: String.t(),
            width: integer() | nil
          }

    @fields [
      :id,
      :text,
      :order_number,
      :is_rail_mounted,
      :hash,
      :width
    ]
    @enforce_keys @fields
    defstruct @fields
  end

  defmodule Manufacturer.Hardware.Hardware2Program do
    @moduledoc """
    KNX manufacturer Hardware-to-Program mapping.
    """

    @typedoc """
    Represents a KNX manufacturer Hardware-to-Program mapping.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            medium_types: [KNXex.EtsProject.medium()],
            hash: String.t(),
            application_program_refid: String.t() | nil
          }

    @fields [:id, :medium_types, :hash, :application_program_refid]
    @enforce_keys @fields
    defstruct @fields
  end

  defmodule Manufacturer.ApplicationProgram do
    @moduledoc """
    KNX manufacturer application program.
    """

    @typedoc """
    Represents a KNX manufacturer application program.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            description: String.t() | nil,
            app_number: String.t() | nil,
            app_version: String.t() | nil,
            program_type: String.t() | nil,
            mask_version: String.t() | nil,
            dynamic_table_management: boolean() | nil,
            linkable: boolean() | nil,
            hash: String.t(),
            com_objects: %{
              optional(refid :: String.t()) => KNXex.EtsProject.Topology.Device.ComObject.t()
            }
          }

    @fields [
      :id,
      :name,
      :description,
      :app_number,
      :app_version,
      :program_type,
      :mask_version,
      :dynamic_table_management,
      :linkable,
      :hash,
      :com_objects
    ]
    @enforce_keys @fields
    defstruct @fields
  end
end
