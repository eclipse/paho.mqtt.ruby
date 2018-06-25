# Copyright (c) 2016-2018 Pierre Goudet <p-goudet@ruby-dev.jp>
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


module PahoMqtt
  class Exception < ::StandardError
    def initialize(msg="")
      super
    end
  end
  
  class ProtocolViolation < Exception
  end
  
  class WritingException < Exception
  end
  
  class ReadingException < Exception
  end

  class PacketException < Exception
  end

  class PacketFormatException < Exception
  end

  class ProtocolVersionException < Exception
  end

  class LowVersionException < Exception
  end

  class FullWritingException < Exception
  end

  class FullQueueException < Exception
  end

  class NotSupportedEncryptionException < Exception
  end
end
