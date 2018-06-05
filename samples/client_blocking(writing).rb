require 'paho-mqtt'

PahoMqtt.logger = ('paho_mqtt.log')

client = PahoMqtt::Client.new()

client.on_message = lambda { |p|  puts ">>>>> This is the callback for a message event <<<<<\nTopic: #{p.topic}\nPayload: #{p.payload}\nQoS: #{p.qos}" }


client.connect('localhost', 1883, client.keep_alive, true, true)
client.subscribe(["topic_test", 2])

loop do
  client.publish("topic_test", "Hello, Are you there?", false, 1)
  client.loop_write
  client.loop_read
  sleep 1
end
