require 'eventmachine'
require 'json'

require_relative 'base_protocol'

module FFWD::Plugin::Tunnel
  class BinaryProtocol < BaseProtocol
    def initialize core, output, connection
      super core, output, connection
      @header = nil
    end

    def self.type
      :binary
    end

    Header = Struct.new(
      :protocol,
      :bindport,
      :family,
      :ip,
      :port,
      :datasize,
    )

    HEADER_FORMAT = 'CnCa16nn'
    HEADER_LENGTH = 24

    def receive_line line
      raise "already have metadata" if @metadata
      receive_metadata JSON.load(line)
      set_text_mode HEADER_LENGTH
    end

    def receive_binary_data data
      unless @header
        @header = Header.new(*data.unpack(HEADER_FORMAT))
        set_text_mode @header.datasize
        return
      end

      id = [@header.protocol, @header.bindport]
      addr = [@header.family, @header.ip, @header.port]
      tunnel_frame id, addr, data

      @header = nil
      set_text_mode HEADER_LENGTH
    end

    def dispatch id, addr, data
      protocol, bindport = id
      family, ip, port = addr
      header = [protocol, bindport, family, ip, port, data.size]
      header = header.pack HEADER_FORMAT
      frame = header + data
      send_data frame
    end
  end
end
