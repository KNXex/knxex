defmodule KNXexIP.DPT do
  @moduledoc """
  KNX data point types (DPT). This module only contains a subset of all DPTs.

  KNX datapoints all have a type as well as a value. The type must be known
  in order to encode and decode a datapoint.

  The datapoint type is a string, consisting of a main number and a subnumber
  seperated by a dot, e.g. `"1.001"`. The type carries information as to the
  format, encoding, range and unit of the datapoint. A full list of datapoint
  types can be seen in the KNX specification (document 3/7/2).

  Most datapoint types are mapped directly to a single-valued Elixir data
  type, but complex KNX values are mapped to tuples. The below table lists these mappings:

  | Datapoint Type     | Elixir type                                                                                                               | Encoded                  | Decoded                                                 |
  |--------------------|---------------------------------------------------------------------------------------------------------------------------|--------------------------|---------------------------------------------------------|
  | 1.*                | boolean()                                                                                                                 | `<<1::6>>`               | `true`                                                  |
  | 2.*                | {c, v}, all elements are integer()                                                                                        | `<<3::6>>`               | `{1, 1}`                                                |
  | 3.*                | {c, stepcode}, all elements are integer()                                                                                 | `<<3>>`                  | `{0, 3}`                                                |
  | 4.*                | binary()                                                                                                                  | `<<"T">>`                | `"T"`                                                   |
  | 5.*                | integer()                                                                                                                 | `<<123>>`                | `123`                                                   |
  | 6.* (except 6.020) | integer()                                                                                                                 | `<<123>>`                | `123`                                                   |
  | 6.020              | {a, b, c, d, e, f}, all elements are integer()                                                                            | `<<180>>`                | `{1, 0, 1, 1, 0, 4}`                                    |
  | 7.*                | integer()                                                                                                                 | `<<3421::16>>`           | `3421`                                                  |
  | 8.*                | integer()                                                                                                                 | `<<3421::16>>`           | `3421`                                                  |
  | 9.*                | float()                                                                                                                   | `<<13, 220>>`            | `30.0`                                                  |
  | 10.*               | {day, hour, minutes, seconds}, all elements are integer()                                                                 | `<204, 43, 12>>`         | `{6, 12, 43, 12}`                                       |
  | 11.*               | {day, month, year}, all elements are integer()                                                                            | `<<12, 5, 19>>`          | `{12, 5, 2019}`                                         |
  | 12.*               | integer()                                                                                                                 | `<<203424034::32>>`      | `203424034`                                             |
  | 13.*               | integer()                                                                                                                 | `<<203424034::32>>`      | `203424034`                                             |
  | 14.*               | float()                                                                                                                   | `<<1174713696::32>>`     | `8493.34375`                                            |
  | 15.*               | {d6, d5, d4, d3, d2, d1, e, p, d, c, index}, all elements are integer()                                                   | `<<32, 118, 57, 158>>`   | `{2, 0, 7, 6, 3, 9, 1, 0, 0, 1, 14}`                    |
  | 16.*               | binary()                                                                                                                  | `<<79, 75, 0, 0, ...>>`  | `OK`                                                    |
  | 17.*               | integer()                                                                                                                 | `<<61>>`                 | `61`                                                    |
  | 18.*               | {c, scene_number}, all elements are integer()                                                                             | `<<152>>`                | `{1, 24}`                                               |
  | 19.*               | {{fault, dst, clock_quality}, NaiveDateTime.t() \\| :invalid_date_and_time}, first tuple element = all elements boolean() | `<<122, 5, 7, ...>>`     | `{{false, true, false}, ~N[2022-05-07 17:46:35]}`       |
  | 20.*               | integer()                                                                                                                 | `<<13>>`                 | `13`                                                    |
  | 21.*               | {b0, b1, b2, b3, b4, b5, b7}, all elements are boolean()                                                                  | `<<13>>`                 | `{true, false, true, true, false, false, false, false}` |
  | 22.*               | {b0, b1, b2, b3, b4, b5, b7, ..., b15}, all elements are boolean()                                                        | `<<13, 15>>`             | `{true, true, true, true, false, ..., false}`           |
  | 23.*               | {a, b}, all elements are integer()                                                                                        | `<<3::6>>`               | `{1, 1}`                                                |
  | 24.*               | String.t()                                                                                                                | `<<75, 78, ..., 0>>`     | `KNX is OK`                                             |
  | 25.*               | integer()                                                                                                                 | `<<58>>`                 | `58`                                                    |
  | 26.*               | {active, scene_number}, all elements are integer()                                                                        | `<<34>>`                 | `{0, 34}`                                               |
  | 27.*               | List of {onoff_state, valid} à 16 elements, all tuple elements are integer()                                              | `<<15, 240, 252, 15>>`   | `[{1, 0}, ..., {0, 1}, .. {1, 1}, ...]`                 |
  | 28.*               | String.t()                                                                                                                | `<<75, 78, ..., 0>>`     | `KNX is OK`                                             |
  | 29.*               | integer()                                                                                                                 | `<<255, 255, ...>>`      | `-92363274911746`                                       |
  | 219.*              | {lognumber, priority, app_area, error_class, attributes, alarmstatus_attributes}, all elements are integer()              | `<<128, 2, 1, 3, 0, 3>>` | `{128, 2, 1, 3, 0, 3}`                                  |
  """

  import KNXexIP.Macro
  @before_compile KNXexIP.Macro

  # Most of the decoder and encoder code has been verbatim copied
  # from the KNXnet/IP library, so a huge shootout for them.
  @before_compile KNXexIP.DPT.Decoder
  @before_compile KNXexIP.DPT.Encoder

  Module.register_attribute(__MODULE__, :constants, accumulate: true)

  defconstant(:dpt_1bit, "1-bit", "1.*")
  defconstant(:dpt_1bit, "DPT_Switch", "1.001")
  defconstant(:dpt_1bit, "DPT_Bool", "1.002")
  defconstant(:dpt_1bit, "DPT_Enable", "1.003")
  defconstant(:dpt_1bit, "DPT_Ramp", "1.004")
  defconstant(:dpt_1bit, "DPT_Alarm", "1.005")
  defconstant(:dpt_1bit, "DPT_BinaryValue", "1.006")
  defconstant(:dpt_1bit, "DPT_Step", "1.007")
  defconstant(:dpt_1bit, "DPT_UpDown", "1.008")
  defconstant(:dpt_1bit, "DPT_OpenClose", "1.009")
  defconstant(:dpt_1bit, "DPT_Start", "1.010")
  defconstant(:dpt_1bit, "DPT_State", "1.011")
  defconstant(:dpt_1bit, "DPT_Invert", "1.012")
  defconstant(:dpt_1bit, "DPT_DimSendStyle", "1.013")
  defconstant(:dpt_1bit, "DPT_InputSource", "1.014")
  defconstant(:dpt_1bit, "DPT_Reset", "1.015")
  defconstant(:dpt_1bit, "DPT_Ack", "1.016")
  defconstant(:dpt_1bit, "DPT_Trigger", "1.017")
  defconstant(:dpt_1bit, "DPT_Occupancy", "1.018")
  defconstant(:dpt_1bit, "DPT_Window_Door", "1.019")
  defconstant(:dpt_1bit, "DPT_LogicalFunction", "1.021")
  defconstant(:dpt_1bit, "DPT_Scene_AB", "1.022")
  defconstant(:dpt_1bit, "DPT_ShutterBlinds_Mode", "1.023")
  defconstant(:dpt_1bit, "DPT_DayNight", "1.024")
  defconstant(:dpt_1bit, "DPT_Heat_Cool", "1.100")

  defconstant(:dpt_2bit, "1-bit controlled", "2.*")
  defconstant(:dpt_2bit, "DPT_Switch_Control", "2.001")
  defconstant(:dpt_2bit, "DPT_Bool_Control", "2.002")
  defconstant(:dpt_2bit, "DPT_Enable_Control", "2.003")
  defconstant(:dpt_2bit, "DPT_Ramp_Control", "2.004")
  defconstant(:dpt_2bit, "DPT_Alarm_Control", "2.005")
  defconstant(:dpt_2bit, "DPT_BinaryValue_Control", "2.006")
  defconstant(:dpt_2bit, "DPT_Step_Control", "2.007")
  defconstant(:dpt_2bit, "DPT_Direction1_Control", "2.008")
  defconstant(:dpt_2bit, "DPT_Direction2_Control", "2.009")
  defconstant(:dpt_2bit, "DPT_Start_Control", "2.010")
  defconstant(:dpt_2bit, "DPT_State_Control", "2.011")
  defconstant(:dpt_2bit, "DPT_Invert_Control", "2.012")

  defconstant(:dpt_4bit, "3-bit controlled", "3.*")
  defconstant(:dpt_4bit, "DPT_Control_Dimming", "3.007")
  defconstant(:dpt_4bit, "DPT_Control_Blinds", "3.008")

  defconstant(:dpt_8bit_charset, "Character", "4.*")
  defconstant(:dpt_8bit_charset, "DPT_Char_ASCII", "4.001")
  defconstant(:dpt_8bit_charset, "DPT_Char_8859_1", "4.002")

  defconstant(:dpt_8bit_charset, "8-bit unsigned value", "5.*")
  defconstant(:dpt_8bit_unsigned, "DPT_Scaling", "5.001")
  defconstant(:dpt_8bit_unsigned, "DPT_Angle", "5.003")
  defconstant(:dpt_8bit_unsigned, "DPT_Percent_U8", "5.004")
  defconstant(:dpt_8bit_unsigned, "DPT_DecimalFactor", "5.005")
  defconstant(:dpt_8bit_unsigned, "DPT_Tariff", "5.006")
  defconstant(:dpt_8bit_unsigned, "DPT_Value_1_Ucount", "5.010")

  defconstant(:dpt_8bit_signed, "8-bit signed value", "6.*")
  defconstant(:dpt_8bit_signed, "DPT_Percent_V8", "6.001")
  defconstant(:dpt_8bit_signed, "DPT_Value_1_Count", "6.010")
  defconstant(:dpt_8bit_signed, "DPT_Status_Mode3", "6.020")

  defconstant(:dpt_16bit_unsigned, "2-byte unsigned value", "7.*")
  defconstant(:dpt_16bit_unsigned, "DPT_Value_2_UCount", "7.001")
  defconstant(:dpt_16bit_unsigned, "DPT_TimePeriodMsec", "7.002")
  defconstant(:dpt_16bit_unsigned, "DPT_TimePeriod10Msec", "7.003")
  defconstant(:dpt_16bit_unsigned, "DPT_TimePeriod100Msec", "7.004")
  defconstant(:dpt_16bit_unsigned, "DPT_TimePeriodSec", "7.005")
  defconstant(:dpt_16bit_unsigned, "DPT_TimePeriodMin", "7.006")
  defconstant(:dpt_16bit_unsigned, "DPT_TimePeriodHrs", "7.007")
  defconstant(:dpt_16bit_unsigned, "DPT_PropDataType", "7.010")
  defconstant(:dpt_16bit_unsigned, "DPT_Length_mm", "7.011")
  defconstant(:dpt_16bit_unsigned, "DPT_UEICurrentmA", "7.012")
  defconstant(:dpt_16bit_unsigned, "DPT_Brightness", "7.013")

  defconstant(:dpt_16bit_signed, "2-byte signed value", "8.*")
  defconstant(:dpt_16bit_signed, "DPT_Value_2_Count", "8.001")
  defconstant(:dpt_16bit_signed, "DPT_DeltaTimeMsec", "8.002")
  defconstant(:dpt_16bit_signed, "DPT_DeltaTime10Msec", "8.003")
  defconstant(:dpt_16bit_signed, "DPT_DeltaTime100Msec", "8.004")
  defconstant(:dpt_16bit_signed, "DPT_DeltaTimeSec", "8.005")
  defconstant(:dpt_16bit_signed, "DPT_DeltaTimeMin", "8.006")
  defconstant(:dpt_16bit_signed, "DPT_DeltaTimeHrs", "8.007")
  defconstant(:dpt_16bit_signed, "DPT_Percent_V16", "8.010")
  defconstant(:dpt_16bit_signed, "DPT_Rotation_Angle", "8.011")
  defconstant(:dpt_16bit_signed, "DPT_Length_m", "8.012")

  defconstant(:dpt_16bit_float, "2-byte float value", "9.*")
  defconstant(:dpt_16bit_float, "DPT_Value_Temp", "9.001")
  defconstant(:dpt_16bit_float, "DPT_Value_Tempd", "9.002")
  defconstant(:dpt_16bit_float, "DPT_Value_Tempa", "9.003")
  defconstant(:dpt_16bit_float, "DPT_Value_Lux", "9.004")
  defconstant(:dpt_16bit_float, "DPT_Value_Wsp", "9.005")
  defconstant(:dpt_16bit_float, "DPT_Value_Pres", "9.006")
  defconstant(:dpt_16bit_float, "DPT_Value_Humidity", "9.007")
  defconstant(:dpt_16bit_float, "DPT_Value_AirQuality", "9.008")
  defconstant(:dpt_16bit_float, "DPT_Value_AirFlow", "9.009")
  defconstant(:dpt_16bit_float, "DPT_Value_Time1", "9.010")
  defconstant(:dpt_16bit_float, "DPT_Value_Time2", "9.011")
  defconstant(:dpt_16bit_float, "DPT_Value_Volt", "9.020")
  defconstant(:dpt_16bit_float, "DPT_Value_Curr", "9.021")
  defconstant(:dpt_16bit_float, "DPT_PowerDensity", "9.022")
  defconstant(:dpt_16bit_float, "DPT_KelvinPerPercent", "9.023")
  defconstant(:dpt_16bit_float, "DPT_Power", "9.024")
  defconstant(:dpt_16bit_float, "DPT_Value_Volume_Flow", "9.025")
  defconstant(:dpt_16bit_float, "DPT_Rain_Amount", "9.026")
  defconstant(:dpt_16bit_float, "DPT_Value_Temp_F", "9.027")
  defconstant(:dpt_16bit_float, "DPT_Value_Wsp_kmh", "9.028")
  defconstant(:dpt_16bit_float, "DPT_Value_Absolute_Humidity", "9.029")
  defconstant(:dpt_16bit_float, "DPT_Concentration_μgm3", "9.030")

  defconstant(:dpt_24bit_time, "Time", "10.*")
  defconstant(:dpt_24bit_time, "DPT_TimeOfDay", "10.001")

  defconstant(:dpt_24bit_date, "Date", "11.*")
  defconstant(:dpt_24bit_date, "DPT_Date", "11.001")

  defconstant(:dpt_32bit_unsigned, "4-byte unsigned value", "12.*")
  defconstant(:dpt_32bit_unsigned, "DPT_4_Ucount", "12.001")
  defconstant(:dpt_32bit_unsigned, "DPT_LongTimePeriod_Sec", "12.100")
  defconstant(:dpt_32bit_unsigned, "DPT_LongTimePeriod_Min", "12.101")
  defconstant(:dpt_32bit_unsigned, "DPT_LongTimePeriod_Hrs", "12.102")

  defconstant(:dpt_32bit_signed, "4-byte signed value", "13.*")
  defconstant(:dpt_32bit_signed, "DPT_4_Count", "13.001")
  defconstant(:dpt_32bit_signed, "DPT_FlowRate_m3/h", "13.002")
  defconstant(:dpt_32bit_signed, "DPT_ActiveEnergy", "13.010")
  defconstant(:dpt_32bit_signed, "DPT_ApparantEnergy", "13.011")
  defconstant(:dpt_32bit_signed, "DPT_ReactiveEnergy", "13.012")
  defconstant(:dpt_32bit_signed, "DPT_ActiveEnergy_kWh", "13.013")
  defconstant(:dpt_32bit_signed, "DPT_ApparantEnergy_kVAh", "13.014")
  defconstant(:dpt_32bit_signed, "DPT_ReactiveEnergy_kVARh", "13.015")
  defconstant(:dpt_32bit_signed, "DPT_ActiveEnergy_MWh", "13.016")
  defconstant(:dpt_32bit_signed, "DPT_LongDeltaTimeSec", "13.100")

  defconstant(:dpt_32bit_float, "4-byte float value", "14.*")
  defconstant(:dpt_32bit_float, "DPT_Value_Acceleration", "14.000")
  defconstant(:dpt_32bit_float, "DPT_Value_Acceleration_Angular", "14.001")
  defconstant(:dpt_32bit_float, "DPT_Value_Activation_Energy", "14.002")
  defconstant(:dpt_32bit_float, "DPT_Value_Activity", "14.003")
  defconstant(:dpt_32bit_float, "DPT_Value_Mol", "14.004")
  defconstant(:dpt_32bit_float, "DPT_Value_Amplitude", "14.005")
  defconstant(:dpt_32bit_float, "DPT_Value_AngleRad", "14.006")
  defconstant(:dpt_32bit_float, "DPT_Value_AngleDeg", "14.007")
  defconstant(:dpt_32bit_float, "DPT_Value_Angular_Momentum", "14.008")
  defconstant(:dpt_32bit_float, "DPT_Value_Angular_Velocity", "14.009")
  defconstant(:dpt_32bit_float, "DPT_Value_Area", "14.010")
  defconstant(:dpt_32bit_float, "DPT_Value_Capacitance", "14.011")
  defconstant(:dpt_32bit_float, "DPT_Value_Charge_DensitySurface", "14.012")
  defconstant(:dpt_32bit_float, "DPT_Value_Charge_DensityVolume", "14.013")
  defconstant(:dpt_32bit_float, "DPT_Value_Compressibility", "14.014")
  defconstant(:dpt_32bit_float, "DPT_Value_Conductance", "14.015")
  defconstant(:dpt_32bit_float, "DPT_Value_Electrical_Conductivity", "14.016")
  defconstant(:dpt_32bit_float, "DPT_Value_Density", "14.017")
  defconstant(:dpt_32bit_float, "DPT_Value_Electric_Charge", "14.018")
  defconstant(:dpt_32bit_float, "DPT_Value_Electric_Current", "14.019")
  defconstant(:dpt_32bit_float, "DPT_Value_Electric_CurrentDensity", "14.020")
  defconstant(:dpt_32bit_float, "DPT_Value_Electric_DipoleMoment", "14.021")
  defconstant(:dpt_32bit_float, "DPT_Value_Electric_Displacement", "14.022")
  defconstant(:dpt_32bit_float, "DPT_Value_Electric_FieldStrength", "14.023")
  defconstant(:dpt_32bit_float, "DPT_Value_Electric_Flux", "14.024")
  defconstant(:dpt_32bit_float, "DPT_Value_Electric_FluxDensity", "14.025")
  defconstant(:dpt_32bit_float, "DPT_Value_Electric_Polarization", "14.026")
  defconstant(:dpt_32bit_float, "DPT_Value_Electric_Potential", "14.027")
  defconstant(:dpt_32bit_float, "DPT_Value_Electric_PotentialDifference", "14.028")
  defconstant(:dpt_32bit_float, "DPT_Value_ElectromagneticMoment", "14.029")
  defconstant(:dpt_32bit_float, "DPT_Value_Electromotive_Force", "14.030")
  defconstant(:dpt_32bit_float, "DPT_Value_Energy", "14.031")
  defconstant(:dpt_32bit_float, "DPT_Value_Force", "14.032")
  defconstant(:dpt_32bit_float, "DPT_Value_Frequency", "14.033")
  defconstant(:dpt_32bit_float, "DPT_Value_Angular_Frequency", "14.034")
  defconstant(:dpt_32bit_float, "DPT_Value_Heat_Capacity", "14.035")
  defconstant(:dpt_32bit_float, "DPT_Value_Heat_FlowRate", "14.036")
  defconstant(:dpt_32bit_float, "DPT_Value_Heat_Quantity", "14.037")
  defconstant(:dpt_32bit_float, "DPT_Value_Impedance", "14.038")
  defconstant(:dpt_32bit_float, "DPT_Value_Length", "14.039")
  defconstant(:dpt_32bit_float, "DPT_Value_Light_Quantity", "14.040")
  defconstant(:dpt_32bit_float, "DPT_Value_Luminance", "14.041")
  defconstant(:dpt_32bit_float, "DPT_Value_Luminous_Flux", "14.042")
  defconstant(:dpt_32bit_float, "DPT_Value_Luminous_Intensity", "14.043")
  defconstant(:dpt_32bit_float, "DPT_Value_Magnetic_FieldStrength", "14.044")
  defconstant(:dpt_32bit_float, "DPT_Value_Magnetic_Flux", "14.045")
  defconstant(:dpt_32bit_float, "DPT_Value_Magnetic_FluxDensity", "14.046")
  defconstant(:dpt_32bit_float, "DPT_Value_Magnetic_Moment", "14.047")
  defconstant(:dpt_32bit_float, "DPT_Value_Magnetic_Polarization", "14.048")
  defconstant(:dpt_32bit_float, "DPT_Value_Magnetization", "14.049")
  defconstant(:dpt_32bit_float, "DPT_Value_MagnetomotiveForce", "14.050")
  defconstant(:dpt_32bit_float, "DPT_Value_Mass", "14.051")
  defconstant(:dpt_32bit_float, "DPT_Value_MassFlux", "14.052")
  defconstant(:dpt_32bit_float, "DPT_Value_Momentum", "14.053")
  defconstant(:dpt_32bit_float, "DPT_Value_Phase_AngleRad", "14.054")
  defconstant(:dpt_32bit_float, "DPT_Value_Phase_AngleDeg", "14.055")
  defconstant(:dpt_32bit_float, "DPT_Value_Power", "14.056")
  defconstant(:dpt_32bit_float, "DPT_Value_Power_Factor", "14.057")
  defconstant(:dpt_32bit_float, "DPT_Value_Pressure", "14.058")
  defconstant(:dpt_32bit_float, "DPT_Value_Reactance", "14.059")
  defconstant(:dpt_32bit_float, "DPT_Value_Resistance", "14.060")
  defconstant(:dpt_32bit_float, "DPT_Value_Resistivity", "14.061")
  defconstant(:dpt_32bit_float, "DPT_Value_SelfInductance", "14.062")
  defconstant(:dpt_32bit_float, "DPT_Value_SolidAngle", "14.063")
  defconstant(:dpt_32bit_float, "DPT_Value_Sound_Intensity", "14.064")
  defconstant(:dpt_32bit_float, "DPT_Value_Speed", "14.065")
  defconstant(:dpt_32bit_float, "DPT_Value_Stress", "14.066")
  defconstant(:dpt_32bit_float, "DPT_Value_Surface_Tension", "14.067")
  defconstant(:dpt_32bit_float, "DPT_Value_Common_Temperature", "14.068")
  defconstant(:dpt_32bit_float, "DPT_Value_Absolute_Temperature", "14.069")
  defconstant(:dpt_32bit_float, "DPT_Value_TemperatureDifference", "14.070")
  defconstant(:dpt_32bit_float, "DPT_Value_Thermal_Capacity", "14.071")
  defconstant(:dpt_32bit_float, "DPT_Value_Thermal_Conductivity", "14.072")
  defconstant(:dpt_32bit_float, "DPT_Value_ThermoelectricPower", "14.073")
  defconstant(:dpt_32bit_float, "DPT_Value_Time", "14.074")
  defconstant(:dpt_32bit_float, "DPT_Value_Torque", "14.075")
  defconstant(:dpt_32bit_float, "DPT_Value_Volume", "14.076")
  defconstant(:dpt_32bit_float, "DPT_Value_Volume_Flux", "14.077")
  defconstant(:dpt_32bit_float, "DPT_Value_Weight", "14.078")
  defconstant(:dpt_32bit_float, "DPT_Value_Work", "14.079")
  defconstant(:dpt_32bit_float, "DPT_Value_ApparentPower", "14.080")

  defconstant(:dpt_32bit, "Entrance Access", "15.*")
  defconstant(:dpt_32bit, "DPT_Access_Data", "15.000")

  defconstant(:dpt_string, "Character String", "16.*")
  defconstant(:dpt_string, "DPT_String_ASCII", "16.000")
  defconstant(:dpt_string, "DPT_String_8859_1", "16.001")

  defconstant(:dpt_scenenum, "Scene Number", "17.*")
  defconstant(:dpt_scenenum, "DPT_SceneNumber", "17.001")

  defconstant(:dpt_scenecon, "Scene Control", "18.*")
  defconstant(:dpt_scenecon, "DPT_SceneControl", "18.001")

  defconstant(:dpt_datetime, "Date Time", "19.*")
  defconstant(:dpt_datetime, "DPT_DateTime", "19.001")

  defconstant(:dpt_8bit_n8, "1-byte", "20.*")
  defconstant(:dpt_8bit_n8, "DPT_SCLOMode", "20.001")
  defconstant(:dpt_8bit_n8, "DPT_BuildingMode", "20.002")
  defconstant(:dpt_8bit_n8, "DPT_OccMode", "20.003")
  defconstant(:dpt_8bit_n8, "DPT_Priority", "20.004")
  defconstant(:dpt_8bit_n8, "DPT_LightApplicationMode", "20.005")
  defconstant(:dpt_8bit_n8, "DPT_ApplicationArea", "20.006")
  defconstant(:dpt_8bit_n8, "DPT_AlarmClassType", "20.007")
  defconstant(:dpt_8bit_n8, "DPT_PSUMode", "20.008")
  defconstant(:dpt_8bit_n8, "DPT_ErrorClass_System", "20.011")
  defconstant(:dpt_8bit_n8, "DPT_ErrorClass_HVAC", "20.012")
  defconstant(:dpt_8bit_n8, "DPT_Time_Delay", "20.013")
  defconstant(:dpt_8bit_n8, "DPT_Beaufort_Wind_Force_Scale", "20.014")
  defconstant(:dpt_8bit_n8, "DPT_SensorSelect", "20.017")
  defconstant(:dpt_8bit_n8, "DPT_ActuatorConnectType", "20.020")
  defconstant(:dpt_8bit_n8, "DPT_Cloud_Clover", "20.021")
  defconstant(:dpt_8bit_n8, "DPT_PowerReturnMode", "20.022")

  defconstant(:dpt_8bit_b8, "8-bit set", "21.*")
  defconstant(:dpt_8bit_b8, "DPT_StatusGen", "21.001")
  defconstant(:dpt_8bit_b8, "DPT_Device_Control", "21.002")

  defconstant(:dpt_16bit_n16, "16-bit set", "22.*")

  defconstant(:dpt_8bit_n2, "2-bit set", "23.*")
  defconstant(:dpt_8bit_n2, "DPT_OnOffAction", "23.001")
  defconstant(:dpt_8bit_n2, "DPT_Alarm_Reaction", "23.002")
  defconstant(:dpt_8bit_n2, "DPT_UpDown_Action", "23.003")

  defconstant(:dpt_varstring, "Variable String ISO-8859-1", "24.*")
  defconstant(:dpt_varstring, "DPT_VarString_8859_1", "24.001")

  defconstant(:dpt_8bit_n4, "2-nibble set", "25.*")
  defconstant(:dpt_8bit_n4, "DPT_DoubleNibble", "25.001")

  defconstant(:dpt_sceneinfo, "8-bit set", "26.*")
  defconstant(:dpt_sceneinfo, "DPT_SceneInfo", "26.001")

  defconstant(:dpt_combinedinfo, "32-bit set", "27.*")
  defconstant(:dpt_combinedinfo, "DPT_CombinedInfoOnOff", "27.001")

  defconstant(:dpt_utf8, "UTF-8 String", "28.*")
  defconstant(:dpt_utf8, "DPT_UTF-8", "28.001")

  defconstant(:dpt_electricalenergy, "Electrical Energy", "29.*")
  defconstant(:dpt_electricalenergy, "DPT_ActiveEnergy_V64", "29.010")
  defconstant(:dpt_electricalenergy, "DPT_ApparantEnergy_V64", "29.011")
  defconstant(:dpt_electricalenergy, "DPT_ReactiveEnergy_V64", "29.012")

  defconstant(:dpt_alarminfo, "Alarm Info", "219.*")
  defconstant(:dpt_alarminfo, "DPT_AlarmInfo", "219.001")

  @doc """
  Get all defined DPTs.

  This will return a list of `{type, name, value}`, i.e. `[{:dpt_1bit, "DPT_Switch", "1.001"}]`.
  """
  @spec get_dpts() :: [{dpt_type :: atom(), dpt_name :: String.t(), dpt :: String.t()}]
  def get_dpts() do
    @constants
  end
end
