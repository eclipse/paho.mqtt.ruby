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
    class Suback < PahoMqtt::Packet::Base
      # An array of return codes, ordered by the topics that were subscribed to
      attr_accessor :return_codes

      # Default attribute values
      ATTR_DEFAULTS = {
        :return_codes => [],
      }

      # Create a new Subscribe Acknowledgment packet
      def initialize(args={})
        super(ATTR_DEFAULTS.merge(args))
      end

      # Set the granted QoS value for each of the topics that were subscribed to
      # Can either be an integer or an array or integers.
      def return_codes=(value)
        if value.is_a?(Array)
          @return_codes = value
        elsif value.is_a?(Integer)
          @return_codes = [value]
        else
          raise PahoMqtt::PacketFormatException.new(
                  "return_codes should be an integer or an array of return codes")
        end
      end

      # Get serialisation of packet's body
      def encode_body
        if @return_codes.empty?
          raise PahoMqtt::PacketFormatException.new(
                  "No granted QoS given when serialising packet")
        end
        body = encode_short(@id)
        return_codes.each { |qos| body += encode_bytes(qos) }
        return body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)
        while buffer.bytesize > 0
          @return_codes << shift_byte(buffer)
        end
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X, rc=%s>" % [id, return_codes.map { |rc| "0x%2.2X" % rc }.join(',')]
      end
    end
  end
end
