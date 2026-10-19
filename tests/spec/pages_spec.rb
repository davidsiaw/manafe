# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'The course menu and my progress', type: :feature do
  let(:rust) do
    { id: 'rust', title: 'Rust Basics', description: 'About Rust.', problem_count: 12, solved_count: 3,
      next_problem_id: 'integers' }
  end
  let(:git) do
    { id: 'git', title: 'Git Basics', description: 'About Git.', problem_count: 6, solved_count: 0,
      next_problem_id: 'repositories' }
  end

  describe 'the course menu' do
    before do
      MOCK_API.stub('GET', '/courses', body: [git, rust])
      visit_as_anonymous('/')
    end

    it 'lists every course with how far the learner is' do
      wait_for_cappuccino_text('Courses')
      expect(cappuccino_text_values).to include('About Git.', '0 / 6 solved', 'About Rust.', '3 / 12 solved')
      wait_for_cappuccino_button('Rust Basics')
    end

    it 'opens a course where the learner left off' do
      problems = [{ id: 'syntax', title: 'Syntax' }, { id: 'integers', title: 'Integers' }]
      MOCK_API.stub('GET', '/courses/rust', body: { id: 'rust', title: 'Rust Basics',
                                                     sections: [{ title: 'S', problems:, sections: [] }] })
      MOCK_API.stub('GET', '/courses/rust/progress', body: progress(solved: ['syntax']))
      MOCK_API.stub('GET', '/courses/rust/problems/integers',
                    body: { id: 'integers', title: 'Integers', body: '', question: 'Q about integers?',
                            choices: [], previous: nil, next: nil })
      wait_for_cappuccino_button('Rust Basics')
      click_cappuccino_button('Rust Basics')

      wait_for_cappuccino_text('Q about integers?')
      expect(page).to have_current_path(%r{#/courses/rust/integers\z}, url: true)
    end
  end

  describe 'my progress' do
    it 'asks an anonymous learner to register, and shows the courses started' do
      MOCK_API.stub('GET', '/me', body: { email: nil, courses: [rust] }) # at startup
      visit_as_anonymous('/#/me', courses: [rust]) # and for the page

      wait_for_cappuccino_text('My progress')
      wait_for_cappuccino_button('Register')
      wait_for_cappuccino_text('3 / 12 solved')
      expect(cappuccino_text_values).not_to include('0 / 6 solved')
    end

    it 'shows who a registered learner is' do
      MOCK_API.stub('GET', '/me', body: { email: 'student@example.com', courses: [] }) # at startup
      visit_as_registered('/#/me', email: 'student@example.com') # and for the page

      wait_for_cappuccino_text('Logged in as student@example.com.')
      wait_for_cappuccino_text('You have not started a course yet.')
    end
  end

  describe 'the top bar' do
    it 'offers registering and logging in to an anonymous learner' do
      MOCK_API.stub('GET', '/courses', body: [])
      visit_as_anonymous('/')
      wait_for_cappuccino_button('Register')
      expect([cappuccino_button_visible?('Log in'), cappuccino_button_visible?('Log out')]).to eq [true, false]
    end

    it 'shows a registered learner\'s email and a way to log out' do
      MOCK_API.stub('GET', '/courses', body: [])
      visit_as_registered('/', email: 'student@example.com')
      wait_for_cappuccino_text('student@example.com')
      expect([cappuccino_button_visible?('Log out'), cappuccino_button_visible?('Register')]).to eq [true, false]
    end
  end
end
