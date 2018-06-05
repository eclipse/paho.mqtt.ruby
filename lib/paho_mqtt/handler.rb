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



module PahoMqtt
  class Handler

    attr_reader :registered_callback
    attr_accessor :last_ping_resp
    attr_accessor :clean_session

    def initialize
      @registered_callback = []
      @last_ping_resp = -1
      @publisher = nil
      @subscriber = nil
    end

    def config_pubsub(publisher, subscriber)
      @publisher = publisher
      @subscriber = subscriber
    end

    def socket=(socket)
      @socket = socket
    end

    def receive_packet
      result = IO.select([@socket], [], [], SELECT_TIMEOUT) unless @socket.nil? || @socket.closed?
      unless result.nil?
        packet = PahoMqtt::Packet::Base.read(@socket)
        unless packet.nil?
          if packet.is_a?(PahoMqtt::Packet::Connack)
            @last_ping_resp = Time.now
            handle_connack(packet)
          else
            handle_packet(packet)
            @last_ping_resp = Time.now
          end
        end
      end
    end

    def handle_packet(packet)
      PahoMqtt.logger.info("New packet #{packet.class} recieved.") if PahoMqtt.logger?
      type = packet_type(packet)
      self.send("handle_#{type}", packet)
    end

    def register_topic_callback(topic, callback, &block)
      if topic.nil?
        PahoMqtt.logger.error("The topics where the callback is trying to be registered have been found nil.") if PahoMqtt.logger?
        raise ArgumentError
      end
      clear_topic_callback(topic)
      if block_given?
        @registered_callback.push([topic, block])
      elsif !(callback.nil?) && callback.is_a?(Proc)
        @registered_callback.push([topic, callback])
      end
      MQTT_ERR_SUCCESS
    end

    def clear_topic_callback(topic)
      if topic.nil?
        PahoMqtt.logger.error("The topics where the callback is trying to be unregistered have been found nil.") if PahoMqtt.logger?
        raise ArgumentError
      end
      @registered_callback.delete_if {|pair| pair.first == topic}
      MQTT_ERR_SUCCESS
    end

    def handle_connack(packet)
      if packet.return_code == 0x00
        PahoMqtt.logger.debug("Connack receive and connection accepted.") if PahoMqtt.logger?
        handle_connack_accepted(packet.session_present)
      else
        handle_connack_error(packet.return_code)
      end
      @on_connack.call(packet) unless @on_connack.nil?
      MQTT_CS_CONNECTED
    end

    def handle_connack_accepted(session_flag)
      clean_session?(session_flag)
      new_session?(session_flag)
      old_session?(session_flag)
    end

    def new_session?(session_flag)
      if !@clean_session && !session_flag
        PahoMqtt.logger.debug("New session created for the client") if PahoMqtt.logger?
      end
    end

    def clean_session?(session_flag)
      if @clean_session && !session_flag
        PahoMqtt.logger.debug("No previous session found by server, starting a new one.") if PahoMqtt.logger?
      end
    end

    def old_session?(session_flag)
      if !@clean_session && session_flag
        PahoMqtt.logger.debug("Previous session restored by the server.") if PahoMqtt.logger?
      end
    end

    def handle_pingresp(_packet)
      @last_ping_resp = Time.now
    end

    def handle_suback(packet)
      max_qos = packet.return_codes
      id = packet.id
      topics = []
      topics = @subscriber.add_subscription(max_qos, id, topics)
      unless topics.empty?
        @on_suback.call(topics) unless @on_suback.nil?
      end
    end

    def handle_unsuback(packet)
      id = packet.id
      topics = []
      topics = @subscriber.remove_subscription(id, topics)
      unless topics.empty?
        @on_unsuback.call(topics) unless @on_unsuback.nil?
      end
    end

    def handle_publish(packet)
      id = packet.id
      qos = packet.qos
      if @publisher.do_publish(qos, id) == MQTT_ERR_SUCCESS
        @on_message.call(packet) unless @on_message.nil?
        check_callback(packet)
      end
    end

    def handle_puback(packet)
      id = packet.id
      if @publisher.do_puback(id) == MQTT_ERR_SUCCESS
        @on_puback.call(packet) unless @on_puback.nil?
      end
    end

    def handle_pubrec(packet)
      id = packet.id
      if @publisher.do_pubrec(id) == MQTT_ERR_SUCCESS
        @on_pubrec.call(packet) unless @on_pubrec.nil?
      end
    end

    def handle_pubrel(packet)
      id = packet.id
      if @publisher.do_pubrel(id) == MQTT_ERR_SUCCESS
        @on_pubrel.call(packet) unless @on_pubrel.nil?
      end
    end

    def handle_pubcomp(packet)
      id = packet.id
      if @publisher.do_pubcomp(id) == MQTT_ERR_SUCCESS
        @on_pubcomp.call(packet) unless @on_pubcomp.nil?
      end
    end

    def handle_connack_error(return_code)
      if return_code == 0x01
        raise LowVersionException
      elsif CONNACK_ERROR_MESSAGE.has_key(return_code.to_sym)
        PahoMqtt.logger.warm(CONNACK_ERRO_MESSAGE[return_code])
        MQTT_CS_DISCONNECTED
      else
        PahoMqtt.logger("Unknown return code for CONNACK packet: #{return_code}")
        raise PacketException
      end
    end

    def on_connack(&block)
      @on_connack = block if block_given?
      @on_connack
    end

    def on_suback(&block)
      @on_suback = block if block_given?
      @on_suback
    end

    def on_unsuback(&block)
      @on_unsuback = block if block_given?
      @on_unsuback
    end

    def on_puback(&block)
      @on_puback = block if block_given?
      @on_puback
    end

    def on_pubrec(&block)
      @on_pubrec = block if block_given?
      @on_pubrec
    end

    def on_pubrel(&block)
      @on_pubrel = block if block_given?
      @on_pubrel
    end

    def on_pubcomp(&block)
      @on_pubcomp = block if block_given?
      @on_pubcomp
    end

    def on_message(&block)
      @on_message = block if block_given?
      @on_message
    end

    def on_connack=(callback)
      @on_connack = callback if callback.is_a?(Proc)
    end

    def on_suback=(callback)
      @on_suback = callback if callback.is_a?(Proc)
    end

    def on_unsuback=(callback)
      @on_unsuback = callback if callback.is_a?(Proc)
    end

    def on_puback=(callback)
      @on_puback = callback if callback.is_a?(Proc)
    end

    def on_pubrec=(callback)
      @on_pubrec = callback if callback.is_a?(Proc)
    end

    def on_pubrel=(callback)
      @on_pubrel = callback if callback.is_a?(Proc)
    end

    def on_pubcomp=(callback)
      @on_pubcomp = callback if callback.is_a?(Proc)
    end

    def on_message=(callback)
      @on_message = callback if callback.is_a?(Proc)
    end

    def packet_type(packet)
      type = packet.class
      if PahoMqtt::PACKET_TYPES[3..13].include?(type)
        type.to_s.split('::').last.downcase
      else
        puts "Packet: #{packet.inspect}"
        PahoMqtt.logger.error("Received an unexpeceted packet: #{packet}") if PahoMqtt.logger?
         raise PacketException
      end
    end

    def check_callback(packet)
      callbacks = []
      @registered_callback.each do |reccord|
        callbacks.push(reccord.last) if PahoMqtt.match_filter(packet.topic, reccord.first)
      end
      unless callbacks.empty?
        callbacks.each do |callback|
            callback.call(packet)
        end
      end
    end
  end
end
