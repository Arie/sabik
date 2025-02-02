# Sabik 350 Modbus Control

Control and monitor a Sabik 350 ventilation unit via Modbus and MQTT, allowing integration with Home Assistant.

## Prerequisites

- Ruby 3.0 or newer
- USB-Modbus converter connected to the Sabik
- MQTT broker (typically Home Assistant's built-in broker)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/Arie/sabik
cd sabik
```

2. Install dependencies:
```bash
gem install bundler && bundle
```

3. [Create a MQTT user in Home Assistant](https://community.home-assistant.io/t/mqtt-user-config/286096/2) if you don't already have one

4. Create a `secrets.rb` file with your MQTT credentials:
```ruby
MQTT_USER = 'your-ha-mqtt-user-here'
MQTT_PASSWORD = 'your-ha-mqtt-user-password-here'
MQTT_HOST = 'ip-address-or-hostname-of-ha-mqtt'
```

## Initial Setup

1. Create the sensors in Home Assistant:
```bash
ruby setup_mqtt.rb
```

2. Test the Modbus connection:
```bash
bundle console
```
Then in the console:
```ruby
require_relative 'sabik'
Sabik.new.status
```

You should see output like this:
```ruby
{:active_alarms=>0,
 :filter_alarm=>0,
 :temperature_sensor_extract_air_status=>0,
 # ... more status values ...
 :selected_air_volume=>1}
```

## Running the MQTT Subscriber

### Manual Start
```bash
ruby mqtt_subscriber.rb
```

### As a Systemd User Service

1. Create the systemd user directory:
```bash
mkdir -p ~/.config/systemd/user/
```

2. Create `~/.config/systemd/user/sabik-mqtt.service`:
```ini
[Unit]
Description=Sabik MQTT Control Service
After=network.target

[Service]
Type=simple
Environment="MQTT_HOST=your-ha-mqtt-host"
Environment="MQTT_USER=your-ha-mqtt-user"
Environment="MQTT_PASSWORD=your-ha-mqtt-password"
WorkingDirectory=%h/path/to/sabik
ExecStart=/usr/bin/ruby mqtt_subscriber.rb
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
```

3. Enable and start the service:
```bash
# Enable service
systemctl --user enable sabik-mqtt.service

# Start service
systemctl --user start sabik-mqtt.service

# Check status
systemctl --user status sabik-mqtt.service
```

## Testing and Control

Use the test script for manual control:
```bash
ruby test_mqtt_control.rb
```

Features available through the test script:
- Operation modes (off/auto/manual)
- Fan speeds (low/medium/high/auto/snooze)
- Bypass temperature settings:
  - Minimum indoor temperature (21-30°C)
  - Minimum outdoor temperature (12-20°C)
  - Minimum temperature difference (3-6°C)
- Manual and automatic bypass control
- Summer mode control
- Boost mode
- Time settings and synchronization
- Status monitoring

## Temperature-Dependent Features

### Bypass Mode
Bypass requires all these conditions:
- Indoor (Extract) temperature > minimum (default 23°C)
- Outdoor temperature > minimum (default 13°C)
- Temperature difference > minimum (default 3°C)

### Summer Mode
Requires:
- Outdoor temperature above minimum (uses same threshold as bypass)

## Troubleshooting

1. Serial Port Access:
```bash
# Add user to dialout group
sudo usermod -a -G dialout $USER
# Verify permissions
ls -l /dev/ttyUSB0
```

2. View Service Logs:
```bash
journalctl --user -u sabik-mqtt.service -f
```

3. Test MQTT Connection:
```bash
mosquitto_sub -h your-ha-mqtt-host -u your-mqtt-user -P your-mqtt-password -t 'homeassistant/climate/sabik/#'
```
