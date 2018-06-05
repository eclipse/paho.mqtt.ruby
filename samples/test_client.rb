require "paho-mqtt"
require "logger"

cli = PahoMqtt::Client.new({persistent: true, keep_alive: 7})
PahoMqtt.logger = 'paho_log'

cli.connect('localhost', 1883)

#########################################################
### Callback settings
waiting = true
cli.on_suback { waiting = false}

cli.on_message = lambda { |p|  puts ">>>>> This is a LAMBDA callback for message event <<<<<\nTopic: #{p.topic}\nPayload: #{p.payload}\nQoS: #{p.qos}" }

foo_foo = lambda { |p| puts ">>>>> I am LAMBDA callback for the /foo/foo topic <<<<<" }
foo_bar = proc { puts ">>>>> I am PROC callback for the /foo/bar topic <<<<<" }


cli.add_topic_callback('/foo/tutu') do
  puts ">>>>> I am BLOCK callback for the /foo/tutu topic <<<<<"
end
cli.add_topic_callback('/foo/bar', foo_bar)
cli.add_topic_callback('/foo/foo', foo_foo)

#########################################################

cli.subscribe(['/foo/foo', 0], ['/foo/bar', 1], ['/foo/tutu', 2], ["/foo", 0])

while waiting do
  sleep 0.0001
end

cli.publish("/foo/tutu", "It's me!", false, 2)
cli.publish("/foo/tutu", "It's you!", false, 1)
cli.publish("/foo/tutu", "It's them!", false, 0)

cli.publish("/foo/bar", "It's me!", false, 2)
cli.publish("/foo/bar", "It's you!", false, 1)
cli.publish("/foo/bar", "It's them!", false, 0)

cli.publish("/foo/foo", "It's me!", false, 2)
cli.publish("/foo/foo", "It's you!", false, 1)
cli.publish("/foo/foo", "It's them!", false, 0)

sleep cli.ack_timeout

cli.on_message = nil
foo_tutu = lambda { |p| puts ">>>>> Changing callback type to LAMBDA for the /foo/tutu topic <<<<<" }
cli.add_topic_callback('/foo/tutu', foo_tutu)
cli.add_topic_callback('/foo/bar') do
  puts ">>>>> Changing callback type to BLOCK for the /foo/bar topic <<<<<"
end

cli.publish("/foo/tutu", "It's me!", false, 2)
cli.publish("/foo/tutu", "It's you!", false, 1)
cli.publish("/foo/tutu", "It's them!", false, 0)

cli.publish("/foo/bar", "It's me!", false, 2)
cli.publish("/foo/bar", "It's you!", false, 1)
cli.publish("/foo/bar", "It's them!", false, 0)

sleep cli.ack_timeout

cli.unsubscribe("+/tutu", "+/+")

puts "Waiting 10 sec for keeping alive..."
sleep 10

cli.disconnect
