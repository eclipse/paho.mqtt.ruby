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
    class Pubrec < PahoMqtt::Packet::Base
      # Get serialisation of packet's body
      def encode_body
        encode_short(@id)
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)
        unless buffer.empty?
          raise PahoMqtt::PacketFormatException.new(
                  "Extra bytes at end of Publish Received packet")
        end
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X>" % id
      end
    end
  end
end
