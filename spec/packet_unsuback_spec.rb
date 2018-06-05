$:.unshift(File.dirname(__FILE__))

require 'spec_helper'

describe PahoMqtt::Packet::Unsuback do
  context "Create a simple suback packet" do
    it "Successfully create suback packet from header" do
      packet = PahoMqtt::Packet::Base.create_from_header(0xB0)
      expect(packet.inspect).to eq("#<PahoMqtt::Packet::Unsuback: 0x00>")
    end
  end

  context "Encode body for suback packet" do
    packet = PahoMqtt::Packet::Unsuback.new
    it "Fill in field for suback body" do
      packet.id  = 99
      expect(packet.encode_body.bytes).to eq("\x00c".bytes)
    end
  end

  context "Parse body of suback packet" do
    packet = PahoMqtt::Packet::Unsuback.new
    it "Extract fields from buffer " do
      body = "\x00b"
      packet.body_length = 2
      expect(packet.parse_body(body)).to eq(nil)
      expect(packet.id).to eq(98)
    end
  end
  
   context "Raising execption" do
     it "Fail to encode body for empty topics" do
       packet = PahoMqtt::Packet::Unsuback.new
       body = "\x00\x00\x00"
       packet.body_length = 3
       expect { packet.parse_body(body) }.to raise_error(PahoMqtt::PacketFormatException, "Extra bytes at end of Unsubscribe Acknowledgment packet")
     end
   end
end
