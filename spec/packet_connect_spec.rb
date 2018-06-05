$:.unshift(File.dirname(__FILE__))

require 'spec_helper'

describe PahoMqtt::Packet::Connect do
  context "Connect packet class" do
    it "Create correct connect packet for version 3.1.1" do
      packet = PahoMqtt::Packet::Connect.new(version: '3.1.1')
      expect(packet.protocol_name).to eq('MQTT')
      expect(packet.protocol_level).to eq (0x04)
    end

    it "Create correct connect packet for version 3.1.0" do
      packet = PahoMqtt::Packet::Connect.new(version: '3.1.0')
      expect(packet.protocol_name).to eq('MQIsdp')
      expect(packet.protocol_level).to eq (0x03)
    end

    it "Create connect packet with invalid version 2.0" do
      expect { PahoMqtt::Packet::Connect.new(version: '2.0') }.to raise_error(PahoMqtt::PacketFormatException, "Unsupported protocol version: 2.0")
    end
  end

  context "Connect packet full field" do
      packet = PahoMqtt::Packet::Connect.new(
        client_id: '0001',
        version: '3.1.1',
        clean_session: true,
        keep_alive: 30,
        will_topic: 'test',
        will_qos: 1,
        will_retain: true,
        will_payload: 'hogehoge',
        username: 'pierre',
        password: 'goudet'
      )
      
    it "expect all field to be set" do
      expect(packet.client_id).to eq('0001')
      expect(packet.version).to eq('3.1.1')
      expect(packet.clean_session).to eq(true)
      expect(packet.keep_alive).to eq(30)
      expect(packet.will_topic).to eq('test')
      expect(packet.will_qos).to eq(1)
      expect(packet.will_retain).to eq(true)
      expect(packet.will_payload).to eq('hogehoge')
    end
    
    it "Encode flags for connect packet" do
      flag = packet.encode_flags(0)
      expect(flag.unpack('C*').first).to eq(238)
    end

    it "expect all field to be correctly encoded" do
      bd = packet.encode_body
      expt = "\x00\x04MQTT\x04\xEE\x00\x1E\x00\x040001\x00\x04test\x00\bhogehoge\x00\x06pierre\x00\x06goudet"
      expect(bd.bytes).to eq(expt.bytes)
    end
  end
end
