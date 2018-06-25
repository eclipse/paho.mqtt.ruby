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

require 'openssl'

module PahoMqtt
  module SSLHelper
    extend self

    def config_ssl_context(cert_path=nil, key_path=nil, ca_path=nil)
      ssl_context = OpenSSL::SSL::SSLContext.new
      set_cert(cert_path, ssl_context)
      set_key(key_path, ssl_context)
      set_root_ca(ca_path, ssl_context)
      # ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER unless ca_path.nil?
      ssl_context
    end

    def set_cert(cert_path=nil, ssl_context)
      unless cert_path.nil?
        ssl_context.cert = OpenSSL::X509::Certificate.new(File.read(cert_path))
      end
    end

    def set_key(key_path=nil, ssl_context)
      unless key_path.nil?
        return MQTT_ERR_SUCCESS if try_rsa_key(key_path, ssl_context) == MQTT_ERR_SUCCESS
        begin
          ssl_context.key = OpenSSL::PKey::EC.new(File.read(key_path))
          return MQTT_ERR_SUCCESS
        rescue OpenSSL::PKey::ECError
          raise NotSupportedEncryptionException.new("Could not support the type of the provided key (supported: RSA and EC)")
        end
      end
    end

    def try_rsa_key(key_path, ssl_context)
      begin
        ssl_context.key = OpenSSL::PKey::RSA.new(File.read(key_path))
        return MQTT_ERR_SUCCESS
      rescue OpenSSL::PKey::RSAError
        return MQTT_ERR_FAIL
      end
    end

    def set_root_ca(ca_path, ssl_context)
      ssl_context.ca_file = ca_path
    end
  end
end
