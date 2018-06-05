$:.unshift(File.dirname(__FILE__))

require 'spec_helper'

describe PahoMqtt::Packet::Pubrec do
  context "Create a simple pubrec packet" do
    it "Successfully create pubrec packet from header" do
      packet = PahoMqtt::Packet::Base.create_from_header(0x50)
      expect(packet.inspect).to eq("#<PahoMqtt::Packet::Pubrec: 0x00>")
      expect(packet.parse_body("")).to be nil
    end
    it "Encode packet id" do
      packet = PahoMqtt::Packet::Pubrec.new({id: 4})
      expect(packet.encode_body.bytes).to eq("\x00\x04".bytes)
    end
  end
    
  context "Raising execption" do
    it "Fail for payload in pubrec packet" do
      packet = PahoMqtt::Packet::Pubrec.new
      packet.body_length = 3
      expect { packet.parse_body("\x01\x00\x00") }.to raise_error(PahoMqtt::PacketFormatException, "Extra bytes at end of Publish Received packet")
    end
  end
end
