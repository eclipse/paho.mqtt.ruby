$:.unshift(File.dirname(__FILE__))

require 'spec_helper'

describe PahoMqtt::Packet::Subscribe do
  context "Create a simple subscribe packet" do
    it "Successfully create subscribe packet from header" do
      packet = PahoMqtt::Packet::Base.create_from_header(0x80)
      expect(packet.inspect).to eq("#<PahoMqtt::Packet::Subscribe: 0x00, >")
    end
    it "Set up flags for subscribe packet" do
      packet = PahoMqtt::Packet::Subscribe.new
      expect(packet.validate_flags).to be nil
      packet = PahoMqtt::Packet:: Subscribe.new
    end
  end

  context "Encode subscribe packet with topics" do
    packet = PahoMqtt::Packet:: Subscribe.new
    it "initialize with single topic" do
      packet.topics = "test/topic"
      expect(packet.topics).to eq([["test/topic", 0]])
    end
    it "initialize with multiple topics in array" do
      packet.topics = [["test/topic", 0], ["test/topictopic", 1]]
      expect(packet.topics).to eq([["test/topic", 0], ["test/topictopic", 1]])
    end
    it "initialize with multiple topics in hash" do
      packet.topics = {"test/topic" => 0, "test/topictopic" => 1}
      expect(packet.topics).to eq([["test/topic", 0], ["test/topictopic", 1]])
    end
    it "Encode body for subscribe packet" do
      packet.id = 4
      packet.topics = "test/topic"
      expect(packet.encode_body.bytes).to eq("\x00\x04\x00\ntest/topic\x00".bytes)
    end

  end
  context "Parse body for subscribe packet" do
    it "Fill in all fields with right value" do
      packet = PahoMqtt::Packet:: Subscribe.new
      packet.body_length = 15
      body = "\x00\x04\x00\ntest/topic\x00"
      packet.parse_body(body)
      expect(packet.id).to eq(4)
      expect(packet.topics).to eq([["test/topic", 0]])
    end
  end
  
   context "Raising execption" do
     it "Fail to validate header flags" do
       packet = PahoMqtt::Packet::Subscribe.new(flags: [false, false, false, false])
       expect { packet.validate_flags }.to raise_error(PahoMqtt::PacketFormatException, "Invalid flags in SUBSCRIBE packet header")
     end

     it "Fail because of invalid topics type" do
       packet = PahoMqtt::Packet::Subscribe.new
       expect { packet.topics = 12345 }.to raise_error(PahoMqtt::PacketFormatException, "Invalid topics input: 12345")
     end

     it "Fail to encode body for empty topics" do
       packet = PahoMqtt::Packet::Subscribe.new
       expect { packet.encode_body }.to raise_error(PahoMqtt::PacketFormatException, "No topics given when serialising packet")
     end
   end
end
