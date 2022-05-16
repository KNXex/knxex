defmodule KNXex.ProjectParser do
  @moduledoc """
  KNX project file parser (ETS .knxproj).
  """

  require KNXex
  alias KNXex
  import KNXex.ProjectParser.Macros

  @project_regex ~r"P-[0-9A-F]{4}/(?:\d+|project)\.xml"i
  @project_info_regex ~r"P-[0-9A-F]{4}/(?:project)\.xml"i
  @manufacturer_regex ~r"M-[0-9A-F]{4}/(?:Hardware|M-.*)\.xml"i
  @manufacturer_id_regex ~r"(M-[0-9A-F]{4})/.*"i

  @before_compile KNXex.ProjectParser.Topology
  @before_compile KNXex.ProjectParser.GroupAddresses
  @before_compile KNXex.ProjectParser.Manufacturer

  @doc """
  Parses a KNX project file (ETS .knxproj), extracting project information and returns a `KNXex.EtsProject` struct.

  The following informations get extracted:
    - Project Information (name, comment, project number, project start/end, etc.)
    - Group Addresses with the DPT
    - Topology (Area, Line, Device, Unassigned Devices)
    - Device Additional Attributes (i.e. IP config, if enabled)
    - Device Communication Objects (if enabled)
    - Device Parameters (if enabled)

  The following options are available:
    - `only: [atom()]` - Only the specified information groups will be parsed, the following groups are available: `project_info`, `group_addresses`, `topology`.
    - `exclude: [atom()]` - The specified information groups will be excluded (see `only`), `only` and `exclude` are mutually exclusive.
    - `include_dev_add_attributes: boolean()` - Include additional attributes from the device (default: `false`).
    - `include_dev_com_objects: boolean()` - Include communication objects from the device (default: `false`).
    - `include_dev_parameters: boolean()` - Include parameters from the device (default: `false`).
    - `group_addresses_key: :id | :address` - The key to use for the group addresses map (default: `:address`).

  This function will raise on errors.
  """
  @spec parse(binary(), Keyword.t()) :: KNXex.EtsProject.t()
  def parse(path, opts \\ []) when is_binary(path) and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError, "parse/2 expected a keyword list, got: #{inspect(opts)}"
    end

    new_opts = Map.new(opts)

    if new_opts[:only] != nil and new_opts[:exclude] != nil do
      raise ArgumentError, "options `only` and `exclude` are mutually exclusive"
    end

    case get_project_xml_from_zip(path, new_opts) do
      {:ok, project_files} ->
        Enum.reduce(project_files, KNXex.EtsProject.new(path), fn
          {filename, file_content}, acc_ets_project ->
            # Drop UTF-8 BOM first
            with content_clean <- Enum.drop(:binary.bin_to_list(file_content), 3),
                 {{:xmlElement, :KNX, :KNX, _list1, _namespace, _list3, _any2, _attribs,
                   xml_elements, _list4, _cwd, _atom},
                  _any3} <- :xmerl_scan.string(content_clean, comments: false, quiet: true),
                 {:xmlElement, :Project, :Project, _list1, _namespace, _list3, _any2, _attribs,
                  xml_project, _list4, _cwd, _atom} <- Enum.at(xml_elements, 1) do
              parse_project(xml_project, acc_ets_project, new_opts)
            else
              {__MODULE__, :skip_parser} ->
                acc_ets_project

              _any ->
                raise "Invalid project file (#{filename} is not a valid ETS project XML file)"
            end

          _any, acc_ets_project ->
            acc_ets_project
        end)

      {:error, err} ->
        errmsg = "#{err}"
        raise errmsg
    end
  end

  @doc """
  Parses a KNX project file (ETS .knxproj), extracting manufacturer information and returns a map.

  The following informations get extracted:
    - Application Programs (basic information and communication objects)
    - Hardware & products (basic information)
    - Hardware-to-Program mappings

  The following options are available:
    - `only: [String.t()]` - Only the specified manufacturers will be parsed, the manufacturer ID, i.e. `M-0001`, is required.
    - `exclude: [String.t()]` - The specified manufacturers will be excluded (see `only`), `only` and `exclude` are mutually exclusive.
    - `parallel: boolean()` - Whether to parse the manufacturers in parallel using `Task.async_stream/5` (default: `false`).
    - `parallel_timeout: pos_integer()` - The timeout for parallel parsing (default: `60_000`ms).

  This function will raise on errors.

  Example output:
  ```elixir
  %{
    "M-00C9" => %{
      application_programs: %{
        "M-00C9_A-FF14-20-223D" => %KNXex.EtsProject.Manufacturer.ApplicationProgram{
          app_number: "65300",
          app_version: "32",
          com_objects: %{
            "O-12" => %KNXex.EtsProject.Topology.Device.ComObject{
              communication_flag: true,
              description: nil,
              dpt: nil,
              function_text: "Eingang",
              id: "O-12",
              links: nil,
              number: 12,
              object_size: 1,
              priority: nil,
              read_flag: false,
              read_on_init_flag: false,
              text: "Temp. Grenzwert 1: Schaltausgang Sperre",
              transmit_flag: false,
              update_flag: false,
              write_flag: true
            }
          },
          description: "KNX TH-UP",
          dynamic_table_management: true,
          hash: "Iss9qvKKsV5qnWizDXWVPQ==",
          id: "M-00C9_A-FF14-20-223D",
          linkable: false,
          mask_version: "MV-0701",
          name: "KNX App_20",
          program_type: "ApplicationProgram"
        }
      },
      hardware: %{
        "M-00C9_H-70121-1" => %KNXex.EtsProject.Manufacturer.Hardware{
          bus_current: 10,
          hardware2programs: %{
            "M-00C9_H-70121-1_HP-FF14-20-223D" => %KNXex.EtsProject.Manufacturer.Hardware.Hardware2Program{
              application_program_refid: "M-00C9_A-FF14-20-223D",
              hash: "SdI1o0jhKfnXwWt3Gf3qOvC/z4U=",
              id: "M-00C9_H-70121-1_HP-FF14-20-223D",
              medium_types: [:tp]
            }
          },
          has_application_program: true,
          has_individual_address: true,
          id: "M-00C9_H-70121-1",
          is_coupler: nil,
          is_ip_enabled: nil,
          is_power_supply: nil,
          name: "KNX T-AP",
          products: %{
            "M-00C9_H-70121-1_P-70121" => %KNXex.EtsProject.Manufacturer.Hardware.Product{
              hash: "H1+DOySrz+UUcxCBvF0s8MIyIak=",
              id: "M-00C9_H-70121-1_P-70121",
              is_rail_mounted: false,
              order_number: "70121",
              text: "KNX T-AP",
              width: nil
            }
          },
          serialnum: "70121",
          version: "1"
        }
      }
    }
  }
  ```
  """
  @spec parse_manufacturers(binary(), Keyword.t()) :: %{
          optional(manufacturer_id :: String.t()) => %{
            hardware: %{
              optional(id :: String.t()) => KNXex.EtsProject.Manufacturer.Hardware.t()
            },
            application_programs: %{
              optional(id :: String.t()) => KNXex.EtsProject.Manufacturer.ApplicationProgram.t()
            }
          }
        }
  def parse_manufacturers(path, opts \\ []) when is_binary(path) and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError, "parse_manufacturers/2 expected a keyword list, got: #{inspect(opts)}"
    end

    new_opts = Map.new(opts)

    if new_opts[:only] != nil and new_opts[:exclude] != nil do
      raise ArgumentError, "options `only` and `exclude` are mutually exclusive"
    end

    # Following XML files should we get: Hardware.xml, M-[...].xml (M- one or many)
    case get_manufacturer_xml_from_zip(path, new_opts) do
      {:ok, manufacturer_files} ->
        sorted_files =
          Enum.sort_by(manufacturer_files, fn {filename, _content} ->
            filename
          end)

        if new_opts[:parallel] == true do
          stream =
            Task.async_stream(
              sorted_files,
              fn file ->
                parse_manufacturer_files([file], new_opts)
              end,
              ordered: false,
              timeout: new_opts[:parallel_timeout] || 60_000
            )

          Enum.reduce(stream, %{}, fn
            {:ok, data}, acc -> Map.merge(acc, data)
            {:exit, reason}, _acc -> exit(reason)
          end)
        else
          parse_manufacturer_files(sorted_files, new_opts)
        end

      {:error, err} ->
        errmsg = "#{err}"
        raise errmsg
    end
  end

  @spec parse_manufacturer_files(list(), map()) :: map()
  defp parse_manufacturer_files(sorted_files, opts) when is_list(sorted_files) do
    Enum.reduce(sorted_files, %{}, fn
      {filename, file_content}, acc_manufacturers ->
        # Drop UTF-8 BOM first
        with content_clean <- Enum.drop(:binary.bin_to_list(file_content), 3),
             {{:xmlElement, :KNX, :KNX, _list1, _namespace, _list3, _any2, _attribs, xml_elements,
               _list4, _cwd, _atom},
              _any3} <- :xmerl_scan.string(content_clean, comments: false, quiet: true),
             {:xmlElement, :ManufacturerData, :ManufacturerData, _list1, _namespace, _list3,
              _any2, _attribs, xml_manufacturer_data, _list4, _cwd,
              _atom} <- Enum.at(xml_elements, 1),
             {:xmlElement, :Manufacturer, :Manufacturer, _list1, _namespace, _list3, _any2,
              attribs, xml_manufacturers, _list4, _cwd,
              _atom} <- Enum.at(xml_manufacturer_data, 1) do
          ref_id =
            Enum.find_value(attribs, fn
              {:xmlAttribute, :RefId, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2} ->
                :binary.list_to_bin(value)

              _any ->
                false
            end)

          acc = Map.get(acc_manufacturers, ref_id, %{hardware: %{}, application_programs: %{}})

          Map.put(
            acc_manufacturers,
            ref_id,
            parse_manufacturer(Enum.at(xml_manufacturers, 1), acc, opts)
          )
        else
          {__MODULE__, :skip_parser} ->
            acc_manufacturers

          _any ->
            raise "Invalid project file (#{filename} is not a valid ETS project XML file)"
        end

      _any, acc_ets_project ->
        acc_ets_project
    end)
  end

  # Retrieve all project XML files from the .knxprod file
  # Raises on errors
  @spec get_project_xml_from_zip(binary(), map()) :: {:ok, list()} | {:error, term()}
  defp get_project_xml_from_zip(path, opts) do
    opts_only = opts[:only]
    opts_exclude = opts[:exclude]

    skip_project_info =
      (opts_only != nil and
         :project_info not in opts_only) or
        (opts_exclude != nil and
           :project_info in opts_exclude)

    get_xml_from_zip(path, fn filename ->
      if skip_project_info and String.match?(filename, @project_info_regex) do
        false
      else
        String.match?(filename, @project_regex)
      end
    end)
  end

  # Retrieve all manufacturers XML files from the .knxprod file
  # Raises on errors
  @spec get_manufacturer_xml_from_zip(binary(), map()) :: {:ok, list()} | {:error, term()}
  defp get_manufacturer_xml_from_zip(path, opts) do
    opts_only = opts[:only]
    opts_exclude = opts[:exclude]

    get_xml_from_zip(path, fn filename ->
      base_match =
        String.match?(filename, @manufacturer_regex) and
          not String.contains?(filename, "Baggages.xml")

      if not base_match or (opts_only == nil and opts_exclude == nil) do
        base_match
      else
        manu_match =
          case Regex.scan(@manufacturer_id_regex, filename) do
            [[_full, main]] ->
              (opts_only != nil and
                 main in opts_only) or
                (opts_exclude != nil and
                   main not in opts_exclude)

            _any ->
              false
          end

        manu_match
      end
    end)
  end

  # Get specific XML files from the zip file
  @spec get_xml_from_zip(binary(), (filename :: String.t() -> boolean())) ::
          {:ok, list()} | {:error, term()}
  defp get_xml_from_zip(path, filter) do
    with true <- File.exists?(path),
         project_path_charlist <- :binary.bin_to_list(path),
         {:ok, zip_files} <- :zip.list_dir(project_path_charlist),
         zip_project_filenames <-
           zip_files
           |> Stream.filter(fn
             {:zip_file, zip_file, _info, _comment, _offset, _size} ->
               filter.(Kernel.to_string(zip_file))

             _any ->
               false
           end)
           |> Enum.map(fn
             {:zip_file, zip_filename, _info, _comment, _offset, _size} -> zip_filename
           end) do
      :zip.unzip(project_path_charlist, [{:file_list, zip_project_filenames}, :memory])
    else
      false -> raise "Given file does not exist"
      nil -> raise "Could not find project file in zip file"
      err -> err
    end
  end

  #####################
  # Parse KNX Project #
  #####################

  @spec parse_project(term(), KNXex.EtsProject.t(), map()) ::
          KNXex.EtsProject.t()
  defp parse_project(xml_project, ets_project, opts) do
    case Enum.at(xml_project, 1) do
      {:xmlElement, :Installations, :Installations, _list1, _namespace, _list3, _any2, _attribs,
       xml_installations, _list4, _cwd, _atom} ->
        Enum.reduce(
          xml_installations,
          ets_project,
          fn
            {:xmlElement, :Installation, :Installation, _list1, _namespace, _list3, _any2,
             _attribs, xml_installation, _list4, _cwd, _atom},
            acc_ets_project ->
              parse_installation(xml_installation, acc_ets_project, opts)

            _xml, acc_ets_project ->
              acc_ets_project
          end
        )

      {:xmlElement, :ProjectInformation, :ProjectInformation, _list1, _namespace, _list3, _any2,
       xml_project_info, _subelements, _list4, _cwd, _atom} ->
        if ets_project.name != "" do
          raise "Unexpected re-entry into project information parsing, are there two projects in one .knxproj export?"
        end

        xml_project_info
        |> Enum.reduce(%{}, fn
          {:xmlAttribute, :Name, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
          acc ->
            Map.put(acc, :name, xml_value_to_string(value))

          {:xmlAttribute, :Comment, _list1, _list2, _list3, _list4, _any1, _list5, value, _any2},
          acc ->
            Map.put(acc, :comment, xml_value_to_string(value))

          {:xmlAttribute, :CompletionStatus, _list1, _list2, _list3, _list4, _any1, _list5, value,
           _any2},
          acc ->
            Map.put(acc, :completion_status, parse_completion_status(xml_value_to_string(value)))

          {:xmlAttribute, :LastModified, _list1, _list2, _list3, _list4, _any1, _list5, value,
           _any2},
          acc ->
            Map.put(acc, :last_modified, xml_value_to_ndt(value))

          {:xmlAttribute, :ProjectStart, _list1, _list2, _list3, _list4, _any1, _list5, value,
           _any2},
          acc ->
            Map.put(acc, :project_start, xml_value_to_ndt(value))

          {:xmlAttribute, :ProjectEnd, _list1, _list2, _list3, _list4, _any1, _list5, value,
           _any2},
          acc ->
            Map.put(acc, :project_end, xml_value_to_ndt(value))

          {:xmlAttribute, :ProjectNumber, _list1, _list2, _list3, _list4, _any1, _list5, value,
           _any2},
          acc ->
            Map.put(acc, :project_number, xml_value_to_string(value))

          {:xmlAttribute, :ContractNumber, _list1, _list2, _list3, _list4, _any1, _list5, value,
           _any2},
          acc ->
            Map.put(acc, :contract_number, xml_value_to_string(value))

          {:xmlAttribute, :BusAccessLegacyMode, _list1, _list2, _list3, _list4, _any1, _list5,
           value, _any2},
          acc ->
            Map.put(acc, :bus_access_legacy_mode, xml_value_to_bool(value))

          _any, acc ->
            acc
        end)
        |> (&Map.merge(ets_project, &1)).()
        |> KNXex.to_struct!(KNXex.EtsProject)

      _any ->
        ets_project
    end
  end

  @spec parse_installation(term(), KNXex.EtsProject.t(), map()) ::
          KNXex.EtsProject.t()
  defp parse_installation(xml_installation, ets_project, opts) do
    opts_only = opts[:only]
    opts_exclude = opts[:exclude]

    # First parse Topology and unassigned Devices
    new_ets_project =
      with false <-
             (opts_only != nil and
                :topology not in opts_only) or
               (opts_exclude != nil and
                  :topology in opts_exclude),
           {:xmlElement, :Topology, :Topology, _list1, _namespace, _list3, _any2, _attribs,
            xml_topology, _list4, _cwd,
            _atom} <-
             Enum.find(
               xml_installation,
               fn element -> elem(element, 1) == :Topology end
             ) do
        parse_topology(xml_topology, ets_project, 0, 0, opts)
      else
        _any -> ets_project
      end

    # Parse Group Addresses
    with false <-
           (opts_only != nil and
              :group_addresses not in opts_only) or
             (opts_exclude != nil and
                :group_addresses in opts_exclude),
         {:xmlElement, :GroupAddresses, :GroupAddresses, _list1, _namespace, _list3, _any2,
          _attribs, xml_group_ranges_base, _list4, _cwd,
          _atom} <-
           Enum.find(
             xml_installation,
             fn element -> elem(element, 1) == :GroupAddresses end
           ),
         {:xmlElement, :GroupRanges, :GroupRanges, _list1, _namespace, _list3, _any2, _attribs,
          xml_group_ranges, _list4, _cwd, _atom} <- Enum.at(xml_group_ranges_base, 1) do
      parse_group_ranges(xml_group_ranges, new_ets_project, opts)
    else
      _any -> new_ets_project
    end
  end

  # Returns the completion atom for the medium type string from the .knxproj XML
  @spec parse_completion_status(binary()) :: KNXex.EtsProject.completion_status()
  defp parse_completion_status("Unknown"), do: :unknown
  defp parse_completion_status("Editing"), do: :editing
  defp parse_completion_status("FinishedDesign"), do: :finished_design
  defp parse_completion_status("FinishedCommissioning"), do: :finished_commissioning
  defp parse_completion_status("Tested"), do: :tested
  defp parse_completion_status("Accepted"), do: :accepted
  defp parse_completion_status("Locked"), do: :locked
end
