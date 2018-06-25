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
    class Subscribe < PahoMqtt::Packet::Base
      # One or more topic filters to subscribe to
      attr_accessor :topics

      # Default attribute values
      ATTR_DEFAULTS = {
        :topics => [],
        :flags => [false, true, false, false],
      }

      # Create a new Subscribe packet
      def initialize(args={})
        super(ATTR_DEFAULTS.merge(args))
      end

      # Set one or more topic filters for the Subscribe packet
      # The topics parameter should be one of the following:
      # * String: subscribe to one topic with QoS 0
      # * Array: subscribe to multiple topics with QoS 0
      # * Hash: subscribe to multiple topics where the key is the topic and the value is the QoS level
      #
      # For example:
      #   packet.topics = 'a/b'
      #   packet.topics = ['a/b', 'c/d']
      #   packet.topics = [['a/b',0], ['c/d',1]]
      #   packet.topics = {'a/b' => 0, 'c/d' => 1}
      #
      def topics=(value)
        # Get input into a consistent state
        if value.is_a?(Array)
          input = value.flatten
        else
          input = [value]
        end

        @topics = []
        while(input.length>0)
          item = input.shift
          if item.is_a?(Hash)
            # Convert hash into an ordered array of arrays
            @topics += item.sort
          elsif item.is_a?(String)
            # Peek at the next item in the array, and remove it if it is an integer
            if input.first.is_a?(Integer)
              qos = input.shift
              @topics << [item, qos]
            else
              @topics << [item, 0]
            end
          else
            # Meh?
            raise PahoMqtt::PacketFormatException.new(
                    "Invalid topics input: #{value.inspect}")
          end
        end
        @topics
      end

      # Get serialisation of packet's body
      def encode_body
        if @topics.empty?
          raise PahoMqtt::PacketFormatException.new(
                  "No topics given when serialising packet")
        end
        body = encode_short(@id)
        topics.each do |item|
          body += encode_string(item[0])
          body += encode_bytes(item[1])
        end
        return body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)
        @topics = []
        while(buffer.bytesize>0)
          topic_name = shift_string(buffer)
          topic_qos = shift_byte(buffer)
          @topics << [topic_name, topic_qos]
        end
      end

      # Check that fixed header flags are valid for this packet type
      # @private
      def validate_flags
        if @flags != [false, true, false, false]
          raise PahoMqtt::PacketFormatException.new(
                  "Invalid flags in SUBSCRIBE packet header")
        end
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        _str = "\#<#{self.class}: 0x%2.2X, %s>" % [
          id,
          topics.map { |t| "'#{t[0]}':#{t[1]}" }.join(', ')
        ]
      end
    end
  end
end
