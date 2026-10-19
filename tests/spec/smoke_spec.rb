# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Manabase smoke', type: :feature do
  before { visit '/' }

  it 'serves the SPA shell' do
    expect(page).to have_title('Manabase')
  end

  it 'boots Cappuccino and says so when the backend is unreachable' do
    wait_for_cappuccino
    # No stubs are queued, so the mock API answers 599.
    wait_for_cappuccino_text('Could not reach the server (599).')
  end
end
