# frozen_string_literal: true

# Passkeys in browser specs: Chrome's virtual authenticator stands in for
# the device, and these build the options the backend would send. The mock
# API returns them; the SPA hands them to navigator.credentials, and the
# virtual authenticator answers as a real one would.
module PasskeyHelper
  def add_virtual_authenticator
    options = Selenium::WebDriver::VirtualAuthenticatorOptions.new(
      protocol: :ctap2, transport: :internal, resident_key: true,
      user_verification: true, user_verified: true
    )
    @virtual_authenticator = page.driver.browser.add_virtual_authenticator(options)
  end

  def remove_virtual_authenticator
    @virtual_authenticator&.remove!
    @virtual_authenticator = nil
  end

  def base64url(bytes)
    [bytes].pack('m0').tr('+/', '-_').delete('=')
  end

  def registration_options(email, user_id: 'user-handle-1')
    {
      challenge: base64url(SecureRandom.random_bytes(32)),
      rp: { name: 'Manabase', id: APP_HOST },
      user: { id: base64url(user_id), name: email, displayName: email },
      pubKeyCredParams: [{ type: 'public-key', alg: -7 }],
      authenticatorSelection: { residentKey: 'required', userVerification: 'preferred' },
      timeout: 60_000
    }
  end

  def login_options
    { challenge: base64url(SecureRandom.random_bytes(32)), rpId: APP_HOST, userVerification: 'preferred',
      timeout: 60_000 }
  end
end

RSpec.configure do |config|
  config.include PasskeyHelper
  config.after { remove_virtual_authenticator }
end
