require_relative './secrets'
require_relative './sabik'
require 'mqtt'
require 'json'

broker = "mqtt://mqtt:#{MQTT_PASSWORD}@127.0.0.1"


MQTT::Client.connect(broker) do |c|
  c.publish('homeassistant/sensor/sabik/sabik_defrost_status/config', JSON.generate({
    name: "Defrost Status",
    state_topic: "homeassistant/sabik/sabikstatus",
    value_template: "{{ value_json['defrost_status'] }}",
    unique_id: "sabik_350_defrost_status",
    "device_class": "enum",
    "options": [
      'inactive', 'active_fireplace', 'active_preheater', 'active_unbalanced_airvolume'
    ],
    "enabled_by_default": "true",
    "device": {
      "identifiers": [
        "sabik"
      ],
      "name": "sabik",
      "model": "S&P Sabik 350",
      "manufacturer": "S&P"
    }
  }
  ), retain: true)
  c.publish('homeassistant/sensor/sabik/sabik_current_work_mode/config', JSON.generate({
    name: "Current Work Mode",
    state_topic: "homeassistant/sabik/sabikstatus",
    value_template: "{{ value_json['current_work_mode'] }}",
    unique_id: "sabik_350_current_work_mode",
    "device_class": "enum",
    "options": [
      'snooze', 'low', 'medium', 'high', 'boost', 'auto_humidity', 'auto_voc', 'auto_0_10v_control', 'auto_boost', 'week_program_1', 'week_program_2', 'week_program_3', 'week_program_4', 'unknown'
    ],
    "enabled_by_default": "true",
    "device": {
      "identifiers": [
        "sabik"
      ],
      "name": "sabik",
      "model": "S&P Sabik 350",
      "manufacturer": "S&P"
    }
  }
  ), retain: true)
  c.publish('homeassistant/sensor/sabik/sabik_extract_air_temperature/config', JSON.generate({
    name: "Extract Air Temperature",
    state_topic: "homeassistant/sabik/sabikstatus",
    value_template: "{{ value_json['extract_air_temperature']| float / 10.0 | float }}",
    state_class: "measurement",
    device_class: "temperature",
    unit_of_measurement: "°C",
    unique_id: "sabik_350_extract_air_temperature",
    "enabled_by_default": "true",
    "device": {
      "identifiers": [
        "sabik"
      ],
      "name": "sabik",
      "model": "S&P Sabik 350",
      "manufacturer": "S&P"
    }
  }
  ), retain: true)
  c.publish('homeassistant/sensor/sabik/sabik_supply_air_temperature/config', JSON.generate({
    name: "Supply Air Temperature",
    state_topic: "homeassistant/sabik/sabikstatus",
    value_template: "{{ value_json['supply_air_temperature']| float / 10.0 | float }}",
    state_class: "measurement",
    device_class: "temperature",
    unit_of_measurement: "°C",
    unique_id: "sabik_350_supply_air_temperature",
    "enabled_by_default": "true",
    "device": {
      "identifiers": [
        "sabik"
      ],
      "name": "sabik",
      "model": "S&P Sabik 350",
      "manufacturer": "S&P"
    }
  }
  ), retain: true)
  c.publish('homeassistant/sensor/sabik/sabik_exhaust_air_temperature/config', JSON.generate({
    name: "Exhaust Air Temperature",
    state_topic: "homeassistant/sabik/sabikstatus",
    value_template: "{{ value_json['exhaust_air_temperature']| float / 10.0 | float }}",
    state_class: "measurement",
    device_class: "temperature",
    unit_of_measurement: "°C",
    unique_id: "sabik_350_exhaust_air_temperature",
    "enabled_by_default": "true",
    "device": {
      "identifiers": [
        "sabik"
      ],
      "name": "sabik",
      "model": "S&P Sabik 350",
      "manufacturer": "S&P"
    }
  }
  ), retain: true)
  c.publish('homeassistant/sensor/sabik/sabik_outdoor_air_temperature/config', JSON.generate({
    name: "Outdoor Air Temperature",
    state_topic: "homeassistant/sabik/sabikstatus",
    value_template: "{{ value_json['outdoor_air_temperature']| float / 10.0 | float }}",
    state_class: "measurement",
    device_class: "temperature",
    unit_of_measurement: "°C",
    unique_id: "sabik_350_outdoor_air_temperature",
    "enabled_by_default": "true",
    "device": {
      "identifiers": [
        "sabik"
      ],
      "name": "sabik",
      "model": "S&P Sabik 350",
      "manufacturer": "S&P"
    }
  }
  ), retain: true)
  c.publish('homeassistant/sensor/sabik/sabik_rpm_extract_motor/config', JSON.generate({
    name: "RPM Extract Motor",
    state_topic: "homeassistant/sabik/sabikstatus",
    value_template: "{{ value_json['rpm_extract_motor'] }}",
    state_class: "measurement",
    unit_of_measurement: "RPM",
    unique_id: "sabik_350_rpm_extract_motor",
    "enabled_by_default": "true",
    "device": {
      "identifiers": [
        "sabik"
      ],
      "name": "sabik",
      "model": "S&P Sabik 350",
      "manufacturer": "S&P"
    }
  }
  ), retain: true)
  c.publish('homeassistant/sensor/sabik/sabik_rpm_supply_motor/config', JSON.generate({
    name: "RPM Supply Motor",
    state_topic: "homeassistant/sabik/sabikstatus",
    value_template: "{{ value_json['rpm_supply_motor'] }}",
    state_class: "measurement",
    unit_of_measurement: "RPM",
    unique_id: "sabik_350_rpm_supply_motor",
    "enabled_by_default": "true",
    "device": {
      "identifiers": [
        "sabik"
      ],
      "name": "sabik",
      "model": "S&P Sabik 350",
      "manufacturer": "S&P"
    }
  }
  ), retain: true)
end
