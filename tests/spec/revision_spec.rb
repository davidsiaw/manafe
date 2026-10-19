# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Revision mode', type: :feature do
  let(:course) do
    { id: 'sample', title: 'Sample',
      sections: [{ title: 'Only', problems: [{ id: 'one', title: 'Problem one' }, { id: 'two', title: 'Problem two' }],
                   sections: [] }] }
  end

  def problem(id, choices: [{ id: 'a', text: 'Wrong choice' }, { id: 'b', text: 'Right choice' }])
    { id:, title: "Problem #{id}", type: 'multiple_choice', body: "About #{id}.", question: "Question about #{id}?",
      choices:, previous: nil, next: nil }
  end

  let(:round1_done) { progress(solved: %w[one two], times_completed: 1) }

  def visit_course(path, course_progress)
    MOCK_API.stub('GET', '/courses/sample', body: course)
    MOCK_API.stub('GET', '/courses/sample/progress', body: course_progress)
    visit_as_anonymous(path)
  end

  it 'explains itself in a popover next to the switch' do
    MOCK_API.stub('GET', '/courses/sample/problems/one', body: problem('one'))
    visit_course('/#/courses/sample/one', round1_done)
    wait_for_cappuccino_button('?')
    click_cappuccino_button('?')
    wait_for_cappuccino_text_including('Revision mode lets you go through the course again from the start')
  end

  it 'shows how often the course was completed, outside revision mode' do
    MOCK_API.stub('GET', '/courses/sample/problems/one', body: problem('one'))
    visit_course('/#/courses/sample/one', round1_done)
    wait_for_cappuccino_text('Completed 1 time')
    expect(cappuccino_outline_rows).to include("\u2713 Problem one", "\u2713 Problem two")
  end

  context 'when switching it on for the first time' do
    before do
      MOCK_API.stub('GET', '/courses/sample/problems/one', body: problem('one'))
      visit_course('/#/courses/sample/one', round1_done)
      wait_for_cappuccino_text('Question about one?')

      MOCK_API.stub('POST', '/courses/sample/revisions', status: 201,
                                                         body: progress(solved: %w[one two], times_completed: 1,
                                                                        revision: { number: 2, solved: [] }))
      MOCK_API.stub('GET', '/courses/sample/problems/one',
                    body: problem('one', choices: [{ id: 'b', text: 'Right choice' }, { id: 'a', text: 'Wrong choice' }]))
      click_cappuccino_button('Revision mode')
    end

    it 'starts a revision from nothing, marking what was solved before' do
      wait_for_cappuccino_text('Revision 1: 0 / 2 solved')
      expect(cappuccino_outline_rows).to include("\u25CB Problem one  \u00D71", "\u25CB Problem two  \u00D71")
      expect(page).to have_current_path(%r{#/revise/sample/one\z}, url: true)
    end

    it 'asks for the problem in the revision\'s round, and answers in it' do
      wait_for_cappuccino_text('Revision 1: 0 / 2 solved')
      wait_for_cappuccino_text('Question about one?')
      expect(MOCK_API.requests.map { |r| "#{r.method} #{r.path}" }).to include('POST /courses/sample/revisions')

      MOCK_API.stub('POST', '/courses/sample/problems/one/answer',
                    body: { correct: true, explanation: '',
                            progress: progress(solved: %w[one two], times_completed: 1,
                                               revision: { number: 2, solved: %w[one] }) })
      choose_cappuccino_radio('Right choice')
      click_cappuccino_button('Check answer')

      wait_for_cappuccino_outline_row("\u2713 Problem one  \u00D72")
      wait_for_cappuccino_text('Revision 1: 1 / 2 solved')
      expect(MOCK_API.requests_to('POST', '/courses/sample/problems/one/answer').first.body)
        .to eq('choice' => 'b', 'round' => 2)
    end
  end

  it 'says so when a revision completes the course again' do
    in_revision = progress(solved: %w[one two], times_completed: 1, revision: { number: 2, solved: %w[one] })
    MOCK_API.stub('GET', '/courses/sample/problems/two', body: problem('two'))
    visit_course('/#/revise/sample/two', in_revision)
    wait_for_cappuccino_text('Question about two?')
    expect(MOCK_API.requests.map(&:path)).to include('/courses/sample/problems/two')

    MOCK_API.stub('POST', '/courses/sample/problems/two/answer',
                  body: { correct: true, explanation: 'Yes.',
                          progress: progress(solved: %w[one two], times_completed: 2,
                                             revision: { number: 2, solved: %w[one two] }) })
    choose_cappuccino_radio('Right choice')
    click_cappuccino_button('Check answer')
    wait_for_cappuccino_text_including('Revision complete! You have completed this course 2 times.')
  end

  it 'starts over after a confirmation, leaving round 1 alone' do
    in_revision = progress(solved: %w[one two], times_completed: 1, revision: { number: 2, solved: %w[one] })
    MOCK_API.stub('GET', '/courses/sample/problems/two', body: problem('two'))
    visit_course('/#/revise/sample/two', in_revision)
    wait_for_cappuccino_text('Revision 1: 1 / 2 solved')

    MOCK_API.stub('POST', '/courses/sample/revisions', status: 201,
                                                       body: progress(solved: %w[one two], times_completed: 1,
                                                                      revision: { number: 3, solved: [] }))
    MOCK_API.stub('GET', '/courses/sample/problems/one', body: problem('one'))
    click_cappuccino_button('Start over')
    wait_for_cappuccino_button('Start again')
    click_cappuccino_button('Start again')

    wait_for_cappuccino_text('Revision 2: 0 / 2 solved')
    wait_for_cappuccino_text('Question about one?')
    expect(MOCK_API.requests_to('GET', '/courses/sample/problems/one').first.path).to eq '/courses/sample/problems/one'
  end

  it 'goes back to round 1 when switched off' do
    in_revision = progress(solved: %w[one], times_completed: 0, revision: { number: 2, solved: [] })
    MOCK_API.stub('GET', '/courses/sample/problems/one', body: problem('one'))
    visit_course('/#/revise/sample/one', in_revision)
    wait_for_cappuccino_text('Revision 1: 0 / 2 solved')

    MOCK_API.stub('GET', '/courses/sample/problems/two', body: problem('two'))
    click_cappuccino_button('Revision mode')
    wait_for_cappuccino_text('Not completed yet')
    wait_for_cappuccino_text('Question about two?')
    expect(page).to have_current_path(%r{#/courses/sample/two\z}, url: true)
  end

  it 'offers to continue a revision from the course menu' do
    MOCK_API.stub('GET', '/courses', body: [{ id: 'sample', title: 'Sample', description: '', problem_count: 2,
                                              solved_count: 2, next_problem_id: 'one', times_completed: 1,
                                              revision: { number: 2, solved_count: 1, next_problem_id: 'two' } }])
    visit_as_anonymous('/')
    wait_for_cappuccino_text('2 / 2 solved · completed 1 time')
    wait_for_cappuccino_text('Revision 1: 1 / 2 solved')

    MOCK_API.stub('GET', '/courses/sample', body: course)
    MOCK_API.stub('GET', '/courses/sample/progress',
                  body: progress(solved: %w[one two], times_completed: 1, revision: { number: 2, solved: %w[one] }))
    MOCK_API.stub('GET', '/courses/sample/problems/two', body: problem('two'))
    click_cappuccino_button('Continue revision of Sample')
    wait_for_cappuccino_text('Question about two?')
    expect(page).to have_current_path(%r{#/revise/sample/two\z}, url: true)
  end
end
