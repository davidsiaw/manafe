# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Taking a course', type: :feature do
  let(:course) do
    {
      id: 'sample', title: 'Sample',
      sections: [
        { title: 'First', problems: [{ id: 'one', title: 'Problem one' }],
          sections: [{ title: 'Nested', problems: [{ id: 'two', title: 'Problem two' }], sections: [] }] },
        { title: 'Second', problems: [{ id: 'three', title: 'Problem three' }], sections: [] }
      ]
    }
  end

  def problem(id, title, previous: nil, next_problem: nil)
    {
      id:, title:, type: 'multiple_choice',
      body: "Explanation of #{id}.",
      question: "Question about #{id}?",
      choices: [{ id: 'a', text: 'Wrong choice' }, { id: 'b', text: 'Right choice' }],
      previous:, next: next_problem
    }
  end

  def stub_course(solved: [])
    MOCK_API.stub('GET', '/courses/sample', body: course)
    MOCK_API.stub('GET', '/courses/sample/progress', body: progress(solved:))
  end

  context 'with a first-time visitor' do
    before do
      MOCK_API.stub('POST', '/learners', status: 201, body: { token: 'new-token-0123456789' })
      stub_course
      MOCK_API.stub('GET', '/courses/sample/problems/one', body: problem('one', 'Problem one'))
      prepare_browser
      visit '/#/courses/sample'
      wait_for_cappuccino
    end

    it 'starts an anonymous session, keeps it, and sends it with later requests' do
      wait_for_cappuccino_text('Problem one')
      expect(local_storage('manabase.token')).to eq 'new-token-0123456789'
      expect(MOCK_API.requests_to('GET', '/courses/sample/progress').first.headers['Authorization'])
        .to eq 'Bearer new-token-0123456789'
    end

    it 'shows the tree with unsolved marks and opens the first problem' do
      wait_for_cappuccino_text('Question about one?')
      expect(cappuccino_outline_rows).to eq ['First', "\u25CB Problem one", 'Nested', 'Second', "\u25CB Problem three"]
      expect(current_url).to end_with '#/courses/sample/one'
    end
  end

  context 'when answering' do
    before do
      stub_course
      MOCK_API.stub('GET', '/courses/sample/problems/one', body: problem('one', 'Problem one'))
      visit_as_anonymous('/#/courses/sample/one')
      wait_for_cappuccino_text('Question about one?')
    end

    it 'says so and leaves the problem unticked when the answer is wrong' do
      MOCK_API.stub('POST', '/courses/sample/problems/one/answer', body: { correct: false })
      choose_cappuccino_radio('Wrong choice')
      click_cappuccino_button('Check answer')

      wait_for_cappuccino_text('Not quite. Try again.')
      expect(cappuccino_outline_rows).to include("\u25CB Problem one")
    end

    it 'ticks the problem in the sidebar when the answer is right' do
      MOCK_API.stub('POST', '/courses/sample/problems/one/answer',
                    body: { correct: true, explanation: 'Because.', progress: progress(solved: %w[one]) })
      choose_cappuccino_radio('Right choice')
      click_cappuccino_button('Check answer')

      wait_for_cappuccino_outline_row("\u2713 Problem one")
      wait_for_cappuccino_text('Correct! Because.')
      answer = MOCK_API.requests_to('POST', '/courses/sample/problems/one/answer').first
      expect([answer.body, answer.headers['Authorization']])
        .to eq [{ 'choice' => 'b', 'round' => 1 }, "Bearer #{LearnerHelper::ANONYMOUS_TOKEN}"]
    end

    it 'allows only one choice at a time' do
      choose_cappuccino_radio('Wrong choice')
      choose_cappuccino_radio('Right choice')
      expect(cappuccino_selected_radio_titles).to eq ['Right choice']
    end

    it 'asks for a choice before checking' do
      click_cappuccino_button('Check answer')
      wait_for_cappuccino_text('Pick an answer first.')
      expect(MOCK_API.requests_to('POST', '/courses/sample/problems/one/answer')).to be_empty
    end
  end

  context 'with a returning learner' do
    it 'shows earlier progress and opens the first unsolved problem' do
      stub_course(solved: %w[one])
      MOCK_API.stub('GET', '/courses/sample/problems/two', body: problem('two', 'Problem two'))
      visit_as_anonymous('/#/courses/sample')

      wait_for_cappuccino_text('Question about two?')
      expect(cappuccino_outline_rows).to include("\u2713 Problem one", "\u25CB Problem two")
      expect(MOCK_API.requests_to('POST', '/learners')).to be_empty
    end

    it 'starts over as a new anonymous learner when the server no longer knows the session' do
      prepare_browser(token: 'forgotten-token-0123456789')
      MOCK_API.stub('GET', '/me', status: 401, body: { error: 'unauthorized' })
      MOCK_API.stub('POST', '/learners', status: 201, body: { token: 'new-token-0123456789' })
      stub_course
      MOCK_API.stub('GET', '/courses/sample/problems/one', body: problem('one', 'Problem one'))
      visit '/#/courses/sample'
      wait_for_cappuccino

      wait_for_cappuccino_text('Question about one?')
      expect(local_storage('manabase.token')).to eq 'new-token-0123456789'
    end
  end

  context 'when the server keeps rejecting sessions' do
    it 'starts over only once, instead of creating learners in a loop' do
      prepare_browser(token: 'forgotten-token-0123456789')
      MOCK_API.stub('GET', '/me', status: 401, body: { error: 'unauthorized' })
      3.times { MOCK_API.stub('POST', '/learners', status: 201, body: { token: 'new-token-0123456789' }) }
      3.times { MOCK_API.stub('GET', '/courses/sample', body: course) }
      3.times { MOCK_API.stub('GET', '/courses/sample/progress', status: 401, body: { error: 'unauthorized' }) }
      visit '/#/courses/sample'
      wait_for_cappuccino

      wait_for_cappuccino_text_including('keeps rejecting')
      sleep 1
      expect(MOCK_API.requests_to('POST', '/learners').size).to eq 1
    end
  end

  context 'when moving between problems' do
    before { stub_course }

    it 'opens the problem named in the URL' do
      MOCK_API.stub('GET', '/courses/sample/problems/three', body: problem('three', 'Problem three'))
      visit_as_anonymous('/#/courses/sample/three')
      wait_for_cappuccino_text('Question about three?')
    end

    it 'follows the Next button into a nested section, and puts it in the URL' do
      MOCK_API.stub('GET', '/courses/sample/problems/one',
                    body: problem('one', 'Problem one', next_problem: { id: 'two', title: 'Problem two' }))
      MOCK_API.stub('GET', '/courses/sample/problems/two', body: problem('two', 'Problem two'))
      visit_as_anonymous('/#/courses/sample/one')
      wait_for_cappuccino_button("Problem two \u2192")

      click_cappuccino_button("Problem two \u2192")
      wait_for_cappuccino_text('Question about two?')
      expect(cappuccino_outline_rows).to include('Nested', "\u25CB Problem two")
      expect(current_url).to end_with '#/courses/sample/two'
    end
  end
end
