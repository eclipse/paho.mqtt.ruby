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
  class Sender

    attr_accessor :last_ping_req

    def initialize(ack_timeout)
      @socket          = nil
      @writing_queue   = []
      @publish_queue   = []
      @publish_mutex   = Mutex.new
      @writing_mutex   = Mutex.new
      @last_ping_req   = -1
      @ack_timeout     = ack_timeout
    end

    def socket=(socket)
      @socket = socket
    end

    def send_packet(packet)
      begin
        @socket.write(packet.to_s) unless @socket.nil? || @socket.closed?
        @last_ping_req = Time.now
        MQTT_ERR_SUCCESS
      end
    rescue StandardError
      raise WritingException
    rescue IO::WaitWritable
      IO.select(nil, [@socket], nil, SELECT_TIMEOUT)
      retry
    end

    def send_pingreq
      send_packet(PahoMqtt::Packet::Pingreq.new)
    end

    def prepare_sending(queue, mutex, max_packet, packet)
      if queue.length < max_packet
        mutex.synchronize do
          queue.push(packet)
        end
      else
        PahoMqtt.logger.error('Writing queue is full, slowing down') if PahoMqtt.logger?
        raise FullWritingException
      end
    end

    def append_to_writing(packet)
      begin
        if packet.is_a?(PahoMqtt::Packet::Publish)
          prepare_sending(@publish_queue, @publish_mutex, MAX_PUBLISH, packet)
        else
          prepare_sending(@writing_queue, @writing_mutex, MAX_QUEUE, packet)
        end
      rescue FullWritingException
        sleep SELECT_TIMEOUT
        retry
      end
      MQTT_ERR_SUCCESS
    end

    def writing_loop
      @writing_mutex.synchronize do
        MAX_QUEUE.times do
          break if @writing_queue.empty?
          packet = @writing_queue.shift
          send_packet(packet)
        end
      end
      @publish_mutex.synchronize do
        MAX_PUBLISH.times do
          break if @publish_queue.empty?
          packet = @publish_queue.shift
          send_packet(packet)
        end
      end
      MQTT_ERR_SUCCESS
    end

    def flush_waiting_packet(sending=true)
      if sending
        @writing_mutex.synchronize do
          @writing_queue.each do |packet|
            send_packet(packet)
          end
        end
        @publish_mutex.synchronize do
          @publish_queue.each do |packet|
            send_packet(packet)
          end
        end
      end
      @writing_queue = []
      @publish_queue = []
    end

    def check_ack_alive(queue, mutex)
      mutex.synchronize do
        now = Time.now
        queue.each do |pck|
          if now >= pck[:timestamp] + @ack_timeout
            pck[:packet].dup ||= true unless pck[:packet].class == PahoMqtt::Packet::Subscribe || pck[:packet].class == PahoMqtt::Packet::Unsubscribe
            PahoMqtt.logger.info("Acknowledgement timeout is over, resending #{pck[:packet].inspect}") if PahoMqtt.logger?
            send_packet(pck[:packet])
            pck[:timestamp] = now
          end
        end
      end
    end
  end
end
