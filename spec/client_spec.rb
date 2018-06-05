$:.unshift(File.dirname(__FILE__))

require 'spec_helper'

describe PahoMqtt::Client do
  context "From scratch" do
    it "Initialize the client with default parameter" do
      client = PahoMqtt::Client.new
      expect(client.host).to eq("")
      expect(client.port).to eq(1883)
      expect(client.mqtt_version).to eq('3.1.1')
      expect(client.clean_session).to be true
      expect(client.client_id).not_to be_nil
      expect(client.username).to be_nil
      expect(client.password).to be_nil
      expect(client.ssl).to be false
      expect(client.will_topic).to be_nil
      expect(client.will_payload).to be_nil    
      expect(client.will_qos).to eq(0)
      expect(client.will_retain).to be false
      expect(client.keep_alive).to eq(60)
      expect(client.ack_timeout).to eq(5)
    end

    it "Initialize the client paramter" do
      client = PahoMqtt::Client.new(
        :host => 'localhost',
        :port => 8883,
        :mqtt_version => '3.1.1',
        :clean_session => false,
        :client_id => "my_client1234",
        :username => 'Foo Bar',
        :password => 'barfoo',
        :ssl => false,
        :will_topic => "my_will_topic",
        :will_payload => "Bye Bye",
        :will_qos => 1,
        :will_retain => true,
        :keep_alive => 20,
        :ack_timeout => 3,
        :on_message => lambda { |packet| puts packet }
      )
      
      expect(client.host).to eq('localhost')
      expect(client.port).to eq(8883)
      expect(client.mqtt_version).to eq('3.1.1')
      expect(client.clean_session).to be false
      expect(client.client_id).to eq("my_client1234") 
      expect(client.username).to eq('Foo Bar')
      expect(client.password).to eq('barfoo')
      expect(client.ssl).to be false
      expect(client.will_topic).to eq("my_will_topic")
      expect(client.will_payload).to eq("Bye Bye")    
      expect(client.will_qos).to eq(1)
      expect(client.will_retain).to be true
      expect(client.keep_alive).to eq(20)
      expect(client.ack_timeout).to eq(3)
      expect(client.on_message.is_a?(Proc)).to be true
      expect(client.ssl_context).to be nil
    end

    context "when ssl option is set to true" do
      it "assigns ssl option" do
        client = PahoMqtt::Client.new(ssl: true)
        expect(client.ssl).to be true
      end

      it "creates new ssl context" do
        allow(OpenSSL::SSL::SSLContext).to receive(:new).and_return(:new_ssl_context)
        client = PahoMqtt::Client.new(ssl: true)
        expect(client.ssl_context).to eq(:new_ssl_context)
      end
    end
  end
  
  context "Configure ssl context" do
    let(:client) { PahoMqtt::Client.new(:ssl => true) }
    
    it "Set up a ssl context with key and certificate" do
      client.config_ssl_context(cert_path('client.crt'), cert_path('client.key'))
      expect(client.ssl_context.key).to be_a(OpenSSL::PKey::RSA)
      expect(client.ssl_context.cert).to be_a(OpenSSL::X509::Certificate)
    end

    it "Set up an ssl context with key, certificate and rootCA"do
      client.config_ssl_context(cert_path('client.crt'), cert_path('client.key'), cert_path('ca.crt'))
      expect(client.ssl_context.ca_file).to eq(cert_path('ca.crt'))
    end
  end

  context "With a defined host" do
    let(:client) { PahoMqtt::Client.new(:host => 'localhost') }
    before(:each) do
      expect(client.connection_state).to eq(PahoMqtt::MQTT_CS_DISCONNECT)
    end

    after(:each) do
      client.disconnect
    end

    it "Connect with unencrypted mode" do
      client.connect(client.host, client.port, 20)
      expect(client.keep_alive).to eq(20)
      expect(client.connection_state).to eq(PahoMqtt::MQTT_CS_CONNECTED)
    end

    it "Connect with encrypted mode with Certificate Authority" do
      client.port = 8883
      client.config_ssl_context(cert_path('client.crt'), cert_path('client.key'), cert_path('ca.crt'))
      client.connect(client.host, client.port)
      expect(client.connection_state).to eq(PahoMqtt::MQTT_CS_CONNECTED)
    end

    it "Connect with encrypted mode" do
      client.port = 8883
      client.config_ssl_context(cert_path('client.crt'), cert_path('client.key'))
      client.connect(client.host, client.port)
      expect(client.connection_state).to eq(PahoMqtt::MQTT_CS_CONNECTED)
    end

    it "Connect and verify the on_connack callback" do
      connected = false
      client.on_connack do
        connected = true
      end
      client.connect
      expect(connected).to be true
    end
    
    it "Automaticaly disconnect after the keep alive run out on not persistent mode" do
      client.ack_timeout = 2
      client.connect(client.host, client.port)
      expect(client.connection_state).to eq(PahoMqtt::MQTT_CS_CONNECTED)
      client.keep_alive = 1 # Make the client disconnect
      sleep 3
      expect(client.connection_state).to eq(PahoMqtt::MQTT_CS_DISCONNECT)
      client.keep_alive = 15
      sleep client.ack_timeout
      expect(client.connection_state).to eq(PahoMqtt::MQTT_CS_DISCONNECT)
    end
  end

  context "Already connected client" do
    let(:client) { PahoMqtt::Client.new(:host => 'localhost', :ack_timeout => 2) }
    let(:valid_topics) { Array({"/My_all_topic/#"=> 2, "My_private_topic" => 1}) }
    let(:unsub_topics) { Array("My_private_topic/#")}
    let(:invalid_topics) { Array({"" => 1, "topic_invalid_qos" => 42}) }
    let(:publish_content) { Hash(:topic => "My_private_topic", :payload => "Hello World!", :qos => 1, :retain => false) }
    
    before(:each) do
      client.connect(client.host, client.port)
      expect(client.connection_state).to eq(PahoMqtt::MQTT_CS_CONNECTED)
    end

    after(:each) do
      client.disconnect
    end

    it "Subscribe to valid topic and return success" do
      expect(client.subscribe(valid_topics)).to eq(PahoMqtt::MQTT_ERR_SUCCESS)
    end

    it "Subscribe to a topic and update the subscribed topic" do
      subscribed = false
      client.on_suback = lambda { |pck| subscribed  = true }
      client.subscribe(valid_topics)
      while !subscribed do
        sleep 0.001
      end
      expect(client.subscribed_topics).to eq(valid_topics)
    end

    it "Subscribe to a topic and verifiy the on_suback callback"do
      subscribed = false
      client.on_suback = lambda { |pck| subscribed = true }
      client.subscribe(valid_topics)
      while !subscribed do
        sleep 0.0001
      end
      expect(subscribed).to be true
    end

    it "Try to subscribe to an empty topic" do
      expect { client.subscribe(invalid_topics[0]) }.to raise_error(PahoMqtt::ProtocolViolation)
    end

    # Failed because message broker already close socket so can not disconnect
    # it "Try to subscribe to topic with invalid qos" do
    #   subscribed = false
    #   client.on_suback = lambda { |pck| subscribed = true }
    #   expect {
    #     client.subscribe(invalid_topics[1])
    #     while !subscribed do
    #       sleep 0.0001
    #     end
    #   }.to raise_error(Exception)
    # end

    it "Unsubscribe from a valid topic" do
      expect(client.unsubscribe(valid_topics)).to eq(PahoMqtt::MQTT_ERR_SUCCESS)
    end

    it "Unsubscribe and check if the subscribed topics have been updated" do
      subscribed = false
      client.on_suback = lambda { |pck| subscribed = true }
      client.subscribe(valid_topics)
      while !subscribed do
        sleep 0.0001
      end
      expect(client.subscribed_topics).to eq(valid_topics)
      unsubscribed = false
      client.on_unsuback = lambda { |pck| unsubscribed = true }
      client.unsubscribe(valid_topics.flatten[0])
      while !unsubscribed do
        sleep 0.0001
      end
      expect(client.subscribed_topics).not_to eq(valid_topics)
    end

    it "Try to unsubscribe from an empty topic" do
      expect{ client.unsubscribe(invalid_topics[0]) }.to raise_error(PahoMqtt::ProtocolViolation)
    end

    it "Try to unsubscribe to topic with invalid qos" do
      unsubscribed = false
      client.on_unsuback = lambda { |pck| unsubscribed = true }
      expect {
        client.subscribe(invalid_topics[1])
        while !subscribed do
          sleep 0.0001
        end
      }.to raise_error(::Exception)
    end

    it "Publish a packet to a valid topic"do
      expect(client.publish(publish_content[:topic], publish_content[:payload], publish_content[:retain], publish_content[:qos])).to eq(PahoMqtt::MQTT_ERR_SUCCESS)
    end

    it "Publish to a topic and verify the on_message callback" do
      message = false
      client.on_message = proc { |packet| message = true }
      expect(message).to be false
      client.subscribe(valid_topics)
      client.publish(publish_content[:topic], publish_content[:payload], publish_content[:retain], publish_content[:qos])
      while !message do
        sleep 0.0001
      end
      expect(message).to be true
    end

    it "Publish a packet to an invalid topic" do
      expect {
        client.publish(publish_content[:topic], publish_content[:payload], publish_content[:retain], 42)
      }.to raise_error(PahoMqtt::PacketFormatException, /Invalid QoS value/)
    end

    it "Publish to a topic and verify the callback registered for a specific topic" do
      filter = false
      client.add_topic_callback("/My_all_topic/topic1") do
        filter = true
      end
      expect(filter).to be false
      client.subscribe(valid_topics)
      client.publish("/My_all_topic/topic1", "Hello World", false, 1)
      while !filter do
        sleep 0.0001
      end
      expect(filter).to be true
    end

    it "Publish to topic and verify the callback registered for a wildcard" do
      wildcard = false
      client.add_topic_callback("/My_all_topic/+") do
        wildcard = true
      end
      expect(wildcard).to be false
      client.subscribe(valid_topics)
      client.publish("/My_all_topic/topic1", "Hello World", false, 1)
      while !wildcard do
        sleep 0.0001
      end
      expect(wildcard).to be true
    end

    it "Publish to a subscribed topic where callback is removed" do
      message = false
      client.on_message = lambda {|pck| message = true}
      filter = false
      client.add_topic_callback("/My_all_topic/topic1") do
        filter = true
      end
      expect(filter).to be false
      expect(message).to be false
      client.subscribe(["/My_all_topic/topic1", 1])
      sleep 1
      client.publish("/My_all_topic/topic1", "Hello World", false, 0)
      while !message && !filter do
        sleep 0.0001
      end
      expect(filter).to be true
      expect(message).to be true
      filter = false
      message = false
      client.remove_topic_callback("/My_all_topic/topic1")
      client.publish("/My_all_topic/topic1", "Hello World", false, 0)      
      while !message do
        sleep 0.0001
      end
      expect(filter).to be false
      expect(message).to be true
    end

    it "Publish with qos 1 to subcribed topic and verfiy the on_puback callback" do
      puback = false
      client.on_puback do
        puback = true
      end
      expect(puback).to be false
      client.subscribe(valid_topics)
      client.publish(publish_content[:topic], publish_content[:payload], publish_content[:retain], 1)
      while !puback do
        sleep 0.0001
      end
      expect(puback).to be true
    end

    it "Publish with qos 2 to subcribed topic and verfiy the on_pubrec, on_pubrel and on_pubcomp callback" do
      pubrec = false
      pubrel = false
      pubcomp = false
      client.on_pubrec do
        pubrec = true
      end
      client.on_pubrel = proc { pubrel = true }
      client.on_pubcomp = lambda { |pck| pubcomp = true }
      expect(pubrec).to be false
      expect(pubrel).to be false
      expect(pubcomp).to be false
      client.subscribe(["My_test_qos_2_topic", 2])
      client.publish("My_test_qos_2_topic", "Foo Bar", false, 2)
      while !pubrec || !pubrel || !pubcomp do
        sleep 0.0001
      end

      expect(pubrec).to be true
      expect(pubrel).to be true
      expect(pubcomp).to be true
    end
  end

  context "Already connected client on persistent mode" do
    let(:client) { PahoMqtt::Client.new({:host => 'localhost', :ack_timeout => 2, :persistent => true})}
    let(:valid_topics) { Array({"/My_all_topic/#"=> 2, "My_private_topic" => 1}) }

    before(:each) do
      client.connect
      expect(client.connection_state).to eq(PahoMqtt::MQTT_CS_CONNECTED)
    end

    after(:each) do
      client.disconnect
    end

    it "Automatically try to reconnect after a unexpected disconnect on persistent mode" do
      connack = false
      client.on_connack = lambda { |pck| connack = true; client.keep_alive = 15 }
      client.keep_alive = 0 # Make the client disconnect
      while !connack do
        sleep 0.01
      end
      expect(client.connection_state).to eq(PahoMqtt::MQTT_CS_CONNECTED)
    end

    it "Automatically resubscribe after unexpected disconnect" do
      client.subscribe(valid_topics)
      on_message = false
      client.on_message {|pck| on_message = true }
      client.on_connack { client.keep_alive = 15 }
      client.publish("My_private_topic", "Foo Bar", false, 1)
      while !on_message do
        sleep 0.0001
      end
      on_message = false
      client.keep_alive = 0 # Make the client disconnect
      while client.connection_state != PahoMqtt::MQTT_CS_CONNECTED do
        sleep 0.0001
      end
      client.publish("My_private_topic", "Foo Bar", false, 1)
      on_message = false
      while !on_message do
        sleep 0.0001
      end
      expect(on_message).to be true
    end
  end
end
