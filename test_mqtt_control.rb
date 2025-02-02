require 'mqtt'
require_relative 'secrets'
require 'logger'

class TestMQTTControl
  MQTT_TOPIC_PREFIX = 'homeassistant/climate/sabik'
  MODES = ['off', 'auto', 'manual']
  FAN_SPEEDS = ['low', 'medium', 'high', 'auto', 'snooze']
  SWITCH_STATES = ['ON', 'OFF']

  def initialize
    @client = MQTT::Client.new
    @client.host = ENV['MQTT_HOST'] || MQTT_HOST
    @client.port = (ENV['MQTT_PORT'] || 1883).to_i
    @client.username = ENV['MQTT_USERNAME'] || MQTT_USER
    @client.password = ENV['MQTT_PASSWORD'] || MQTT_PASSWORD

    # Setup logging
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::DEBUG
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] Tester: #{msg}\n"
    end
  end

  def send_command(command_type, value)
    topic = "#{MQTT_TOPIC_PREFIX}/#{command_type}/set"
    @logger.debug("Connecting to MQTT broker at #{@client.host}:#{@client.port}")
    @client.connect do |client|
      @logger.info("Publishing: #{value} to #{topic}")
      client.publish(topic, value)
      @logger.debug("Published successfully")
    end
  rescue StandardError => e
    @logger.error("Failed to send command: #{e.message}")
    @logger.debug(e.backtrace.join("\n"))
  end

  def show_menu
    puts "\nSabik Control Menu:"
    puts "1. Set Mode (#{MODES.join('/')})"
    puts "2. Set Fan Speed (#{FAN_SPEEDS.join('/')})"
    puts "   Note: 'auto' and 'snooze' are special modes"
    puts "   - low/medium/high require manual mode"
    puts "   - auto will use automatic fan control"
    puts "   - snooze will stop the unit for 1 hour"
    puts "3. Bypass Temperature Settings:"
    puts "   a. Set Min Indoor Temperature (21-30°C)"
    puts "      Indoor temperature must be above this"
    puts "   b. Set Min Outdoor Temperature (12-20°C)"
    puts "      Outdoor temperature must be above this"
    puts "   c. Set Min Temperature Difference (3-6°C)"
    puts "      Indoor must be this much warmer than outdoor"
    puts "4. Bypass Settings:"
    puts "   a. Set Manual Bypass (ON/OFF)"
    puts "   b. Set Automatic Bypass (ON/OFF)"
    puts "      Note: When ON, bypass opens automatically based on temperatures"
    puts "5. Set Summer Mode (ON/OFF)"
    puts "6. Set Boost (ON/OFF)"
    puts "7. Time Settings:"
    puts "   a. Set Time Manually (YYYY-MM-DD HH:MM:SS)"
    puts "   b. Sync with Local Time"
    puts "8. Monitor Status"
    puts "q. Quit"
    print "\nEnter choice: "
  end

  def monitor_status
    @logger.info("Starting status monitor...")
    @client.connect do |client|
      topics = [
        "#{MQTT_TOPIC_PREFIX}/+/state",
        "homeassistant/sabik/sabikstatus",
        "#{MQTT_TOPIC_PREFIX}/current_temperature",
        "#{MQTT_TOPIC_PREFIX}/exhaust_temperature",
        "#{MQTT_TOPIC_PREFIX}/outdoor_temperature",
        "#{MQTT_TOPIC_PREFIX}/supply_temperature"
      ]
      @logger.debug("Subscribing to topics: #{topics}")
      client.subscribe(topics)

      @logger.info("Monitoring status (Ctrl+C to stop)...")
      client.get do |topic, message|
        @logger.info("\nReceived message:")
        @logger.info("Topic: #{topic}")
        @logger.info("Message: #{message}")
      end
    end
  rescue StandardError => e
    @logger.error("Monitor error: #{e.message}")
    @logger.debug(e.backtrace.join("\n"))
  end

  def run
    loop do
      show_menu
      choice = gets.chomp.downcase

      case choice
      when '1'
        print "Enter mode (#{MODES.join('/')}): "
        mode = gets.chomp.downcase
        if MODES.include?(mode)
          send_command('mode', mode)
          @logger.info("Note: When setting to #{mode} mode:")
          case mode
          when 'manual'
            @logger.info("- Will first unsnooze and then set to manual mode")
            @logger.info("- Fan speed can be controlled (low/medium/high)")
          when 'auto'
            @logger.info("- Will first unsnooze and then set to auto mode")
            @logger.info("- Fan speed is controlled automatically")
          when 'off'
            @logger.info("- Will set to snooze mode")
          end
        else
          puts "Invalid mode! Must be one of: #{MODES.join(', ')}"
        end

      when '2'
        print "Enter fan speed (#{FAN_SPEEDS.join('/')}): "
        speed = gets.chomp.downcase
        if FAN_SPEEDS.include?(speed)
          send_command('fan_mode', speed)
          case speed
          when 'auto'
            @logger.info("Note: Setting fan speed to auto")
          when 'snooze'
            @logger.info("Note: Setting unit to snooze mode (will stop for 1 hour)")
          else
            @logger.info("Note: Setting fan speed will first switch to manual mode")
          end
        else
          puts "Invalid fan speed! Must be one of: #{FAN_SPEEDS.join(', ')}"
        end

      when '3'
        puts "\nBypass Temperature Settings:"
        puts "a. Set Min Indoor Temperature (21-30°C)"
        puts "b. Set Min Outdoor Temperature (12-20°C)"
        puts "c. Set Min Temperature Difference (3-6°C)"
        print "Enter choice (a/b/c): "
        subchoice = gets.chomp.downcase

        case subchoice
        when 'a'
          print "Enter minimum indoor temperature (21-30°C): "
          temp = gets.chomp.to_f
          if temp >= 21 && temp <= 30
            send_command('min_eta_bypass', temp)
            @logger.info("Set minimum indoor temperature for bypass to #{temp}°C")
          else
            puts "Invalid temperature! Must be between 21 and 30°C"
          end

        when 'b'
          print "Enter minimum outdoor temperature (12-20°C): "
          temp = gets.chomp.to_f
          if temp >= 12 && temp <= 20
            send_command('min_oda_bypass', temp)
            @logger.info("Set minimum outdoor temperature for bypass to #{temp}°C")
          else
            puts "Invalid temperature! Must be between 12 and 20°C"
          end

        when 'c'
          print "Enter minimum temperature difference (3-6°C): "
          temp = gets.chomp.to_f
          if temp >= 3 && temp <= 6
            send_command('min_eta_oda_bypass', temp)
            @logger.info("Set minimum temperature difference for bypass to #{temp}°C")
          else
            puts "Invalid temperature difference! Must be between 3 and 6°C"
          end

        else
          puts "Invalid choice!"
        end

      when '4'
        puts "\nBypass Settings:"
        puts "a. Set Manual Bypass (ON/OFF)"
        puts "b. Set Automatic Bypass (ON/OFF)"
        print "Enter choice (a/b): "
        subchoice = gets.chomp.downcase

        case subchoice
        when 'a'
          print "Enter bypass state (ON/OFF): "
          state = gets.chomp.upcase
          if SWITCH_STATES.include?(state)
            send_command('bypass', state)
            @logger.info("Setting manual bypass to #{state}")
          else
            puts "Invalid state! Must be ON or OFF"
          end

        when 'b'
          print "Enter automatic bypass state (ON/OFF): "
          state = gets.chomp.upcase
          if SWITCH_STATES.include?(state)
            send_command('auto_bypass', state)
            @logger.info("Setting automatic bypass to #{state}")
            if state == 'ON'
              @logger.info("Note: Bypass will open automatically when temperature conditions are met")
            end
          else
            puts "Invalid state! Must be ON or OFF"
          end

        else
          puts "Invalid choice!"
        end

      when '5'
        command_type = 'summer_mode'
        print "Enter state (ON/OFF): "
        state = gets.chomp.upcase
        if SWITCH_STATES.include?(state)
          send_command(command_type, state)
        else
          puts "Invalid state! Must be ON or OFF"
        end

      when '6'
        command_type = 'boost'
        print "Enter state (ON/OFF): "
        state = gets.chomp.upcase
        if SWITCH_STATES.include?(state)
          send_command(command_type, state)
        else
          puts "Invalid state! Must be ON or OFF"
        end

      when '7'
        puts "\nTime Settings:"
        puts "a. Set Time Manually"
        puts "b. Sync with Local Time"
        print "Enter choice (a/b): "
        subchoice = gets.chomp.downcase

        case subchoice
        when 'a'
          print "Enter time (YYYY-MM-DD HH:MM:SS): "
          time_str = gets.chomp
          begin
            # Basic validation
            Time.parse(time_str)  # Will raise ArgumentError if invalid
            send_command('time', time_str)
            @logger.info("Setting time to: #{time_str}")
          rescue ArgumentError
            puts "Invalid time format! Use: YYYY-MM-DD HH:MM:SS"
          end

        when 'b'
          send_command('time/sync', '')
          @logger.info("Syncing time with local system")

        else
          puts "Invalid choice!"
        end

      when '8'
        monitor_status

      when 'q'
        puts "Goodbye!"
        break

      else
        puts "Invalid choice!"
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  tester = TestMQTTControl.new
  tester.run
end
