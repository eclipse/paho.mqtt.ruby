# Eclipse Paho Ruby Client

The following file describes the Paho Mqtt client API for the ruby programming language. It enables applications to connect to an MQTT message broker threw the [MQTT](http://mqtt.org/) protocol (versions 3.1.1). MQTT is a lightweight protocol designed for IoT/M2M. A Mqtt client can connect to a message broker in order to publish and received data contained in short messages. The messages are exchanged on topics where the client has to subscribe for receiving message. This client was contributed to the Eclipse Foundation by Ruby development Inc. and includes code contributed from the [ruby-mqtt](https://github.com/njh/ruby-mqtt/) library.



## Project description:

The Paho project has been created to provide reliable open-source implementations of open and standard messaging protocols aimed at new, existing, and emerging applications for Machine-to-Machine (M2M) and Internet of Things (IoT).
Paho reflects the inherent physical and cost constraints of device connectivity. Its objectives include effective levels of decoupling between devices and applications, designed to keep markets open and encourage the rapid growth of scalable Web and Enterprise middleware and applications.


## Links

- Project Website: [https://www.eclipse.org/paho](https://www.eclipse.org/paho)
- Eclipse Project Information: [https://projects.eclipse.org/projects/iot.paho](https://projects.eclipse.org/projects/iot.paho)
- Paho Ruby Client Page: [https://eclipse.org/paho/clients/java/](https://eclipse.org/paho/clients/ruby)
- GitHub: [https://github.com/eclipse/paho.mqtt.ruby](https://github.com/eclipse/paho.mqtt.ruby)
- Twitter: [@eclipsepaho](https://twitter.com/eclipsepaho)
- Issues: [https://github.com/eclipse/paho.mqtt.ruby/issues](https://github.com/eclipse/paho.mqtt.ruby/issues)
- Mailing-list: [https://dev.eclipse.org/mailman/listinfo/paho-dev](https://dev.eclipse.org/mailman/listinfo/paho-dev)


## Contents
* [Installation](#installation)
* [Usage](#usage)
  * [Getting started](#getting-started)
* [Client](#client)
  * [Initialization](#initialization)
  * [Client's parameters](#clients-parameter)
  * [Subscription](#subscription)
  * [Publishing](#publishing)
* [Connection configuration](#connection-configuration)
  * [Unencrypted mode](#unencrypted-mode)
  * [Encrypted mode](#encrypted-mode)
  * [Persistence](#persistence)
  * [Foreground and Daemon](#foreground-and-daemon)
* [Control loops](#control-loops)
  * [Reading loop](#reading-loop)
  * [Writing loop](#writing-loop)
  * [Miscellaneous loop](#miscellaneous-loop)
* [Handlers and Callbacks](#handlers-and-callbacks)
  * [Handlers](#handlers)
  * [Callbacks](#callbacks)
* [Mosquitto (message broker)](#mosquitto-message-broker)
* [Thanks](#thanks)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'paho-mqtt'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install paho-mqtt

## Usage

### Getting started
The following samples files cover the main features of the client:
```ruby
require 'paho-mqtt'

### Create a simple client with default attributes
client = PahoMqtt::Client.new

### Register a callback on message event to display messages
message_counter = 0
client.on_message do |message|
  puts "Message recieved on topic: #{message.topic}\n>>> #{message.payload}"
  message_counter += 1
end

### Register a callback on suback to assert the subcription
waiting_suback = true
client.on_suback do
  waiting_suback = false
  puts "Subscribed"
end

### Register a callback for puback event when receiving a puback
waiting_puback = true
client.on_puback do
  waiting_puback = false
  puts "Message Acknowledged"
end

### Connect to the eclipse test server on port 1883 (Unencrypted mode)
client.connect('iot.eclipse.org', 1883)

### Subscribe to a topic
client.subscribe(['/paho/ruby/test', 2])

### Waiting for the suback answer and excute the previously set on_suback callback
while waiting_suback do
  sleep 0.001
end

### Publlish a message on the topic "/paho/ruby/test" with "retain == false" and "qos == 1"
client.publish("/paho/ruby/test", "Hello there!", false, 1)

while waiting_puback do
  sleep 0.001
end

### Waiting to assert that the message is displayed by on_message callback
sleep 1

### Calling an explicit disconnect
client.disconnect
```

## Client
### Initialization
The client may be initialized without paramaeters or with a hash of parameters. The list of client's accessor is details in the next parts. A client id would be generated if not provided, a default port would be also set (8883 if ssl set, else 1883).
```ruby
client = PahoMqtt::Client.new
# Or
client = PahoMqtt::Client.new({host: "iot.eclispe.org", port: 1883, ssl: false})
```

### Client's parameters
The client has many accessors which help to configure the client depending on user's need. The different accessors could be splited in four roles, connection setup, last will setup, time-out setup and callback setup.
Connection setup:
```
* host            : The endpoint where the client would try to connect (defaut "")
* port            : The port on the remote host where the socket would try to connect (default 1883)
* mqtt_version    : The version of MQTT protocol used to communication (default 3.1.1)
* clean_session   : If set to false, ask the message broker to try to restore the previous session (default true)
* persistent      : Keep the client connected even after keep alive timer run out, automatically try to reconnect on failure (default false)
* reconnect_limit : If persistent mode is enabled, the maximum reconnect attempt (default 3)
* reconnect_delay : If persistent mode is enabled, the delay between to reconnection attempt in second (default 5)
* client_id       : The identifier of the client (default nil)
* username        : The username if the server require authentication (default nil)
* password        : The password of the user if authentication required (default nil)
* ssl             : Requiring the encryption for the communication (default false)
```

Last Will:
```
* will_topic   : The topic where to publish the last will (default nil)
* will_payload : The message of the last will (default "")
* will_qos     : The qos of the last will (default 0)
* will_retain  : The retain status of the last will (default false)
```

Timers:
```
* keep_alive  : The reference timer after which the client should decide to keep the connection alive or not
* ack_timeout : The timer after which a non-acknowledged packet is considered as a failure
```

The description of the callback accessor is detailed in the section dedicated to the callbacks. The client also have three read only attributes which provide information on the client state.
```
* registered_callback : The list of topics where callback have been registred which the associated callback
* subscribed_topics   : The list of the topics where the client is currentely receiving publish.
* connection_state    : The current state of the connection between the message broker and the client
```

### Subscription
In order to read a message sent on a topic, the client should subscribe to this topic. The client enables to subscribe to several topics in the same subscribe request. The subscription could also be done by using a wild-card, see more details on [MQTT protocol specifications](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html). Each topic is subscribed with a maximum qos level, only message with a qos level lower or equal to this value would be forwarded to the client. The subscribe command accepts one or several pair, each pair is composed by the topic (or wild-card) and the maximum qos level.  
```ruby
### Subscribe to two topics with maximum qos associated
client.subscribe(["/foo/bar", 1], ["/foo/foo/", 2])
```

The subscription is persistent, in case of an unexpected disconnecting, the current subscription state is saved and a new subscribe request is sent to the message broker.

### Publishing
User data could be sent to the message broker with the publish operation. A publish operation requires a topic, and payload (user data), two other parameters may be configured, retain and qos. The retain flag tell to the message broker to keep the current publish packet, see the [MQTT protocol specifications](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html) for more details about retain. The qos enable different levels of control on the transmission of publish package. The PahoMqtt client supports the three levels of qos (0, 1 and 2), see the [MQTT protocol specifications](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html) for qos level details. The default retain value is False and the qos level is 0.
```ruby
### Publish to the topics "/foo/bar", with qos = 1 and no retain
client.publish("/foo/bar", "Hello Wourld!", false, 1)
```

## Connection configuration
### Unencrypted mode
The most simple connection way is the unencrypted mode. All data would be sent clearly to the message broker, also it might not be safe for sensitive data. The connect method may set up or override some parameters of the client, the host, the port, the keep_alive timer, the persistence mode and blocking mode.
```ruby
### Simply connect to the message broker with default value or pre-set value
client.connect
# Or
### Connect to the message broker with all parameter
client.connect("iot.eclipse.org", 1883, client.keep_alive, client.persistent, client.blocking)
```

### Encrypted mode
The client supports the encrypted connection threw tls-ssl socket. In order to use encrypted mode, the ssl flag of the client should be set to True.   
``` ruby
### Set the encryption mode to True
client.ssl = true
### Configure the user SSL key and the certificate
client.config_ssl_context(certificate_path, key_path)
client.connect("test.mosquitto.org", 8883)
### Or if rootCA is needed
client.config_ssl_context(certificate_path, key_path, rootCA_path)
client.connect("test.mosquitto.org", 8884)
```

### Persistence
The client holds a keep_alive timer is the reference time that the connection should be held. The timer is reset every time a new valid packet is received from the message broker. The persistence flag, when set to True, enables the client to be more independent from the keep_alive timer. Just before the keep_alive run out, the client sends a ping request to tell to the message broker that the connection should be kept. The persistent mode also enables the client to automatically reconnect to the message broker after an unexpected failure.  
When the client's persistence flag is set to False, it just simply disconnects when the keep_alive timer runs out.  
```ruby
### This will connect to the message broker, keep connected and automatically reconnect on failure
client.connect('iot.eclipse.org', 1883, client.keep_alive, true, client.blocking)
#Or
### This only connect to the message broker, disconnect after keep_alive or on failure
client.connect('iot.eclipse.org', 1883, client.keep_alive, false, client.blocking)
```
The client has two attributes `@reconnect_limit` and `@reconnect_delay` which configure the reconnection process. `@reconnection_limit` is the maximum reconnection attempt that a client could try and `@reconnection_delay` is the delay that the client waits between two reconnection attempt. Setting the `@reconnect_limit` to -1 would run the reconnection process forever. 

### Foreground and Daemon
The client could be connected to the message broker using the main thread in foreground or as a daemon in a separate thread. The default mode is daemon mode, the daemon would run in the background the read/write operation as well as the control of the timers. If the client is connected using the main thread, all control operations are left to the user, using the different control loops. There are four different loop roles is detailed in the next part.

```ruby
### Connect to the message broker executing the mqtt_loop (socket reading/writing) in the background
client.connect('iot.eclipse.org', 1883, client.keep_alive, client.persistence, true)
#Or
### This only connect to the message broker, nothing more
client.connect('iot.eclipse.org', 1883, client.keep_alive, client.persistence, false)
```

## Control loops
/!\ The control loops should not be used in a daemon mode.  
They are automatically run in separate thread and execute the necessary operations for reading, writing and checking the connection state.

### Reading loop
The reading loop provides access to the socket in a reading mode. Periodically, the socket would be inspected to try to find a mqtt packet. The read loop accepts a parameter, which is the number of loop's turn. The default value is five turns.  
The default value is defined in the PahoMqtt module as the constant PahoMqtt::MAX_READ, another module constant could be modified to control the socket inspection period. The referring constant is SELECT_TIMEOUT (PahoMqtt::SELECT_TIMEOUT) and its default value is 0.  
```ruby
### Trying to read 'max_packet' packets from the client socket
client.loop_read(max_packet)
```

### Writing loop
The writing loop send the packets which have previously been stacked by MQTT operations. This loop also accepts a parameter, which is the maximum packets number that could be written as the MAX_WRITING constant (PahoMqtt::MAX_WRITING). The writing loop exit if the maximum number of packet have been sent or if the waiting packet queue is empty.
```ruby
### Writing 'max_packet' packets to the client socket
client.loop_write(max_packet)
```

### Miscellaneous loop
The misc loop performs different control operations, modifying the packets states and the connection state. The misc loop parses the different queue of packet that are waiting for an acknowledgement. If the ack_timeout of a packet had run out, the packet is re-sent. The size of the different waiting queues is defined as module constants. This loop also asserts that the connection is still available by checking the keep_alive timer.
```ruby
### Perfom control operations on packets queues and connection
client.loop_misc
```

## Handlers and Callbacks
### Handlers
When a packet is received and inspected, an appropriate handler is called. The handler performs different control operation such as update the connection state, update the subscribed topics, and send publish control packets. Each packet has a specific handler, except the pingreq/pingresp packet. Before returning the handler executes a callback, if the user has configured one for this type of packet. The publish handler may execute sequentially two callbacks. One callback for the reception of a generic publish packet and another one, if the user has configured a callback for the topic where the publish packet has been received.  

### Callbacks
The callbacks could be defined in a three different ways, as block, as Proc or as Lambda. The callback has access to the packet which triggered it.  
```ruby
### Register a callback trigger on the reception of a CONNACK packet
client.on_connack = proc { puts "Successfully Connected" }

### Register a callback trigger on the reception of PUBLISH packet
client.on_message do |packet|
  puts "New message received on topic: #{packet.topic}\n>>>#{packet.payload}"
end
```

A callback could be configured for every specific topics. The list of topics where a callbacks have been registered could be read at any time, threw the registered_callback variable. The following example details how to manage callbacks for specific topics.  
```ruby
### Add a callback for every message received on /foo/bar
specific_callback = lambda { |packet| puts "Specific callback for #{packet.topic}" }
client.add_topic_callback("/foo/bar", specific_callback)
# Or
client.add_topic_callback("/foo/bar") do |packet|
  puts "Specific callback for #{packet.topic}"
end

### To remove a callback form a topic
client.remove_topic_callback("/foo/bar")
```

## Mosquitto (message broker)
Mosquitto is a message broker support by Eclipse, which is quite easy-going. In order to run spec or samples files, a message broker is needed. Mosquitto enable to run locally a message broker, it could be configured with the mosquitto.conf files.
### Install mosquitto
#### OSX (homebrew)
```
$ brew install mosquitto
```
### Run mosquitto
#### Default mode
The default mode of mosquitto is unencrypted, listening on the port 1883.
```
 $ mosquitto
```

#### Encrypted mode
In order to successfully pass the spec, or for testing in encrypted mode, some configurations are needed on mosquitto. Private keys and certificates should be set on both client side and server side. The [mosquitto-tls](https://mosquitto.org/man/mosquitto-tls-7.html) page might help you create all the required credentials. Once the credentials are created, the mosquitto's config files should be updated as following.

```
$ cp mosquitto.conf samples-mosquitto.conf
$ nano mosquitto.conf
```

The following file enables the broker to support the unencrypted mode (default) on port 1883, and the encrypted mode on port 8883. Update the path variable with the file's location on your environment. 
```
### mosquitto.conf
# =================================================================
# General configuration
# =================================================================
.
.
.
# =================================================================
# Extra listeners
# =================================================================
.
.
listener 8883
.
.
cafile   "Path to the certificate authorithy certificate file"
certfile "Path to the server certificate file"
keyfile  "Path to the server private keys file"
.
.
.
```
Finally run the server with the updated configuration file.

```
$ mosquitto -c mosquitto.conf
```

See [Mosquitto message broker page](https://mosquitto.org/) for more details.

## Thanks
Special thanks to [Nicholas Humfrey](https://github.com/njh) for providing a great help with the packet serializer/deserializer.
