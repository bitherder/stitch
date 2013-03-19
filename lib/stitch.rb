require 'typhoeus'
require 'fiber'

class Stitch
  attr_accessor :hydra
  attr_accessor :states

  class ResponseFuture
    attr_accessor :hydra
    attr_accessor :request

    def initialize(hydra_arg, request_arg = nil)
      @hydra = hydra_arg
      self.request = request_arg if request_arg
      @pending = []
    end

    def request=(request_arg)
      @request = request_arg
      @request.on_complete{|response| complete(response) }
      hydra.queue(request)
    end

    def complete(response)
      @response = response
      @pending.each do |pend|
        result = response.send(pend[:method], *pend[:args])
        pend[:fiber].resume result
      end
    end

    def get(url)
      self.request = Typhoeus::Request.new(url, method: :get)
    end

    def method_missing(method, *args)
      super unless respond_to_missing?(method)

      if @response
        @response.send(method, *args)
      else
        # TODO: check for root fiber
        @pending << {fiber: Fiber.current, method: method, args: args}
        Fiber.yield
      end
    end

    def respond_to_missing?(method, include_private = false)
      if include_private
        Typhoeus::Response.instance_methods.include?(method)
      else
        Typhoeus::Response.public_instance_methods.include?(method)
      end
    end
  end

  def initialize
    @hydra = Typhoeus::Hydra.new
  end

  def context
    Fiber.new{ yield }.resume
    hydra
  end

  def future
    ResponseFuture.new(hydra)
  end

  def get(url)
    request = Typhoeus::Request.new(url, method: :get)
    ResponseFuture.new(hydra, request)
  end
end
