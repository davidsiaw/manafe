# frozen_string_literal: true

require 'json'
require 'rack'

# Stands in for the backend in browser specs. Specs queue a response per
# "METHOD /path"; each request takes the next one in FIFO order, and every
# request is recorded so that specs can assert on what the SPA sent, with its
# Authorization header and parsed JSON body.
#
# Plain Rack rather than Sinatra, because rack-protection rejects requests
# that look cross-origin. A request with nothing queued gets a 599, so a
# missing stub shows up in the request log rather than as a hang.
class MockApi
  Request = Struct.new(:method, :path, :headers, :body, keyword_init: true)

  attr_reader :requests

  def initialize
    @mutex = Mutex.new
    reset!
  end

  def reset!
    @mutex.synchronize do
      @queues = Hash.new { |h, k| h[k] = [] }
      @requests = []
    end
  end

  def stub(method, path, status: 200, body: {})
    @mutex.synchronize { @queues["#{method} #{path}"] << [status, body] }
  end

  def requests_to(method, path)
    @mutex.synchronize { @requests.select { |r| r.method == method && r.path == path } }
  end

  def call(env)
    request = Rack::Request.new(env)
    body = request.body&.read.to_s
    record(request, body)

    status, payload = @mutex.synchronize do
      @queues["#{request.request_method} #{request.path_info}"].shift
    end
    status ||= 599
    payload ||= { error: "no stub for #{request.request_method} #{request.path_info}" }
    [status, { 'content-type' => 'application/json' }, [payload.to_json]]
  end

  private

  def record(request, body)
    headers = { 'Authorization' => request.get_header('HTTP_AUTHORIZATION') }
    parsed = body.empty? ? nil : JSON.parse(body)
    @mutex.synchronize do
      @requests << Request.new(method: request.request_method, path: request.path_info, headers:, body: parsed)
    end
  end
end
