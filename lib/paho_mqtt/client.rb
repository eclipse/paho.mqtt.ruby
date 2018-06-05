# Copyright (c) 2016-2017 Pierre Goudet <p-goudet@ruby-dev.jp>
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# and Eclipse Distribution License v1.0 which accompany this distribution.
#
# The Eclipse Public License is available at
#    https://eclipse.org/org/documents/epl-v10.php.
# and the Eclipse Distribution License is available at
#   https://eclipse.org/org/documents/edl-v10.php.
#
# Contributors:
#    Pierre Goudet - initial committer
#    And Others.

require 'paho_mqtt/handler'
require 'paho_mqtt/connection_helper'
require 'paho_mqtt/sender'
require 'paho_mqtt/publisher'
require 'paho_mqtt/subscriber'
require 'paho_mqtt/ssl_helper'

module PahoMqtt
  class Client
    # Connection related attributes:
    attr_accessor :host
    attr_accessor :port
    attr_accessor :mqtt_version
    attr_accessor :clean_session
    attr_accessor :persistent
    attr_accessor :blocking
    attr_accessor :client_id
    attr_accessor :username
    attr_accessor :password
    attr_accessor :ssl

    # Last will attributes:
    attr_accessor :will_topic
    attr_accessor :will_payload
    attr_accessor :will_qos
    attr_accessor :will_retain

    # Timeout attributes:
    attr_accessor :keep_alive
    attr_accessor :ack_timeout

    #Read Only attribute
    attr_reader :connection_state
    attr_reader :ssl_context

    def initialize(*args)
      @last_ping_resp = Time.now
      @last_packet_id = 0
      @ssl_context = nil
      @sender = nil
      @handler = Handler.new
      @connection_helper = nil
      @connection_state = MQTT_CS_DISCONNECT
      @connection_state_mutex = Mutex.new
      @mqtt_thread = nil
      @reconnect_thread = nil
      @id_mutex = Mutex.new

      if args.last.is_a?(Hash)
        attr = args.pop
      else
        attr = {}
      end

      CLIENT_ATTR_DEFAULTS.merge(attr).each_pair do |k,v|
        self.send("#{k}=", v)
      end

      if @ssl
        @ssl_context = OpenSSL::SSL::SSLContext.new
      end

      if @port.nil?
        if @ssl
          @port = DEFAULT_SSL_PORT
        else
          @port = DEFAULT_PORT
        end
      end

      if  @client_id.nil? || @client_id == ""
        @client_id = generate_client_id
      end
    end

    def generate_client_id(prefix='paho_ruby', lenght=16)
      charset = Array('A'..'Z') + Array('a'..'z') + Array('0'..'9')
      @client_id = prefix << Array.new(lenght) { charset.sample }.join
    end

    def config_ssl_context(cert_path, key_path, ca_path=nil)
      @ssl ||= true
      @ssl_context = SSLHelper.config_ssl_context(cert_path, key_path, ca_path)
    end

    def connect(host=@host, port=@port, keep_alive=@keep_alive, persistent=@persistent, blocking=@blocking)
      @persistent = persistent
      @blocking = blocking
      @host = host
      @port = port.to_i
      @keep_alive = keep_alive
      @connection_state_mutex.synchronize {
        @connection_state = MQTT_CS_NEW
      }
      @mqtt_thread.kill unless @mqtt_thread.nil?
      init_connection
      @connection_helper.send_connect(session_params)
      begin
        @connection_state = @connection_helper.do_connect(reconnect?)
        if connected?
          build_pubsub
          daemon_mode unless @blocking
        end
      rescue LowVersionException
        downgrade_version
      end
    end

    def daemon_mode
      @mqtt_thread = Thread.new do
        @reconnect_thread.kill unless @reconnect_thread.nil? || !@reconnect_thread.alive?
        begin
          while connected? do
            mqtt_loop
          end
        rescue SystemCallError => e
          if @persistent
            reconnect()
          else
            raise e
          end
        end
      end
    end

    def connected?
      @connection_state == MQTT_CS_CONNECTED
    end

    def reconnect?
      Thread.current == @reconnect_thread
    end

    def loop_write(max_packet=MAX_WRITING)
      begin
        @sender.writing_loop(max_packet)
      rescue WritingException
        if check_persistence
          reconnect
        else
          raise WritingException
        end
      end
    end

    def loop_read(max_packet=MAX_READ)
      max_packet.times do
        begin
          @handler.receive_packet
        rescue ReadingException
          if check_persistence
            reconnect
          else
            raise ReadingException
          end
        end
      end
    end

    def mqtt_loop
      loop_read
      loop_write
      loop_misc
      sleep LOOP_TEMPO
    end

    def loop_misc
      if @connection_helper.check_keep_alive(@persistent, @handler.last_ping_resp, @keep_alive) == MQTT_CS_DISCONNECT
        reconnect if check_persistence
      end
      @publisher.check_waiting_publisher
      @subscriber.check_waiting_subscriber
    end

    def reconnect
      @reconnect_thread = Thread.new do
        RECONNECT_RETRY_TIME.times do
          PahoMqtt.logger.debug("New reconnect atempt...") if PahoMqtt.logger?
          connect
          if connected?
            break
          else
            sleep RECONNECT_RETRY_TIME
          end
        end
        unless connected?
          PahoMqtt.logger.error("Reconnection atempt counter is over.(#{RECONNECT_RETRY_TIME} times)") if PahoMqtt.logger?
          disconnect(false)
        end
      end
    end

    def disconnect(explicit=true)
      @last_packet_id = 0 if explicit
      @connection_helper.do_disconnect(@publisher, explicit, @mqtt_thread)
      @connection_state_mutex.synchronize {
        @connection_state = MQTT_CS_DISCONNECT
      }
      MQTT_ERR_SUCCESS
    end

    def publish(topic, payload="", retain=false, qos=0)
      if topic == "" || !topic.is_a?(String)
        PahoMqtt.logger.error("Publish topics is invalid, not a string or empty.") if PahoMqtt.logger?
        raise ArgumentError
      end
      id = next_packet_id
      @publisher.send_publish(topic, payload, retain, qos, id)
      MQTT_ERR_SUCCESS
    end

    def subscribe(*topics)
      begin
        id = next_packet_id
        unless @subscriber.send_subscribe(topics, id) == PahoMqtt::MQTT_ERR_SUCCESS
          reconnect if check_persistence
        end
        MQTT_ERR_SUCCESS
      rescue ProtocolViolation
        PahoMqtt.logger.error("Subscribe topics need one topic or a list of topics.") if PahoMqtt.logger?
        disconnect(false)
        raise ProtocolViolation
      end
    end

    def unsubscribe(*topics)
      begin
        id = next_packet_id
        unless @subscriber.send_unsubscribe(topics, id) == MQTT_ERR_SUCCESS
          reconnect if check_persistence
        end
        MQTT_ERR_SUCCESS
      rescue ProtocolViolation
        PahoMqtt.logger.error("Unsubscribe need at least one topics.") if PahoMqtt.logger?
        disconnect(false)
        raise ProtocolViolation
      end
    end

    def ping_host
      @sender.send_pingreq
    end

    def add_topic_callback(topic, callback=nil, &block)
      @handler.register_topic_callback(topic, callback, &block)
    end

    def remove_topic_callback(topic)
      @handler.clear_topic_callback(topic)
    end

    def on_connack(&block)
      @handler.on_connack = block if block_given?
      @handler.on_connack
    end

    def on_suback(&block)
      @handler.on_suback = block if block_given?
      @handler.on_suback
    end

    def on_unsuback(&block)
      @handler.on_unsuback = block if block_given?
      @handler.on_unsuback
    end

    def on_puback(&block)
      @handler.on_puback = block if block_given?
      @handler.on_puback
    end

    def on_pubrec(&block)
      @handler.on_pubrec = block if block_given?
      @handler.on_pubrec
    end

    def on_pubrel(&block)
      @handler.on_pubrel = block if block_given?
      @handler.on_pubrel
    end

    def on_pubcomp(&block)
      @handler.on_pubcomp = block if block_given?
      @handler.on_pubcomp
    end

    def on_message(&block)
      @handler.on_message = block if block_given?
      @handler.on_message
    end

    def on_connack=(callback)
      @handler.on_connack = callback if callback.is_a?(Proc)
    end

    def on_suback=(callback)
      @handler.on_suback = callback if callback.is_a?(Proc)
    end

    def on_unsuback=(callback)
      @handler.on_unsuback = callback if callback.is_a?(Proc)
    end

    def on_puback=(callback)
      @handler.on_puback = callback if callback.is_a?(Proc)
    end

    def on_pubrec=(callback)
      @handler.on_pubrec = callback if callback.is_a?(Proc)
    end

    def on_pubrel=(callback)
      @handler.on_pubrel = callback if callback.is_a?(Proc)
    end

    def on_pubcomp=(callback)
      @handler.on_pubcomp = callback if callback.is_a?(Proc)
    end

    def on_message=(callback)
      @handler.on_message = callback if callback.is_a?(Proc)
    end

    def registered_callback
      @handler.registered_callback
    end

    def subscribed_topics
      @subscriber.subscribed_topics
    end


    private

    def next_packet_id
      @id_mutex.synchronize {
        @last_packet_id = ( @last_packet_id || 0 ).next
      }
    end

    def downgrade_version
      PahoMqtt.logger.debug("Unable to connect to the server with the version #{@mqtt_version}, trying 3.1") if PahoMqtt.logger?
      if @mqtt_version != "3.1"
        @mqtt_version = "3.1"
        connect(@host, @port, @keep_alive)
      else
        raise "Unsupported MQTT version"
      end
    end

    def build_pubsub
      if @subscriber.nil?
        @subscriber = Subscriber.new(@sender)
      else
        @subscriber.sender = @sender
        @subscriber.config_subscription(next_packet_id)
      end
      if @publisher.nil?
        @publisher = Publisher.new(@sender)
      else
        @publisher.sender = @sender
        @publisher.config_all_message_queue
      end
      @handler.config_pubsub(@publisher, @subscriber)
      @sender.flush_waiting_packet(true)
    end

    def init_connection
      unless reconnect?
        @connection_helper = ConnectionHelper.new(@host, @port, @ssl, @ssl_context, @ack_timeout)
        @connection_helper.handler = @handler
        @sender = @connection_helper.sender
      end
        @connection_helper.setup_connection
    end

    def session_params
      {:version => @mqtt_version,
       :clean_session => @clean_session,
       :keep_alive => @keep_alive,
       :client_id => @client_id,
       :username => @username,
       :password => @password,
       :will_topic => @will_topic,
       :will_payload => @will_payload,
       :will_qos => @will_qos,
       :will_retain => @will_retain}
    end

    def check_persistence
      disconnect(false)
      @persistent
    end
  end
end
