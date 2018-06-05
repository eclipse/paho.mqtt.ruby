$:.unshift(File.dirname(__FILE__))

require 'spec_helper'

describe PahoMqtt::Packet::Base do
  context "Basic packet class" do
    it "Create basic packets" do
      packet = PahoMqtt::Packet::Base.new({id: "\x02\x04", body_length: 2})
      expect(packet.flags).to eq ([false, false, false, false])
      expect(packet.version).to eq ('3.1.0')
    end
    
    it "Create basic packet with connect type id" do
      packet = PahoMqtt::Packet::Base.create_from_header(0x10)
      expect(packet.class).to eq (PahoMqtt::Packet::Connect)
    end

    it "Raise exception for invalid packet type id" do
      expect { PahoMqtt::Packet::Base.create_from_header(0x01) }.to raise_error(PahoMqtt::PacketFormatException)
    end

    it "Read a basic socket to read bytes" do
      ### Stub socket behaviour wiith a simple pipe
      rd, wr = IO.pipe
      ### Stub a Packet with TypeID = 0x30 BodyLenght = 0x03 and Body = 0x00 0x00 0x00
      wr.write("\x30\x03\x00\x00\x00")
      packet = PahoMqtt::Packet::Base.read(rd)
      expect(packet.class).to eq(PahoMqtt::Packet::Publish)
      expect(packet.body_length).to eq(3)
    end

    it "Parse a buffer to extract packet's header" do
      buffer = "\x30\x02\x00\x00"
      packet = PahoMqtt::Packet::Base.parse_header(buffer)
      expect(packet.class).to eq(PahoMqtt::Packet::Publish)
      expect(packet.flags).to eq ([false, false, false, false])
      expect(packet.version).to eq ('3.1.0')
      expect(packet.body_length).to eq(2)
      expect(buffer).to eq("\u0000\u0000")
    end
  end
end
