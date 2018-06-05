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
  class Publisher

    def initialize(sender)
      @waiting_puback = []
      @waiting_pubrec = []
      @waiting_pubrel = []
      @waiting_pubcomp = []
      @puback_mutex = Mutex.new
      @pubrec_mutex = Mutex.new
      @pubrel_mutex = Mutex.new
      @pubcomp_mutex = Mutex.new
      @sender = sender
    end

    def sender=(sender)
      @sender = sender
    end

    def send_publish(topic, payload, retain, qos, new_id)
      packet = PahoMqtt::Packet::Publish.new(
        :id => new_id,
        :topic => topic,
        :payload => payload,
        :retain => retain,
        :qos => qos
      )
      @sender.append_to_writing(packet)
      case qos
      when 1
        @puback_mutex.synchronize{
          @waiting_puback.push({:id => new_id, :packet => packet, :timestamp => Time.now})
        }
      when 2
        @pubrec_mutex.synchronize{
          @waiting_pubrec.push({:id => new_id, :packet => packet, :timestamp => Time.now})
        }
      end
      MQTT_ERR_SUCCESS
    end

    def do_publish(qos, packet_id)
      case qos
      when 0
      when 1
        send_puback(packet_id)
      when 2
        send_pubrec(packet_id)
      else
        @logger.error("The packet qos value is invalid in publish.") if logger?
        raise PacketException
      end
      MQTT_ERR_SUCCESS
    end

    def send_puback(packet_id)
      packet = PahoMqtt::Packet::Puback.new(
        :id => packet_id
      )
      @sender.append_to_writing(packet)
      MQTT_ERR_SUCCESS
    end

    def do_puback(packet_id)
      @puback_mutex.synchronize{
        @waiting_puback.delete_if { |pck| pck[:id] == packet_id }
      }
      MQTT_ERR_SUCCESS      
    end
    
    def send_pubrec(packet_id)
      packet = PahoMqtt::Packet::Pubrec.new(
        :id => packet_id
      )
      @sender.append_to_writing(packet)
      @pubrel_mutex.synchronize{
        @waiting_pubrel.push({:id => packet_id , :packet => packet, :timestamp => Time.now})
      }
      MQTT_ERR_SUCCESS
    end

    def do_pubrec(packet_id)
      @pubrec_mutex.synchronize {
        @waiting_pubrec.delete_if { |pck| pck[:id] == packet_id }
      }
      send_pubrel(packet_id)
      MQTT_ERR_SUCCESS
    end

    def send_pubrel(packet_id)
      packet = PahoMqtt::Packet::Pubrel.new(
        :id => packet_id
      )
      @sender.append_to_writing(packet)
      @pubcomp_mutex.synchronize{
        @waiting_pubcomp.push({:id => packet_id, :packet => packet, :timestamp => Time.now})
      }
      MQTT_ERR_SUCCESS
    end

    def do_pubrel(packet_id)
      @pubrel_mutex.synchronize {
        @waiting_pubrel.delete_if { |pck| pck[:id] == packet_id }
      }
      send_pubcomp(packet_id)
      MQTT_ERR_SUCCESS
    end

    def send_pubcomp(packet_id)
      packet = PahoMqtt::Packet::Pubcomp.new(
        :id => packet_id
      )
      @sender.append_to_writing(packet)
      MQTT_ERR_SUCCESS
    end

    def do_pubcomp(packet_id)
      @pubcomp_mutex.synchronize {
        @waiting_pubcomp.delete_if { |pck| pck[:id] == packet_id }
      }
      MQTT_ERR_SUCCESS
    end

    def config_all_message_queue
      config_message_queue(@waiting_puback, @puback_mutex, MAX_PUBACK)
      config_message_queue(@waiting_pubrec, @pubrec_mutex, MAX_PUBREC)
      config_message_queue(@waiting_pubrel, @pubrel_mutex, MAX_PUBREL)
      config_message_queue(@waiting_pubcomp, @pubcomp_mutex, MAX_PUBCOMP)
    end

    def config_message_queue(queue, mutex, max_packet)
      mutex.synchronize {
        cnt = 0 
        queue.each do |pck|
          pck[:packet].dup ||= true
          if cnt <= max_packet
            @sender.append_to_writing(pck[:packet])
            cnt += 1
          end
        end
      }
    end

    def check_waiting_publisher
      @sender.check_ack_alive(@waiting_puback, @puback_mutex, MAX_PUBACK)
      @sender.check_ack_alive(@waiting_pubrec, @pubrec_mutex, MAX_PUBREC)
      @sender.check_ack_alive(@waiting_pubrel, @pubrel_mutex, MAX_PUBREL)
      @sender.check_ack_alive(@waiting_pubcomp, @pubcomp_mutex, MAX_PUBCOMP)
    end

    def flush_publisher
      @puback_mutex.synchronize {
        @waiting_puback = []
      }
      @pubrec_mutex.synchronize {
        @waiting_pubrec = []
      }
      @pubrel_mutex.synchronize {
        @waiting_pubrel = []
      }
      @pubcomp_mutex.synchronize {
        @waiting_pubcomp = []
      }
    end
  end
end
