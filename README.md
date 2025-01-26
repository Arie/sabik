# Sabik 350 Modbus

Some code to read all information from a Sabik 350

## Rough instructions

- Clone the project on a PC with USB-modbus converter connected to the Sabik
- Have a working Ruby installation, something version 3.0+
- Install the dependencies with `gem install bundler && bundle`
- [Create a mqtt user in home assistant](https://community.home-assistant.io/t/mqtt-user-config/286096/2) if you don't already have one.
- Edit the `secrets.rb` file:

```ruby
MQTT_USER = 'your-ha-mqtt-user-here'
MQTT_PASSWSORD = 'your-HA-mqtt-user-password-here'
MQTT_HOST = 'ip-address-or-hostname-of-ha-mqtt'
```
- Create the sensors in home assistant with `ruby setup_mqtt.rb`
- Run `bundle console` and enter these commands:

```ruby
require_relative 'sabik'
Sabik.new.status
```

If the output looks a little like this, all is good:

```ruby
{:active_alarms=>0,
 :filter_alarm=>0,
 :temperature_sensor_extract_air_status=>0,
 :temperature_sensor_exhaust_air_status=>0,
 :temperature_sensor_outdoor_air_status=>0,
 :temperature_sensor_supply_air_status=>0,
 :extract_air_fan_status=>0,
 :supply_air_fan_status=>0,
 :automatic_bypass=>0,
 :boost_contact_status=>0,
 :boost_status=>1,
 :reset_filter_alarm=>0,
 :manual_bypass=>0,
 :allow_automatic_bypass=>1,
 :summer_mode_status=>0,
 :manual_boost=>1,
 :snooze_mode=>0,
 :work_mode=>0,
 :communication_error=>0,
 :defrost_status=>"inactive",
 :extract_air_temperature=>201,
 :exhaust_air_temperature=>105,
 :outdoor_air_temperature=>57,
 :supply_air_temperature=>193,
 :rh_extract_air=>53,
 :rh_exhaust_air=>93,
 :rh_outdoor_air=>89,
 :rh_supply_air=>39,
 :control_voltage_extract_motor=>77,
 :control_voltage_supply_motor=>74,
 :rpm_extract_motor=>2594,
 :rpm_supply_motor=>2494,
 :bypass_valve_position=>"closed",
 :current_work_mode=>"boost",
 :modbus_slave_address=>1,
 :baudrate=>192,
 :modbus_parity=>0,
 :day=>27,
 :month=>1,
 :year=>2025,
 :hour=>1,
 :minutes=>25,
 :seconds=>5,
 :manual_bypass_timer=>8,
 :min_oda_for_bypass=>120,
 :min_eta_for_bypass=>230,
 :min_eta_oda_for_bypass=>30,
 :selected_air_volume=>1}
```

Run `ruby mqtt.rb` in the background and it will report the Sabik status to home assistant over MQTT every 5 seconds.
