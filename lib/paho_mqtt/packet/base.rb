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
    # Class representing a MQTT Packet
    # Performs binary encoding and decoding of headers
    class Base
      # The version number of the MQTT protocol to use (default 3.1.0)
      attr_accessor :version

      # Identifier to link related control packets together
      attr_accessor :id

      # Array of 4 bits in the fixed header
      attr_accessor :flags

      # The length of the parsed packet body
      attr_reader :body_length

      # Default attribute values
      ATTR_DEFAULTS = {
        :version => '3.1.0',
        :id => 0,
        :body_length => nil
      }

      # Read in a packet from a socket
      def self.read(socket)
        # Read in the packet header and create a new packet object
        packet = create_from_header(
          read_byte(socket)
        )
        unless packet.nil?
          packet.validate_flags

          # Read in the packet length
          multiplier = 1
          body_length = 0
          pos = 1
          begin
            digit = read_byte(socket)
            body_length += ((digit & 0x7F) * multiplier)
            multiplier *= 0x80
            pos += 1
          end while ((digit & 0x80) != 0x00) and pos <= 4

          # Store the expected body length in the packet
          packet.instance_variable_set('@body_length', body_length)

          # Read in the packet body
          packet.parse_body( socket.read(body_length) )
        end
        return packet
      end

      # Parse buffer into new packet object
      def self.parse(buffer)
        packet = parse_header(buffer)
        packet.parse_body(buffer)
        return packet
      end

      # Parse the header and create a new packet object of the correct type
      # The header is removed from the buffer passed into this function
      def self.parse_header(buffer)
        # Check that the packet is a long as the minimum packet size
        if buffer.bytesize < 2
          raise "Invalid packet: less than 2 bytes long"
        end

        # Create a new packet object
        bytes = buffer.unpack("C5")
        packet = create_from_header(bytes.first)
        packet.validate_flags

        # Parse the packet length
        body_length = 0
        multiplier = 1
        pos = 1
        begin
          if buffer.bytesize <= pos
            raise "The packet length header is incomplete"
          end
          digit = bytes[pos]
          body_length += ((digit & 0x7F) * multiplier)
          multiplier *= 0x80
          pos += 1
        end while ((digit & 0x80) != 0x00) and pos <= 4

        # Store the expected body length in the packet
        packet.instance_variable_set('@body_length', body_length)

        # Delete the fixed header from the raw packet passed in
        buffer.slice!(0...pos)

        return packet
      end

      # Create a new packet object from the first byte of a MQTT packet
      def self.create_from_header(byte)
        unless byte.nil?
          # Work out the class
          type_id = ((byte & 0xF0) >> 4)
          packet_class = PahoMqtt::PACKET_TYPES[type_id]
          if packet_class.nil?
            raise "Invalid packet type identifier: #{type_id}"
          end

          # Convert the last 4 bits of byte into array of true/false
          flags = (0..3).map { |i| byte & (2 ** i) != 0 }

          # Create a new packet object
          packet_class.new(:flags => flags)
        end
      end

      # Create a new empty packet
      def initialize(args={})
        # We must set flags before the other values
        @flags = [false, false, false, false]
        update_attributes(ATTR_DEFAULTS.merge(args))
      end

      # Set packet attributes from a hash of attribute names and values
      def update_attributes(attr={})
        attr.each_pair do |k,v|
          if v.is_a?(Array) or v.is_a?(Hash)
            send("#{k}=", v.dup)
          else
            send("#{k}=", v)
          end
        end
      end

      # Get the identifer for this packet type
      def type_id
        index = PahoMqtt::PACKET_TYPES.index(self.class)
        if index.nil?
          raise "Invalid packet type: #{self.class}"
        end
        return index
      end

      # Get the name of the packet type as a string in capitals
      # (like the MQTT specification uses)
      #
      # Example: CONNACK
      def type_name
        self.class.name.split('::').last.upcase
      end

      # Set the protocol version number
      def version=(arg)
        @version = arg.to_s
      end

      # Set the length of the packet body
      def body_length=(arg)
        @body_length = arg.to_i
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        if buffer.bytesize != body_length
          raise "Failed to parse packet - input buffer (#{buffer.bytesize}) is not the same as the body length header (#{body_length})"
        end
      end

      # Get serialisation of packet's body (variable header and payload)
      def encode_body
        '' # No body by default
      end

      # Serialise the packet
      def to_s
        # Encode the fixed header
        header = [
          ((type_id.to_i & 0x0F) << 4) |
          (flags[3] ? 0x8 : 0x0) |
          (flags[2] ? 0x4 : 0x0) |
          (flags[1] ? 0x2 : 0x0) |
          (flags[0] ? 0x1 : 0x0)
        ]

        # Get the packet's variable header and payload
        body = self.encode_body

        # Check that that packet isn't too big
        body_length = body.bytesize
        if body_length > 268435455
          raise "Error serialising packet: body is more than 256MB"
        end

        # Build up the body length field bytes
        begin
          digit = (body_length % 128)
          body_length = (body_length / 128)
          # if there are more digits to encode, set the top bit of this digit
          digit |= 0x80 if (body_length > 0)
          header.push(digit)
        end while (body_length > 0)

        # Convert header to binary and add on body
        header.pack('C*') + body
      end

      # Check that fixed header flags are valid for types that don't use the flags
      # @private
      def validate_flags
        if flags != [false, false, false, false]
          raise "Invalid flags in #{type_name} packet header"
        end
      end

      # Returns a human readable string
      def inspect
        "\#<#{self.class}>"
      end

      protected

      # Encode an array of bytes and return them
      def encode_bytes(*bytes)
        bytes.pack('C*')
      end

      # Encode an array of bits and return them
      def encode_bits(bits)
        [bits.map{|b| b ? '1' : '0'}.join].pack('b*')
      end

      # Encode a 16-bit unsigned integer and return it
      def encode_short(val)
        [val.to_i].pack('n')
      end

      # Encode a UTF-8 string and return it
      # (preceded by the length of the string)
      def encode_string(str)
        str = str.to_s.encode('UTF-8')

        # Force to binary, when assembling the packet
        str.force_encoding('ASCII-8BIT')
        encode_short(str.bytesize) + str
      end

      # Remove a 16-bit unsigned integer from the front of buffer
      def shift_short(buffer)
        bytes = buffer.slice!(0..1)
        bytes.unpack('n').first
      end

      # Remove one byte from the front of the string
      def shift_byte(buffer)
        buffer.slice!(0...1).unpack('C').first
      end

      # Remove 8 bits from the front of buffer
      def shift_bits(buffer)
        buffer.slice!(0...1).unpack('b8').first.split('').map {|b| b == '1'}
      end

      # Remove n bytes from the front of buffer
      def shift_data(buffer,bytes)
        buffer.slice!(0...bytes)
      end

      # Remove string from the front of buffer
      def shift_string(buffer)
        len = shift_short(buffer)
        str = shift_data(buffer,len)
        # Strings in MQTT v3.1 are all UTF-8
        str.force_encoding('UTF-8')
      end


      private

      # Read and unpack a single byte from a socket
      def self.read_byte(socket)
        byte = socket.read(1)
        unless byte.nil?
          byte.unpack('C').first
        else
          nil
        end
      end
    end
  end
end
