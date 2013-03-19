require 'typhoeus'
require 'fiber'

class Stitch
  attr_accessor :hydra
  attr_accessor :states

  class ResponseFuture
    attr_accessor :hydra
    attr_accessor :request

    def initialize(hydra_arg, request_arg)
      @request = request_arg
      @request.on_complete{|response| complete(response) }
      @hydra = hydra_arg
      @pending = []
      hydra.queue(request)
    end

    def complete(response)
      @response = response
      @pending.each{|pend| pend[:fiber].resume response.send(pend[:method], *pend[:args]) }
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

  def get(url)
    request = Typhoeus::Request.new(url, method: :get)
    ResponseFuture.new(hydra, request)
  end
end
