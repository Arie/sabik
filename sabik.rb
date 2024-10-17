# frozen_string_literal: true

require 'rmodbus'
require 'ccutrer-serialport'
require 'json'
require 'pry-nav'

class Sabik
  attr_accessor :device, :baud_rate, :opts

  def initialize
    @device = '/dev/ttyUSB0'
    @baud_rate = 19_200
    @opts = { parity: :even }
  end

  def set_air_volume!(value)
    write_single_register(132, value)
  end

  def set_min_extract_temp_for_bypass!(value)
    write_single_register(65, (value * 10.0).round)
  end

  def set_delta_temp_for_bypass!(value)
    if value > 3.0 && value < 6.0
      write_single_register(67, (value * 10.0).round)
    else
      'must be between 3.0 and 6.0'
    end
  end

  def reset_filter_alarm!
    write_single_coil(0, 1)
  end

  def bypass!
    write_single_coil(7, 1)
  end

  def unbypass!
    write_single_coil(7, 0)
  end

  def allow_auto_bypass!
    write_single_coil(8, 0)
  end

  def deny_auto_bypass!
    write_single_coil(8, 1)
  end

  def summer!
    write_single_coil(9, 1)
  end

  def unsummer!
    write_single_coil(9, 0)
  end

  def boost!
    write_single_coil(16, 1)
  end

  def unboost!
    write_single_coil(16, 0)
  end

  def snooze!
    write_single_coil(17, 1)
  end

  def unsnooze!
    write_single_coil(17, 0)
  end

  def work_mode_manual!
    write_single_coil(25, 0)
  end

  def work_mode_auto!
    write_single_coil(25, 1)
  end

  def status
    output = {}
    ModBus::RTUClient.connect(device, baud_rate, opts) do |cl|
      discrete_inputs = []
      output_coils = []
      input_registers = []
      holding_registers = []
      cl.with_slave(1) do |slave|
        discrete_inputs = all_discrete_inputs(slave)
        output_coils = all_output_coils(slave)
        input_registers = all_input_registers(slave)
        holding_registers = all_holding_registers(slave)
      end

      all_discrete_inputs_keys.each_with_index do |key, i|
        output[key] = discrete_inputs[i]
      end

      all_output_coils_keys.each_with_index do |key, i|
        output[key] = output_coils[i]
      end

      all_input_registers_keys.each_with_index do |key, i|
        output[key] = input_registers[i]
      end

      all_holding_registers_keys.each_with_index do |key, i|
        output[key] = holding_registers[i]
      end
    end
    output[:current_work_mode] = working_mode_to_string(output[:current_work_mode])
    output[:defrost_status] = defrost_status_to_string(output[:defrost_status])
    output[:bypass_valve_position] = bypass_valve_position_to_string(output[:bypass_valve_position])
    output
  end

  def write_single_coil(register, value)
    ModBus::RTUClient.connect(device, baud_rate, opts) do |cl|
      cl.with_slave(1) do |slave|
        slave.write_single_coil(register, value)
      end
    end
  end

  def write_single_register(register, value)
    ModBus::RTUClient.connect(device, baud_rate, opts) do |cl|
      cl.with_slave(1) do |slave|
        slave.write_single_register(register, value)
      end
    end
  end

  def working_mode_to_string(working_mode)
    case working_mode&.to_i
    when 0
      'snooze'
    when 1
      'low'
    when 2
      'medium'
    when 3
      'high'
    when 4
      'boost'
    when 5
      'auto_humidity'
    when 7
      'auto_voc'
    when 8
      'auto_0_10v_control'
    when 9
      'auto_boost'
    when 10
      'week_program_1'
    when 11
      'week_program_2'
    when 12
      'week_program_3'
    else
      'unknown'
    end
  end

  def defrost_status_to_string(status)
    case status&.to_i
    when 0
      'inactive'
    when 1
      'active_fireplace'
    when 2
      'active_preheater'
    when 3
      'active_unbalanced_airvolume'
    else
      'unknown'
    end
  end

  def bypass_valve_position_to_string(status)
    case status&.to_i
    when 0
      'closed'
    when 1
      'open'
    when 2
      'error'
    else
      'unknown'
    end
  end

  def all_discrete_inputs(slave)
    [
      slave.read_discrete_inputs(0, 2),
      slave.read_discrete_inputs(6, 6),
      slave.read_discrete_input(15),
      slave.read_discrete_inputs(28, 2)
    ].flatten
  end

  def all_discrete_inputs_keys
    %i[active_alarms filter_alarm temperature_sensor_extract_air_status temperature_sensor_exhaust_air_status
       temperature_sensor_outdoor_air_status temperature_sensor_supply_air_status extract_air_fan_status
       supply_air_fan_status automatic_bypass boost_contact_status boost_status]
  end

  def all_output_coils(slave)
    [
      slave.read_coil(0),
      slave.read_coils(7, 3),
      slave.read_coils(16, 2),
      slave.read_coil(25)
    ].flatten
  end

  def all_output_coils_keys
    %i[reset_filter_alarm manual_bypass allow_automatic_bypass summer_mode_status manual_boost snooze_mode work_mode]
  end

  def all_input_registers(slave)
    [
      slave.read_input_registers(4, 2),
      slave.read_input_registers(25, 8),
      slave.read_input_registers(59, 5),
      slave.read_input_register(90)
    ].flatten
  end

  def all_input_registers_keys
    %i[communication_error defrost_status extract_air_temperature exhaust_air_temperature outdoor_air_temperature supply_air_temperature rh_extract_air rh_exhaust_air rh_outdoor_air rh_supply_air control_voltage_extract_motor control_voltage_supply_motor rpm_extract_motor rpm_supply_motor bypass_valve_position current_work_mode]
  end

  def all_holding_registers(slave)
    [
      slave.read_holding_registers(0, 3),
      slave.read_holding_registers(48, 6),
      slave.read_holding_register(56),
      slave.read_holding_register(63),
      slave.read_holding_register(65),
      slave.read_holding_register(67),
      slave.read_holding_register(132)
    ].flatten
  end

  def all_holding_registers_keys
    %i[modbus_slave_address baudrate modbus_parity day month year hour minutes seconds manual_bypass_timer min_oda_for_bypass min_eta_for_bypass min_eta_oda_for_bypass selected_air_volume]
  end
end
