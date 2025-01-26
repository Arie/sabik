# frozen_string_literal: true

require_relative 'secrets'
require_relative 'sabik'
require 'mqtt'
require 'json'

@broker = "mqtt://#{MQTT_USER}:#{MQTT_PASSWORD}@#{MQTT_HOST}"

def run
  sabik_status = Sabik.new.status

  MQTT::Client.connect(@broker) do |c|
    c.publish('homeassistant/sabik/sabikstatus', JSON.generate(sabik_status))
  end
end

while true
  run
  sleep 5
end

