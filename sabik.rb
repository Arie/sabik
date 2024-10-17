
require 'rmodbus'
require 'ccutrer-serialport'
require 'json'

DEVICE = '/dev/ttyUSB0'
BAUD_RATE = 19_200
OPTS = { parity: :even }

def all_discrete_inputs(slave)
  [
    slave.read_discrete_inputs(0, 2),
    slave.read_discrete_inputs(6, 6),
    slave.read_discrete_input(15),
    slave.read_discrete_inputs(28, 2)
  ].flatten
end

def all_discrete_inputs_keys
  [:active_alarms, :filter_alarm, :temperature_sensor_extract_air_status, :temperature_sensor_exhaust_air_status,
   :temperature_sensor_outdoor_air_status, :temperature_sensor_supply_air_status, :extract_air_fan_status,
   :supply_air_fan_status, :automatic_bypass, :boost_contact_status, :boost_status]
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
  [:reset_filter_alarm, :manual_bypass, :allow_automatic_bypass, :summer_mode_status, :manual_boost, :snooze_mode, :work_mode]
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
  [:communication_error, :defrost_status, :extract_air_temperature, :exhaust_air_temperature, :outdoor_air_temperature, :supply_air_temperature, :rh_extract_air, :rh_exhaust_air, :rh_outdoor_air, :rh_supply_air, :control_voltage_extract_motor, :control_voltage_supply_motor, :rpm_extract_motor, :rpm_supply_motor, :bypass_valve_position, :current_work_mode]
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
  [:modbus_slave_address, :baudrate, :modbus_parity, :day, :month, :year, :hour, :minutes, :seconds, :manual_bypass_timer, :min_oda_for_bypass, :min_eta_for_bypass, :min_eta_oda_for_bypass, :selected_air_volume]
end


ModBus::RTUClient.connect(DEVICE, BAUD_RATE, OPTS) do |cl|
  output = {}
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

  puts JSON.pretty_generate(output)
end

