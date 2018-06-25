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

require 'socket'

module PahoMqtt
  class ConnectionHelper

    attr_accessor :sender

    def initialize(host, port, ssl, ssl_context, ack_timeout)
      @cs          = MQTT_CS_DISCONNECT
      @socket      = nil
      @host        = host
      @port        = port
      @ssl         = ssl
      @ssl_context = ssl_context
      @ack_timeout = ack_timeout
      @sender      = Sender.new(ack_timeout)
    end

    def handler=(handler)
      @handler = handler
    end

    def do_connect(reconnection=false)
      @cs = MQTT_CS_NEW
      @handler.socket = @socket
      # Waiting a Connack packet for "ack_timeout" second from the remote
      connect_timeout = Time.now + @ack_timeout
      while (Time.now <= connect_timeout) && !is_connected? do
        @cs = @handler.receive_packet
      end
      unless is_connected?
        PahoMqtt.logger.warn("Connection failed. Couldn't recieve a Connack packet from: #{@host}.") if PahoMqtt.logger?
        raise Exception.new("Connection failed. Check log for more details.") unless reconnection
      end
      @cs
    end

    def is_connected?
      @cs == MQTT_CS_CONNECTED
    end

    def do_disconnect(publisher, explicit, mqtt_thread)
      PahoMqtt.logger.debug("Disconnecting from #{@host}.") if PahoMqtt.logger?
      if explicit
        explicit_disconnect(publisher, mqtt_thread)
      end
      @socket.close unless @socket.nil? || @socket.closed?
      @socket = nil
    end

    def explicit_disconnect(publisher, mqtt_thread)
      @sender.flush_waiting_packet(false)
      send_disconnect
      mqtt_thread.kill if mqtt_thread && mqtt_thread.alive?
      publisher.flush_publisher unless publisher.nil?
    end

    def setup_connection
      clean_start(@host, @port)
      config_socket
      unless @socket.nil?
        @sender.socket = @socket
      end
    end

    def config_socket
      PahoMqtt.logger.debug("Attempt to connect to host: #{@host}...") if PahoMqtt.logger?
      begin
        tcp_socket = TCPSocket.new(@host, @port)
        if @ssl
          encrypted_socket(tcp_socket, @ssl_context)
        else
          @socket = tcp_socket
        end
      rescue StandardError
        PahoMqtt.logger.warn("Could not open a socket with #{@host} on port #{@port}.") if PahoMqtt.logger?
      end
    end

    def encrypted_socket(tcp_socket, ssl_context)
      unless ssl_context.nil?
        @socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_context)
        @socket.sync_close = true
        @socket.connect
      else
        PahoMqtt.logger.error("The SSL context was found as nil while the socket's opening.") if PahoMqtt.logger?
        raise Exception
      end
    end

    def clean_start(host, port)
      self.host = host
      self.port = port
      unless @socket.nil?
        @socket.close unless @socket.closed?
        @socket = nil
      end
    end

    def host=(host)
      if host.nil? || host == ""
        PahoMqtt.logger.error("The host was found as nil while the connection setup.") if PahoMqtt.logger?
        raise ArgumentError
      else
        @host = host
      end
    end

    def port=(port)
      if port.to_i <= 0
        PahoMqtt.logger.error("The port value is invalid (<= 0). Could not setup the connection.") if PahoMqtt.logger?
        raise ArgumentError
      else
        @port = port
      end
    end

    def send_connect(session_params)
      setup_connection
      packet = PahoMqtt::Packet::Connect.new(session_params)
      @handler.clean_session = session_params[:clean_session]
      @sender.send_packet(packet)
      MQTT_ERR_SUCCESS
    end

    def send_disconnect
      packet = PahoMqtt::Packet::Disconnect.new
      @sender.send_packet(packet)
      MQTT_ERR_SUCCESS
    end

    def check_keep_alive(persistent, last_ping_resp, keep_alive)
      now = Time.now
      timeout_req = (@sender.last_ping_req + (keep_alive * 0.7).ceil)
      if timeout_req <= now && persistent
        PahoMqtt.logger.debug("Checking if server is still alive...") if PahoMqtt.logger?
        @sender.send_pingreq
      end
      timeout_resp = last_ping_resp + (keep_alive * 1.1).ceil
      if timeout_resp <= now
        PahoMqtt.logger.debug("No activity is over timeout, disconnecting from #{@host}.") if PahoMqtt.logger?
        @cs = MQTT_CS_DISCONNECT
      end
      @cs
    end
  end
end
