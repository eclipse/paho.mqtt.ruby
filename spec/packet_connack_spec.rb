$:.unshift(File.dirname(__FILE__))

require 'spec_helper'

describe PahoMqtt::Packet::Connack do
  context "Create simple connack packet" do
    it "Successfully create a simple connack packet" do
      packet = PahoMqtt::Packet::Base.create_from_header(0x20)
      expect(packet.inspect).to eq ("#<PahoMqtt::Packet::Connack: 0x00>")
      expect(packet.flags).to eq ([false, false, false, false])
      expect(packet.session_present).to eq (false)
      expect(packet.return_msg).to eq("Connection accepted")
    end

    context "Invalid variable header flags" do
      packet = PahoMqtt::Packet::Connack.new
      it "raise exception for invalid connack flags" do
        packet.body_length = 1
        expect { packet.parse_body("\x02") }.to raise_error(PahoMqtt::PacketFormatException, "Invalid flags in Connack variable header")
      end
      it "raise exception for extra bytes in body" do
        packet.body_length = 3
        expect { packet.parse_body("\x00\x00\x00") }.to raise_error(PahoMqtt::PacketFormatException, "Extra bytes at end of Connect Acknowledgment packet")
      end
    end

    context "Connack packet buffer header" do
      packet = PahoMqtt::Packet::Connack.new
      packet.body_length = 2
      it "return connection accepted" do
        packet.parse_body("\x00\x00")
        expect(packet.return_code).to eq(0x00)
        expect(packet.return_msg).to eq("Connection accepted")
      end
      
      it "return connection refused with protocol error" do
        packet.parse_body("\x00\x01")
        expect(packet.return_code).to eq(0x01)
        expect { packet.return_msg }.to raise_error(PahoMqtt::LowVersionException)
      end

      it "return connection refused with client id error" do
        packet.parse_body("\x00\x02")
        expect(packet.return_code).to eq(0x02)
        expect(packet.return_msg).to eq("Connection refused: client identifier rejected")
      end

      it "return connection refused with server error" do
        packet.parse_body("\x00\x03")
        expect(packet.return_code).to eq(0x03)
        expect(packet.return_msg).to eq("Connection refused: server unavailable")
      end
      
      it "return connection refused with authentication error" do
        packet.parse_body("\x00\x04")
        expect(packet.return_code).to eq(0x04)
        expect(packet.return_msg).to eq("Connection refused: bad user name or password")
      end

      it "return connection refused with authorization error" do
        packet.parse_body("\x00\x05")
        expect(packet.return_code).to eq(0x05)
        expect(packet.return_msg).to eq("Connection refused: not authorised")
      end

      it "return connection refused with unknown error" do
        packet.parse_body("\x00\x11")
        expect(packet.return_code).to eq(0x11)
        expect(packet.return_msg).to eq("Connection refused: error code 17")
      end
    end
  end
end
