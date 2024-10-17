require_relative './secrets'
require_relative './sabik'
require 'mqtt'
require 'json'

broker = "mqtt://mqtt:#{MQTT_PASSWORD}@127.0.0.1"

sabik_status = Sabik.new.status
pp sabik_status

MQTT::Client.connect(broker) do |c|
  c.publish('homeassistant/sabik/sabikstatus', JSON.generate(sabik_status))
end
