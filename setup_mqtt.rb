# frozen_string_literal: true

require_relative 'secrets'
require_relative 'sabik'
require 'mqtt'
require 'json'

@broker = "mqtt://#{MQTT_USER}:#{MQTT_PASSWORD}@#{MQTT_HOST}"
@standard_options = { state_topic: 'homeassistant/sabik/sabikstatus',
                      enabled_by_default: 'true',
                      device: {
                        identifiers: [
                          'sabik'
                        ],
                        name: 'sabik',
                        model: 'S&P Sabik 350',
                        manufacturer: 'S&P'
                      } }

def generate(hash)
  JSON.generate(
    @standard_options.merge(hash)
  )
end

def publish(client, key, options, sensor_type = 'sensor')
  puts generate(options).inspect
  client.publish("homeassistant/#{sensor_type}/sabik/#{key}/config", generate(options), retain: true)
end

def publish_temperatures(client)
  publish(client, 'sabik_extract_air_temperature', {
            name: 'Extract Air Temperature',
            value_template: "{{ value_json['extract_air_temperature']| float / 10.0 | float }}",
            state_class: 'measurement',
            device_class: 'temperature',
            unit_of_measurement: '°C',
            unique_id: 'sabik_350_extract_air_temperature'
          })
  publish(client, 'sabik_supply_air_temperature', {
            name: 'Supply Air Temperature',
            state_topic: 'homeassistant/sabik/sabikstatus',
            value_template: "{{ value_json['supply_air_temperature']| float / 10.0 | float }}",
            state_class: 'measurement',
            device_class: 'temperature',
            unit_of_measurement: '°C',
            unique_id: 'sabik_350_supply_air_temperature'
          })
  publish(client, 'sabik_exhaust_air_temperature', {
            name: 'Exhaust Air Temperature',
            state_topic: 'homeassistant/sabik/sabikstatus',
            value_template: "{{ value_json['exhaust_air_temperature']| float / 10.0 | float }}",
            state_class: 'measurement',
            device_class: 'temperature',
            unit_of_measurement: '°C',
            unique_id: 'sabik_350_exhaust_air_temperature'
          })
  publish(client, 'sabik_outdoor_air_temperature', {
            name: 'Outdoor Air Temperature',
            state_topic: 'homeassistant/sabik/sabikstatus',
            value_template: "{{ value_json['outdoor_air_temperature']| float / 10.0 | float }}",
            state_class: 'measurement',
            device_class: 'temperature',
            unit_of_measurement: '°C',
            unique_id: 'sabik_350_outdoor_air_temperature'
          })
end

def publish_motors(client)
  publish(client, 'sabik_rpm_extract_motor', {
            name: 'RPM Extract Motor',
            state_topic: 'homeassistant/sabik/sabikstatus',
            value_template: "{{ value_json['rpm_extract_motor'] }}",
            state_class: 'measurement',
            unit_of_measurement: 'RPM',
            unique_id: 'sabik_350_rpm_extract_motor'
          })
  publish(client, 'sabik_rpm_supply_motor', {
            name: 'RPM Supply Motor',
            state_topic: 'homeassistant/sabik/sabikstatus',
            value_template: "{{ value_json['rpm_supply_motor'] }}",
            state_class: 'measurement',
            unit_of_measurement: 'RPM',
            unique_id: 'sabik_350_rpm_supply_motor'
          })
end

def publish_voltages(client)
  publish(client, 'sabik_control_voltage_extract_motor', {
            name: 'Voltage Extract Motor',
            state_topic: 'homeassistant/sabik/sabikstatus',
            value_template: "{{ value_json['control_voltage_extract_motor'] }}",
            device_class: 'voltage',
            state_class: 'measurement',
            unit_of_measurement: 'V',
            unique_id: 'sabik_350_control_voltage_extract_motor'
          })
  publish(client, 'sabik_control_voltage_supply_motor', {
            name: 'Voltage Supply Motor',
            state_topic: 'homeassistant/sabik/sabikstatus',
            value_template: "{{ value_json['control_voltage_supply_motor'] }}",
            device_class: 'voltage',
            state_class: 'measurement',
            unit_of_measurement: 'V',
            unique_id: 'sabik_350_control_voltage_supply_motor'
          })
end

def publish_humidity(client, key, name)
  publish(client, "sabik_#{key}", {
            name: name,
            state_topic: 'homeassistant/sabik/sabikstatus',
            value_template: "{{ value_json['#{key}'] }}",
            state_class: 'measurement',
            device_class: 'humidity',
            unit_of_measurement: '%',
            unique_id: "sabik_350_#{key}"
          })
end

def publish_humidities(client)
  {
    rh_extract_air: 'RH Extract Air',
    rh_exhaust_air: 'RH Exhaust Air',
    rh_outdoor_air: 'RH Outdoor Air',
    rh_supply_air: 'RH Supply Air'
  }.each do |k, v|
    publish_humidity(client, k, v)
  end
end

MQTT::Client.connect(@broker) do |c|
  publish(c, 'sabik_defrost_status', {
            name: 'Defrost Status',
            value_template: "{{ value_json['defrost_status'] }}",
            unique_id: 'sabik_350_defrost_status',
            device_class: 'enum',
            options: %w[
              inactive active_fireplace active_preheater active_unbalanced_airvolume
            ]
          })
  publish(c, 'sabik_filter_alarm', {
            name: 'Filter Alarm',
            value_template: "{{ value_json['filter_alarm'] }}",
            device_class: 'problem',
            unique_id: 'sabik_350_filter_alarm',
            payload_on: '1',
            payload_off: '0'
          }, 'binary_sensor')
  publish(c, 'sabik_extract_fan_alarm', {
            name: 'Extract Fan Alarm',
            value_template: "{{ value_json['extract_air_fan_status'] }}",
            device_class: 'problem',
            unique_id: 'sabik_350_extract_air_fan_status',
            payload_on: '1',
            payload_off: '0'
          }, 'binary_sensor')
  publish(c, 'sabik_supply_fan_alarm', {
            name: 'Supply Fan Alarm',
            value_template: "{{ value_json['supply_air_fan_status'] }}",
            device_class: 'problem',
            unique_id: 'sabik_350_supply_air_fan_status',
            payload_on: '1',
            payload_off: '0'
          }, 'binary_sensor')
  publish(c, 'sabik_summer_mode', {
            name: 'Summer mode',
            value_template: "{{ value_json['summer_mode_status'] }}",
            unique_id: 'sabik_350_summer_mode_status',
            payload_on: '1',
            payload_off: '0'
          }, 'binary_sensor')
  publish(c, 'sabik_selected_air_volume', {
            name: 'Selected air volume',
            value_template: "{{ value_json['selected_air_volume'] }}",
            unique_id: 'sabik_350_selected_air_volume',
          })
  publish(c, 'sabik_boost_status', {
            name: 'Boost status',
            value_template: "{{ value_json['boost_status'] }}",
            unique_id: 'sabik_350_boost_status',
            payload_on: '1',
            payload_off: '0'
          }, 'binary_sensor')
  publish(c, 'sabik_current_work_mode', {
            name: 'Current Work Mode',
            value_template: "{{ value_json['current_work_mode'] }}",
            unique_id: 'sabik_350_current_work_mode',
            device_class: 'enum',
            options: %w[
              snooze low medium high boost auto_humidity auto_voc auto_0_10v_control auto_boost week_program_1 week_program_2 week_program_3 week_program_4 unknown
            ]
          })
  publish(c, 'sabik_bypass_valve_position', {
            name: 'Bypass valve position',
            value_template: "{{ value_json['bypass_valve_position'] }}",
            unique_id: 'sabik_350_bypass_valve_position',
            device_class: 'enum',
            options: %w[
              closed open error unknown
            ]
          })
  publish_temperatures(c)
  publish_motors(c)
  publish_humidities(c)
  publish_voltages(c)
end
