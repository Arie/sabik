require 'mqtt'
require 'json'
require_relative 'sabik'
require_relative 'secrets'
require 'logger'

class MQTTSubscriber
  MQTT_TOPIC_PREFIX = 'homeassistant/climate/sabik'
  STATUS_TOPIC = 'homeassistant/sabik/sabikstatus'
  STATUS_UPDATE_INTERVAL = 5 # seconds
  MODES = {
    'off' => 'snooze',
    'auto' => 'auto',
    'manual' => 'manual'
  }
  FAN_MODES = ['low', 'medium', 'high', 'auto', 'snooze']

  def initialize(broker_address: 'localhost', port: 1883, username: nil, password: nil)
    @client = MQTT::Client.new
    @client.host = broker_address
    @client.port = port
    @client.username = username if username
    @client.password = password if password
    @sabik = Sabik.new
    @current_mode = 'auto'
    @current_fan_mode = 'medium'
    @last_status_update = Time.now
    @sabik_mutex = Mutex.new

    # Setup logging
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::DEBUG
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] Subscriber: #{msg}\n"
    end
  end

  def start
    @logger.info("Connecting to MQTT broker at #{@client.host}:#{@client.port}")

    begin
      @client.connect do |client|
        @logger.info("Connected to MQTT broker")

        @logger.debug("Publishing discovery config")
        publish_discovery_config

        # Subscribe to control topics
        topic = "#{MQTT_TOPIC_PREFIX}/+/set"
        @logger.debug("Subscribing to topic: #{topic}")
        client.subscribe(topic)

        # Publish initial states
        publish_full_status

        # Create status update thread
        status_thread = Thread.new do
          loop do
            begin
              sleep STATUS_UPDATE_INTERVAL
              publish_full_status
            rescue StandardError => e
              @logger.error("Error in status thread: #{e.message}")
              @logger.debug(e.backtrace.join("\n"))
            end
          end
        end

        # Main message handling loop
        begin
          client.get do |topic, payload|
            @logger.debug("Received message - Topic: #{topic}, Payload: #{payload}")
            handle_message(topic, payload)
          end
        ensure
          status_thread.kill if status_thread
        end
      end
    rescue MQTT::ProtocolException => e
      @logger.error("MQTT Protocol Error: #{e.message}")
      @logger.error("This might be due to invalid credentials")
      @logger.debug(e.backtrace.join("\n"))
      sleep 5
      retry
    rescue StandardError => e
      @logger.error("Error in MQTT client: #{e.message}")
      @logger.debug(e.backtrace.join("\n"))
      sleep 5
      retry
    end
  end

  private

  def publish_discovery_config
    config = {
      name: "Sabik Ventilation",
      unique_id: "sabik_ventilation",
      device: {
        identifiers: ["sabik_ventilation"],
        name: "Sabik Ventilation",
        model: "Sabik",
        manufacturer: "Sabik"
      },
      mode_command_topic: "#{MQTT_TOPIC_PREFIX}/mode/set",
      mode_state_topic: "#{MQTT_TOPIC_PREFIX}/mode/state",
      modes: MODES.keys,
      fan_mode_command_topic: "#{MQTT_TOPIC_PREFIX}/fan_mode/set",
      fan_mode_state_topic: "#{MQTT_TOPIC_PREFIX}/fan_mode/state",
      fan_modes: FAN_MODES,
      temperature_command_topic: "#{MQTT_TOPIC_PREFIX}/temperature/set",
      temperature_state_topic: "#{MQTT_TOPIC_PREFIX}/temperature/state",
      current_temperature_topic: "#{MQTT_TOPIC_PREFIX}/current_temperature",
      min_temp: 15,
      max_temp: 30,
      temp_step: 0.5,
      summer_mode_command_topic: "#{MQTT_TOPIC_PREFIX}/summer_mode/set",
      summer_mode_state_topic: "#{MQTT_TOPIC_PREFIX}/summer_mode/state",
      # Add additional sensor topics
      exhaust_temperature_topic: "#{MQTT_TOPIC_PREFIX}/exhaust_temperature",
      outdoor_temperature_topic: "#{MQTT_TOPIC_PREFIX}/outdoor_temperature",
      supply_temperature_topic: "#{MQTT_TOPIC_PREFIX}/supply_temperature",
      extract_humidity_topic: "#{MQTT_TOPIC_PREFIX}/extract_humidity",
      exhaust_humidity_topic: "#{MQTT_TOPIC_PREFIX}/exhaust_humidity",
      outdoor_humidity_topic: "#{MQTT_TOPIC_PREFIX}/outdoor_humidity",
      supply_humidity_topic: "#{MQTT_TOPIC_PREFIX}/supply_humidity",
      filter_alarm_topic: "#{MQTT_TOPIC_PREFIX}/filter_alarm",
      active_alarms_topic: "#{MQTT_TOPIC_PREFIX}/active_alarms",
      defrost_status_topic: "#{MQTT_TOPIC_PREFIX}/defrost_status",
      boost_command_topic: "#{MQTT_TOPIC_PREFIX}/boost/set",
      boost_state_topic: "#{MQTT_TOPIC_PREFIX}/boost/state",
      auto_bypass_command_topic: "#{MQTT_TOPIC_PREFIX}/auto_bypass/set",
      auto_bypass_state_topic: "#{MQTT_TOPIC_PREFIX}/auto_bypass/state"
    }

    @client.publish("homeassistant/climate/sabik/config", config.to_json, retain: true)
  end

  def publish_state
    status = nil
    @sabik_mutex.synchronize do
      status = @sabik.status
    end

    # Publish all relevant temperatures
    @client.publish("#{MQTT_TOPIC_PREFIX}/current_temperature", status[:extract_air_temperature].to_s)
    @client.publish("#{MQTT_TOPIC_PREFIX}/exhaust_temperature", status[:exhaust_air_temperature].to_s)
    @client.publish("#{MQTT_TOPIC_PREFIX}/outdoor_temperature", status[:outdoor_air_temperature].to_s)
    @client.publish("#{MQTT_TOPIC_PREFIX}/supply_temperature", status[:supply_air_temperature].to_s)

    # Publish humidity values
    @client.publish("#{MQTT_TOPIC_PREFIX}/extract_humidity", status[:rh_extract_air].to_s)
    @client.publish("#{MQTT_TOPIC_PREFIX}/exhaust_humidity", status[:rh_exhaust_air].to_s)
    @client.publish("#{MQTT_TOPIC_PREFIX}/outdoor_humidity", status[:rh_outdoor_air].to_s)
    @client.publish("#{MQTT_TOPIC_PREFIX}/supply_humidity", status[:rh_supply_air].to_s)

    # Publish fan information
    @client.publish("#{MQTT_TOPIC_PREFIX}/extract_fan_rpm", status[:rpm_extract_motor].to_s)
    @client.publish("#{MQTT_TOPIC_PREFIX}/supply_fan_rpm", status[:rpm_supply_motor].to_s)
    @client.publish("#{MQTT_TOPIC_PREFIX}/extract_fan_voltage", status[:control_voltage_extract_motor].to_s)
    @client.publish("#{MQTT_TOPIC_PREFIX}/supply_fan_voltage", status[:control_voltage_supply_motor].to_s)

    # Publish current mode - updated logic
    current_mode = if status[:snooze_mode]
                    'off'
                  elsif status[:work_mode]  # true = auto, false = manual
                    'auto'
                  else
                    'manual'
                  end
    @client.publish("#{MQTT_TOPIC_PREFIX}/mode/state", current_mode)

    # Publish current fan mode - updated logic
    current_fan = case status[:selected_air_volume]
                 when 0 then 'low'
                 when 1 then 'medium'
                 when 2 then 'high'
                 when 3 then 'auto'
                 when 4 then 'snooze'
                 else 'medium'  # default to medium for unknown states
                 end
    @client.publish("#{MQTT_TOPIC_PREFIX}/fan_mode/state", current_fan)

    # Publish boost state separately
    @client.publish("#{MQTT_TOPIC_PREFIX}/boost/state",
                   status[:current_work_mode] == 'boost' ? 'ON' : 'OFF')

    # Publish bypass state
    @client.publish("#{MQTT_TOPIC_PREFIX}/bypass/state",
                   status[:bypass_valve_position] == 'open' ? 'ON' : 'OFF')

    # Publish summer mode state
    @client.publish("#{MQTT_TOPIC_PREFIX}/summer_mode/state",
                   status[:summer_mode_status] ? 'ON' : 'OFF')

    # Publish alarm states
    @client.publish("#{MQTT_TOPIC_PREFIX}/filter_alarm", status[:filter_alarm] ? 'ON' : 'OFF')
    @client.publish("#{MQTT_TOPIC_PREFIX}/active_alarms", status[:active_alarms] ? 'ON' : 'OFF')

    # Publish defrost status
    @client.publish("#{MQTT_TOPIC_PREFIX}/defrost_status", status[:defrost_status].to_s)

    # Add automatic bypass state
    @client.publish("#{MQTT_TOPIC_PREFIX}/auto_bypass/state",
                   status[:allow_automatic_bypass] ? 'ON' : 'OFF')
  end

  def publish_full_status
    @logger.debug("Publishing status update")
    status = nil
    @sabik_mutex.synchronize do
      status = @sabik.status
    end

    # Publish raw status like the old mqtt.rb did
    @client.publish('homeassistant/sabik/sabikstatus', status.to_json)

    # Also publish individual states for Home Assistant integration
    publish_state
  end

  def handle_message(topic, payload)
    @logger.info("Handling message - Topic: #{topic}, Payload: #{payload}")
    case topic
    when "#{MQTT_TOPIC_PREFIX}/mode/set"
      handle_mode_command(payload)
    when "#{MQTT_TOPIC_PREFIX}/fan_mode/set"
      handle_fan_mode_command(payload)
    when "#{MQTT_TOPIC_PREFIX}/boost/set"
      handle_boost_command(payload)
    when "#{MQTT_TOPIC_PREFIX}/temperature/set"
      handle_temperature_command(payload)
    when "#{MQTT_TOPIC_PREFIX}/bypass/set"
      handle_bypass_command(payload)
    when "#{MQTT_TOPIC_PREFIX}/summer_mode/set"
      handle_summer_mode_command(payload)
    when "#{MQTT_TOPIC_PREFIX}/min_eta_bypass/set"
      handle_min_eta_bypass_command(payload)
    when "#{MQTT_TOPIC_PREFIX}/min_oda_bypass/set"
      handle_min_oda_bypass_command(payload)
    when "#{MQTT_TOPIC_PREFIX}/min_eta_oda_bypass/set"
      handle_min_eta_oda_bypass_command(payload)
    when "#{MQTT_TOPIC_PREFIX}/time/set"
      handle_time_command(payload)
    when "#{MQTT_TOPIC_PREFIX}/time/sync"
      handle_time_sync_command(payload)
    when "#{MQTT_TOPIC_PREFIX}/auto_bypass/set"
      handle_auto_bypass_command(payload)
    end

    # Publish full status update immediately after any change
    publish_full_status
  end

  def handle_mode_command(payload)
    @logger.info("Handling mode command - Payload: #{payload}")
    @sabik_mutex.synchronize do
      case payload
      when 'off'
        @sabik.snooze!
      when 'auto'
        @sabik.unsnooze!
        @sabik.work_mode_auto!
      when 'manual'
        @sabik.unsnooze!
        @sabik.work_mode_manual!
      end
    end
  end

  def handle_fan_mode_command(payload)
    @logger.info("Handling fan mode command - Payload: #{payload}")
    @sabik_mutex.synchronize do
      status_before = @sabik.status
      @logger.debug("Before fan mode change: work_mode=#{status_before[:work_mode]} selected_air_volume=#{status_before[:selected_air_volume]}")

      # Disable snooze first unless we're setting snooze
      @sabik.unsnooze! unless payload == 'snooze'

      # Only switch to manual mode for specific speeds
      @sabik.work_mode_manual! unless ['auto', 'snooze'].include?(payload)

      case payload
      when 'low'
        @sabik.set_air_volume!(0)
      when 'medium'
        @sabik.set_air_volume!(1)
      when 'high'
        @sabik.set_air_volume!(2)
      when 'auto'
        @sabik.set_air_volume!(3)
      when 'snooze'
        @sabik.snooze!
      end

      status_after = @sabik.status
      @logger.debug("After fan mode change: work_mode=#{status_after[:work_mode]} selected_air_volume=#{status_after[:selected_air_volume]}")
    end
  end

  def handle_boost_command(payload)
    @logger.info("Handling boost command - Payload: #{payload}")
    @sabik_mutex.synchronize do
      case payload.upcase
      when 'ON'
        @sabik.unsnooze!  # Disable snooze before enabling boost
        @sabik.boost!
      when 'OFF'
        @sabik.unboost!
      end
    end
  end

  def handle_temperature_command(payload)
    @logger.info("Handling temperature command - Payload: #{payload}")
    begin
      temp = Float(payload)
      @sabik_mutex.synchronize do
        @sabik.set_min_extract_temp_for_bypass!(temp)
      end
    rescue ArgumentError
      @logger.error("Invalid temperature value: #{payload}")
    end
  end

  def handle_bypass_command(payload)
    @logger.info("Handling bypass command - Payload: #{payload}")
    @sabik_mutex.synchronize do
      status = @sabik.status
      outdoor_temp = status[:outdoor_air_temperature] / 10.0
      extract_temp = status[:extract_air_temperature] / 10.0
      min_outdoor = status[:min_oda_for_bypass] / 10.0
      min_extract = status[:min_eta_for_bypass] / 10.0
      min_diff = status[:min_eta_oda_for_bypass] / 10.0
      temp_diff = extract_temp - outdoor_temp

      @logger.info("Temperature conditions for bypass:")
      @logger.info("- Outdoor temp: #{outdoor_temp}°C (must be > #{min_outdoor}°C)")
      @logger.info("- Extract temp: #{extract_temp}°C (must be > #{min_extract}°C)")
      @logger.info("- Temperature difference: #{temp_diff}°C (must be > #{min_diff}°C)")

      case payload.upcase
      when 'ON'
        if outdoor_temp < min_outdoor
          @logger.warn("Cannot enable bypass: Outdoor temperature too low")
        elsif extract_temp < min_extract
          @logger.warn("Cannot enable bypass: Extract temperature too low")
        elsif temp_diff < min_diff
          @logger.warn("Cannot enable bypass: Temperature difference too small")
        else
          @sabik.bypass!
        end
      when 'OFF'
        @sabik.unbypass!
      end
    end
  end

  def handle_summer_mode_command(payload)
    @logger.info("Handling summer mode command - Payload: #{payload}")
    @sabik_mutex.synchronize do
      status = @sabik.status
      outdoor_temp = status[:outdoor_air_temperature] / 10.0
      min_outdoor = status[:min_oda_for_bypass] / 10.0  # Use same threshold as bypass

      @logger.info("Temperature conditions for summer mode:")
      @logger.info("- Outdoor temp: #{outdoor_temp}°C (must be > #{min_outdoor}°C)")

      case payload.upcase
      when 'ON'
        if outdoor_temp < min_outdoor
          @logger.warn("Cannot enable summer mode: Outdoor temperature too low")
        else
          @logger.debug("Calling summer!")
          @sabik.summer!
        end
      when 'OFF'
        @logger.debug("Calling unsummer!")
        @sabik.unsummer!
      end

      status_after = @sabik.status
      @logger.debug("After summer mode change: summer_mode_status=#{status_after[:summer_mode_status]}")
    end
  end

  def handle_min_eta_bypass_command(payload)
    @logger.info("Setting minimum indoor temperature for bypass - Payload: #{payload}")
    begin
      temp = Float(payload)
      @sabik_mutex.synchronize do
        @sabik.set_min_extract_temp_for_bypass!(temp)
      end
    rescue ArgumentError
      @logger.error("Invalid temperature value: #{payload}")
    end
  end

  def handle_min_oda_bypass_command(payload)
    @logger.info("Setting minimum outdoor temperature for bypass - Payload: #{payload}")
    begin
      temp = Float(payload)
      @sabik_mutex.synchronize do
        @sabik.set_min_outdoor_temp_for_bypass!(temp)
      end
    rescue ArgumentError
      @logger.error("Invalid temperature value: #{payload}")
    end
  end

  def handle_min_eta_oda_bypass_command(payload)
    @logger.info("Setting minimum temperature difference for bypass - Payload: #{payload}")
    begin
      temp = Float(payload)
      @sabik_mutex.synchronize do
        @sabik.set_delta_temp_for_bypass!(temp)
      end
    rescue ArgumentError
      @logger.error("Invalid temperature value: #{payload}")
    end
  end

  def handle_time_command(payload)
    @logger.info("Setting time manually - Payload: #{payload}")
    begin
      time = Time.parse(payload)
      @sabik_mutex.synchronize do
        @sabik.set_time!(time)
      end
      @logger.info("Time set to: #{time}")
    rescue ArgumentError => e
      @logger.error("Invalid time format: #{e.message}")
      @logger.info("Expected format: YYYY-MM-DD HH:MM:SS")
    end
  end

  def handle_time_sync_command(payload)
    @logger.info("Syncing time with local system time")
    @sabik_mutex.synchronize do
      local_time = Time.now
      @sabik.set_time!(local_time)
      @logger.info("Time synced to: #{local_time}")
    end
  end

  def handle_auto_bypass_command(payload)
    @logger.info("Setting automatic bypass - Payload: #{payload}")
    @sabik_mutex.synchronize do
      case payload.upcase
      when 'ON'
        @sabik.allow_auto_bypass!
        @logger.info("Automatic bypass enabled")
      when 'OFF'
        @sabik.deny_auto_bypass!
        @logger.info("Automatic bypass disabled")
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  # Validate required environment variables or secrets
  unless defined?(MQTT_HOST) && defined?(MQTT_USER) && defined?(MQTT_PASSWORD)
    puts "Error: Missing required MQTT configuration!"
    puts "Please ensure MQTT_HOST, MQTT_USER, and MQTT_PASSWORD are set"
    puts "either in secrets.rb or as environment variables."
    exit 1
  end

  client = MQTTSubscriber.new(
    broker_address: ENV['MQTT_HOST'] || MQTT_HOST,
    port: (ENV['MQTT_PORT'] || 1883).to_i,
    username: ENV['MQTT_USERNAME'] || MQTT_USER,
    password: ENV['MQTT_PASSWORD'] || MQTT_PASSWORD
  )
  client.start
end
