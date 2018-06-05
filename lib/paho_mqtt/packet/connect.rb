# encoding: BINARY
### original file from the ruby-mqtt gem
### located at https://github.com/njh/ruby-mqtt/blob/master/lib/mqtt/packet.rb
### Copyright (c) 2009-2013 Nicholas J Humfrey
### relicensed with permission by original author(s)

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
  module Packet
    class Connect < PahoMqtt::Packet::Base
      # The name of the protocol
      attr_accessor :protocol_name

      # The version number of the protocol
      attr_accessor :protocol_level

      # The client identifier string
      attr_accessor :client_id

      # Set to false to keep a persistent session with the server
      attr_accessor :clean_session

      # Period the server should keep connection open for between pings
      attr_accessor :keep_alive

      # The topic name to send the Will message to
      attr_accessor :will_topic

      # The QoS level to send the Will message as
      attr_accessor :will_qos

      # Set to true to make the Will message retained
      attr_accessor :will_retain

      # The payload of the Will message
      attr_accessor :will_payload

      # The username for authenticating with the server
      attr_accessor :username

      # The password for authenticating with the server
      attr_accessor :password

      # Default attribute values
      ATTR_DEFAULTS = {
        :client_id => nil,
        :clean_session => true,
        :keep_alive => 15,
        :will_topic => nil,
        :will_qos => 0,
        :will_retain => false,
        :will_payload => '',
        :username => nil,
        :password => nil,
      }

      # Create a new Client Connect packet
      def initialize(args={})
        super(ATTR_DEFAULTS.merge(args))

        if version == '3.1.0' or version == '3.1'
          self.protocol_name ||= 'MQIsdp'
          self.protocol_level ||= 0x03
        elsif version == '3.1.1'
          self.protocol_name ||= 'MQTT'
          self.protocol_level ||= 0x04
        else
          raise ArgumentError.new("Unsupported protocol version: #{version}")
        end
      end

      # Get serialisation of packet's body
      def encode_body
        body = ''
        check_version
        body += encode_string(@protocol_name)
        body += encode_bytes(@protocol_level.to_i)
        if @keep_alive < 0
          raise "Invalid keep-alive value: cannot be less than 0"
        end

        body += encode_flags(@connect_flags)
        body += encode_short(@keep_alive)
        body += encode_string(@client_id)
        unless will_topic.nil?
          body += encode_string(@will_topic)
          # The MQTT v3.1 specification says that the payload is a UTF-8 string
          body += encode_string(@will_payload)
        end
        body += encode_string(@username) unless @username.nil?
        body += encode_string(@password) unless @password.nil?
        body
      end

      def check_version
        if @version == '3.1.0'
          if @client_id.nil? or @client_id.bytesize < 1
            raise "Client identifier too short while serialising packet"
          elsif @client_id.bytesize > 23
            raise "Client identifier too long when serialising packet"
          end
        end
      end

      def encode_flags(flags)
        # Set the Connect flags
        flags = 0
        flags |= 0x02 if @clean_session
        flags |= 0x04 unless @will_topic.nil?
        flags |= ((@will_qos & 0x03) << 3)
        flags |= 0x20 if @will_retain
        flags |= 0x40 unless @password.nil?
        flags |= 0x80 unless @username.nil?
        encode_bytes(flags)
      end

      # Parse the body (variable header and payload) of a Connect packet
      def parse_body(buffer)
        super(buffer)
        @protocol_name = shift_string(buffer)
        @protocol_level = shift_byte(buffer).to_i
        if @protocol_name == 'MQIsdp' and @protocol_level == 3
          @version = '3.1.0'
        elsif @protocol_name == 'MQTT' and @protocol_level == 4
          @version = '3.1.1'
        else
          raise "Unsupported protocol: #{@protocol_name}/#{@protocol_level}"
        end

        @connect_flags = shift_byte(buffer)
        @keep_alive = shift_short(buffer)
        @client_id = shift_string(buffer)
        parse_connect_flags(@connect_flag, buffer)
      end

      def parse_connect_flags(flags, buffer)
        @clean_session = ((@connect_flags & 0x02) >> 1) == 0x01
        if ((flags & 0x04) >> 2) == 0x01
          # Last Will and Testament
          @will_qos = ((flags & 0x18) >> 3)
          @will_retain = ((flags & 0x20) >> 5) == 0x01
          @will_topic = shift_string(buffer)
          # The MQTT v3.1 specification says that the payload is a UTF-8 string
          @will_payload = shift_string(buffer)
        end
        if ((@connect_flags & 0x80) >> 7) == 0x01 and buffer.bytesize > 0
          @username = shift_string(buffer)
        end
        if ((@connect_flags & 0x40) >> 6) == 0x01 and buffer.bytesize > 0
          @password = shift_string(buffer)
        end
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        str = "\#<#{self.class}: "
        str += "keep_alive=#{keep_alive}"
        str += ", clean" if clean_session
        str += ", client_id='#{client_id}'"
        str += ", username='#{username}'" unless username.nil?
        str += ", password=..." unless password.nil?
        str += ">"
      end
    end
  end
end
