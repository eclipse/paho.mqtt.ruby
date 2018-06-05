$:.unshift(File.dirname(__FILE__))

require 'spec_helper'

describe PahoMqtt::Packet::Suback do
  context "Create a simple suback packet" do
    it "Successfully create suback packet from header" do
      packet = PahoMqtt::Packet::Base.create_from_header(0x90)
      expect(packet.inspect).to eq("#<PahoMqtt::Packet::Suback: 0x00, rc=>")
    end
  end

  context "Set up return code for suback" do
    packet = PahoMqtt::Packet::Suback.new
    it "Return an integer" do
      expect(packet.return_codes=(6)).to eq(6)
    end

    it "Return an array" do
      expect(packet.return_codes=([6])).to eq([6])
    end
  end

  context "Encode body for suback packet" do
    packet = PahoMqtt::Packet::Suback.new
    it "Fill in field for suback body" do
      packet.id  = 99
      packet.return_codes = [1, 2, 0, 2, 1]
      expect(packet.encode_body.bytes).to eq("\x00c\x01\x02\x00\x02\x01".bytes)
    end
  end

  context "Parse body of suback packet" do
    packet = PahoMqtt::Packet::Suback.new
    it "Extract fields from buffer " do
      body = "\x00c\x01\x02\x00\x02\x01"
      packet.body_length = 7
      expect(packet.parse_body(body)).to eq(nil)
      expect(packet.id).to eq(99)
      expect(packet.return_codes).to eq([1, 2, 0, 2, 1])
    end
  end
  
   context "Raising execption" do
     it "Fail because of invalid topics type" do
       packet = PahoMqtt::Packet::Suback.new
       expect { packet.return_codes=("fail") }.to raise_error(PahoMqtt::PacketFormatException, "return_codes should be an integer or an array of return codes")
     end

     it "Fail to encode body for empty topics" do
       packet = PahoMqtt::Packet::Suback.new
       expect { packet.encode_body }.to raise_error(PahoMqtt::PacketFormatException, "No granted QoS given when serialising packet")
     end
   end
end
