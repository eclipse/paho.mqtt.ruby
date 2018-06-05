$:.unshift(File.dirname(__FILE__))

require 'spec_helper'

describe PahoMqtt::Packet::Puback do
  context "Create a simple puback packet" do
    it "Successfully create puback packet from header" do
      packet = PahoMqtt::Packet::Base.create_from_header(0x40)
      expect(packet.inspect).to eq("#<PahoMqtt::Packet::Puback: 0x00>")
      expect(packet.parse_body("")).to be nil
    end
    it "Encode packet id" do
      packet = PahoMqtt::Packet::Puback.new({id: 4})
      expect(packet.encode_body.bytes).to eq("\x00\x04".bytes)
    end
  end
    
  context "Raising execption" do
    it "Fail for payload in puback packet" do
      packet = PahoMqtt::Packet::Puback.new
      packet.body_length = 3
      expect { packet.parse_body("\x01\x00\x00") }.to raise_error(PahoMqtt::PacketFormatException, "Extra bytes at end of Publish Acknowledgment packet")
    end
  end
end
