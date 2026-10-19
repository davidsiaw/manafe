# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Registering, logging in and out', type: :feature do
  let(:email) { 'student@example.com' }

  def register(email)
    wait_for_cappuccino_button('Create passkey')
    fill_cappuccino_field('you@example.com', email)
    click_cappuccino_button('Create passkey')
  end

  describe 'registering' do
    before do
      MOCK_API.stub('GET', '/courses', body: [])
      visit_as_anonymous('/#/register')
      add_virtual_authenticator
    end

    it 'creates a passkey for the email and becomes registered' do
      MOCK_API.stub('POST', '/registration/options', body: registration_options(email))
      MOCK_API.stub('POST', '/registration', body: { email: })
      MOCK_API.stub('GET', '/me', body: { email:, courses: [] })
      register(email)

      wait_for_cappuccino_text("Logged in as #{email}.")
      options_request, = MOCK_API.requests_to('POST', '/registration/options')
      credential = MOCK_API.requests_to('POST', '/registration').first.body['credential']
      expect([options_request.body, options_request.headers['Authorization']])
        .to eq [{ 'email' => email }, "Bearer #{LearnerHelper::ANONYMOUS_TOKEN}"]
      expect(credential['response'].keys).to include('attestationObject', 'clientDataJSON')
      expect([local_storage('manabase.email'), local_storage('manabase.hasLoggedIn')]).to eq [email, '1']
    end

    it 'refuses an email that is already registered' do
      MOCK_API.stub('POST', '/registration/options', status: 409, body: { error: 'email_taken' })
      register(email)

      wait_for_cappuccino_text('That email is already registered. Log in instead.')
      expect(MOCK_API.requests_to('POST', '/registration')).to be_empty
    end
  end

  describe 'logging out' do
    before do
      MOCK_API.stub('GET', '/courses', body: [])
      visit_as_registered('/', email:)
      wait_for_cappuccino_button('Log out')
      MOCK_API.stub('DELETE', '/session', status: 204, body: {})
      click_cappuccino_button('Log out')
    end

    it 'ends the session and asks to log in again' do
      wait_for_cappuccino_text('You are logged out')
      expect(MOCK_API.requests_to('DELETE', '/session').first.headers['Authorization'])
        .to eq "Bearer #{LearnerHelper::REGISTERED_TOKEN}"
      expect(local_storage('manabase.token')).to be_nil
    end

    it 'does not become anonymous again, even after a reload' do
      wait_for_cappuccino_text('You are logged out')
      visit '/#/courses/sample'
      wait_for_cappuccino
      wait_for_cappuccino_text('You are logged out')
      expect(MOCK_API.requests_to('POST', '/learners')).to be_empty
    end
  end

  describe 'logging in' do
    before do
      prepare_browser(has_logged_in: true)
      visit '/'
      wait_for_cappuccino
      wait_for_cappuccino_button('Log in with a passkey')
      add_virtual_authenticator
    end

    # A passkey made by registering a new account from the logged-out page,
    # which the specs below then log in with.
    def create_account_and_log_out
      MOCK_API.stub('POST', '/learners', status: 201, body: { token: 'new-account-token-0123456789' })
      MOCK_API.stub('POST', '/registration/options', body: registration_options(email, user_id: 'user-42'))
      MOCK_API.stub('POST', '/registration', body: { email: })
      MOCK_API.stub('GET', '/me', body: { email:, courses: [] })
      click_cappuccino_button('Create a new account')
      register(email)
      wait_for_cappuccino_text("Logged in as #{email}.")

      MOCK_API.stub('DELETE', '/session', status: 204, body: {})
      click_cappuccino_button('Log out')
      wait_for_cappuccino_text('You are logged out')
    end

    it 'can create a new account from the logged-out page' do
      create_account_and_log_out
      expect(MOCK_API.requests_to('POST', '/registration').first.headers['Authorization'])
        .to eq 'Bearer new-account-token-0123456789'
    end

    it 'logs in with the passkey, without asking for the email' do
      create_account_and_log_out
      MOCK_API.stub('POST', '/login/options', body: login_options)
      MOCK_API.stub('POST', '/login', body: { token: 'login-token-0123456789', email: })
      MOCK_API.stub('GET', '/courses', body: [])
      click_cappuccino_button('Log in with a passkey')

      wait_for_cappuccino_button('Log out')
      credential = MOCK_API.requests_to('POST', '/login').first.body['credential']
      expect(credential['response']['userHandle']).to eq base64url('user-42')
      expect(local_storage('manabase.token')).to eq 'login-token-0123456789'
    end

    it 'says so when the browser has no passkey for the site' do
      MOCK_API.stub('POST', '/login/options', body: login_options)
      click_cappuccino_button('Log in with a passkey')
      wait_for_cappuccino_text_including('passkey request')
      expect(MOCK_API.requests_to('POST', '/login')).to be_empty
    end
  end
end
