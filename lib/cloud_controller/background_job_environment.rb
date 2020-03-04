require 'socket'

class BackgroundJobEnvironment
  def initialize(config)
    @config = config
    @log_counter = Steno::Sink::Counter.new

    VCAP::CloudController::StenoConfigurer.new(config.get(:logging)).configure do |steno_config_hash|
      steno_config_hash[:sinks] << @log_counter
    end
  end

  READINESS_SOCKET_QUEUE_DEPTH = 100

  def setup_environment(readiness_port = nil)
    VCAP::CloudController::DB.load_models(@config.get(:db), Steno.logger('cc.background'))
    @config.configure_components

    if readiness_port
      open_readiness_port(readiness_port)
    end

    yield if block_given?
  end

  private

  def open_readiness_port(port)
    $socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM)
    sockaddr = Socket.pack_sockaddr_in(port, '127.0.0.1')
    $socket.bind(sockaddr)
    $socket.listen(READINESS_SOCKET_QUEUE_DEPTH)
  end
end
