# frozen_string_literal: true

require 'capybara'
require 'capybara/rspec'
require 'selenium-webdriver'
require 'rspec'
require 'chino'

require_relative 'cappuccino_helper'
require_relative 'mock_api'
require_relative 'passkey_helper'
require_relative 'learner_helper'
require_relative 'course_helper'

CHROME_HOSTNAME = ENV.fetch('CHROME_HOSTNAME')
TEST_HOST       = ENV.fetch('TEST_HOST')
# Not 4444: in the app container, the dev server's chino already has that.
TEST_PORT       = Integer(ENV.fetch('TEST_PORT', '4445'))
# Chrome reaches the app under this name, which it maps to TEST_HOST. Passkeys
# need a domain name (TEST_HOST may be an IP address) and a secure origin,
# which chrome is told to consider http://APP_HOST:TEST_PORT to be.
APP_HOST        = 'manabase-test'
APP_ORIGIN      = "http://#{APP_HOST}:#{TEST_PORT}".freeze

# The specs serve the app themselves: chino's Sinatra app at /, and the mock
# backend at /api/v1 on the same origin. Config.j.erb is rendered per request
# from this process's ENV, so the SPA talks to the mock.
ENV['API_BASE_URL'] = '/api/v1'
MOCK_API = MockApi.new
# chino resolves files against the working directory; scripts/rspec runs from
# the project root.
Chino::Website.setup(Chino::Config.new)

Capybara.register_driver(:remote_chrome) do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-notifications')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1280,800')
  options.add_argument("--host-resolver-rules=MAP #{APP_HOST} #{TEST_HOST}")
  options.add_argument("--unsafely-treat-insecure-origin-as-secure=#{APP_ORIGIN}")

  Capybara::Selenium::Driver.new(
    app,
    browser: :remote,
    url:     "http://#{CHROME_HOSTNAME}:4444/wd/hub",
    options: options
  )
end

Capybara.default_driver    = :remote_chrome
Capybara.javascript_driver = :remote_chrome
Capybara.app               = Rack::URLMap.new('/api/v1' => MOCK_API, '/' => Chino::Website)
Capybara.server            = :puma, { Silent: true }
Capybara.server_host       = '0.0.0.0'
Capybara.server_port       = TEST_PORT
Capybara.app_host          = APP_ORIGIN
Capybara.default_max_wait_time = 15

RSpec.configure do |config|
  config.include CappuccinoHelper
  config.include Capybara::DSL

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.before { MOCK_API.reset! }

  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
