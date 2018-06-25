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
    class Connack < PahoMqtt::Packet::Base
      # Session Present flag
      attr_accessor :session_present

      # The return code (defaults to 0 for connection accepted)
      attr_accessor :return_code

      # Default attribute values
      ATTR_DEFAULTS = { :return_code => 0x00 }

      # Create a new Client Connect packet
      def initialize(args={})
        # We must set flags before other attributes
        @connack_flags = [false, false, false, false, false, false, false, false]
        super(ATTR_DEFAULTS.merge(args))
      end

      # Get the Session Present flag
      def session_present
        @connack_flags[0]
      end

      # Set the Session Present flag
      def session_present=(arg)
        if arg.kind_of?(Integer)
          @connack_flags[0] = (arg == 0x1)
        else
          @connack_flags[0] = arg
        end
      end

      # Get a string message corresponding to a return code
      def return_msg
        case return_code
        when 0x00
          "Connection accepted"
        when 0x01
          raise LowVersionException
        when 0x02
          "Connection refused: client identifier rejected"
        when 0x03
          "Connection refused: server unavailable"
        when 0x04
          "Connection refused: bad user name or password"
        when 0x05
          "Connection refused: not authorised"
        else
          "Connection refused: error code #{return_code}"
        end
      end

      # Get serialisation of packet's body
      def encode_body
        body = ''
        body += encode_bits(@connack_flags)
        body += encode_bytes(@return_code.to_i)
        body
      end

      # Parse the body (variable header and payload) of a Connect Acknowledgment packet
      def parse_body(buffer)
        super(buffer)
        @connack_flags = shift_bits(buffer)
        unless @connack_flags[1, 7] == [false, false, false, false, false, false, false]
          raise PacketFormatException.new(
                  "Invalid flags in Connack variable header")
        end
        @return_code = shift_byte(buffer)
        unless buffer.empty?
          raise PacketFormatException.new(
                  "Extra bytes at end of Connect Acknowledgment packet")
        end
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X>" % return_code
      end
    end
  end
end
