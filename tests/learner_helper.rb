# frozen_string_literal: true

# Sets up who the browser is before the app boots. localStorage is per
# origin, so it is written from a page on the app's origin that is not the
# app (loading the app would already create a learner).
module LearnerHelper
  ANONYMOUS_TOKEN = 'anonymous-token-0123456789'
  REGISTERED_TOKEN = 'registered-token-0123456789'

  def prepare_browser(token: nil, email: nil, has_logged_in: false)
    visit '/api/v1/blank'
    page.execute_script(<<~JS, token, email, has_logged_in)
      localStorage.clear();
      if (arguments[0]) localStorage.setItem('manabase.token', arguments[0]);
      if (arguments[1]) localStorage.setItem('manabase.email', arguments[1]);
      if (arguments[2]) localStorage.setItem('manabase.hasLoggedIn', '1');
    JS
  end

  # A returning anonymous learner; the app checks the session with GET /me.
  def visit_as_anonymous(path = '/', courses: [])
    prepare_browser(token: ANONYMOUS_TOKEN)
    MOCK_API.stub('GET', '/me', body: { email: nil, courses: })
    visit path
    wait_for_cappuccino
  end

  def visit_as_registered(path = '/', email: 'student@example.com', courses: [])
    prepare_browser(token: REGISTERED_TOKEN, email:, has_logged_in: true)
    MOCK_API.stub('GET', '/me', body: { email:, courses: })
    visit path
    wait_for_cappuccino
  end

  def local_storage(key)
    page.evaluate_script("localStorage.getItem('#{key}')")
  end
end

RSpec.configure { |config| config.include LearnerHelper }
