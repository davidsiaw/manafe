# frozen_string_literal: true

require 'spec_helper'

# Code problems run in the browser, on the real runtime in Resources/runtimes/;
# only the backend is mocked.
RSpec.describe 'Code problems', type: :feature do
  let(:course) do
    { id: 'ruby', title: 'Ruby',
      sections: [{ title: 'Only', problems: [{ id: 'hello', title: 'Hello' }], sections: [] }] }
  end

  let(:problem) do
    { id: 'hello', title: 'Hello', type: 'code', language: 'ruby',
      body: 'Printing.', question: 'Print hello, then the sum of 1 and 2.',
      starter_code: "# your code here\n", previous: nil, next: nil }
  end

  before do
    MOCK_API.stub('GET', '/courses/ruby', body: course)
    MOCK_API.stub('GET', '/courses/ruby/progress', body: progress)
    MOCK_API.stub('GET', '/courses/ruby/problems/hello', body: problem)
    visit_as_anonymous('/#/courses/ruby/hello')
    wait_for_cappuccino_text('Print hello, then the sum of 1 and 2.')
  end

  def answer_requests
    MOCK_API.requests_to('POST', '/courses/ruby/problems/hello/answer')
  end

  it 'starts with the starter code, without choices' do
    expect(cappuccino_code).to eq "# your code here\n"
    expect(cappuccino_button_visible?('Run')).to be true
  end

  it 'runs the program in the browser and shows what it printed' do
    fill_cappuccino_code(%(print "hel"\nputs "lo"\nputs [1, 2].sum))
    click_cappuccino_button('Run')

    wait_for_cappuccino_text("hello\n3")
    expect(answer_requests).to be_empty
  end

  it 'sends the output when checking, and ticks the problem when it is right' do
    MOCK_API.stub('POST', '/courses/ruby/problems/hello/answer',
                  body: { correct: true, explanation: 'Well done.', progress: progress(solved: %w[hello]) })
    fill_cappuccino_code(%(puts "hello"\nputs 1 + 2))
    click_cappuccino_button('Check answer')

    wait_for_cappuccino_outline_row("\u2713 Hello")
    wait_for_cappuccino_text('Correct! Well done.')
    expect(answer_requests.first.body).to eq('output' => "hello\n3\n", 'round' => 1)
  end

  it 'says so when the output is not what was asked for' do
    MOCK_API.stub('POST', '/courses/ruby/problems/hello/answer', body: { correct: false })
    fill_cappuccino_code('puts "hi"')
    click_cappuccino_button('Check answer')

    wait_for_cappuccino_text_including('did not print what the question asks for')
  end

  it 'shows an error and does not send output from a program that failed' do
    fill_cappuccino_code(%(puts "hello"\nputs 1 + nil))
    click_cappuccino_button('Check answer')

    wait_for_cappuccino_text_including('(TypeError)')
    wait_for_cappuccino_text('Your program stopped with an error. Fix it and try again.')
    expect(answer_requests).to be_empty
  end

  it 'stops a program that never ends, and can run another afterwards' do
    fill_cappuccino_code('loop { }')
    click_cappuccino_button('Run')
    wait_for_cappuccino_text_including('was stopped', wait: 20)

    fill_cappuccino_code('puts "again"')
    click_cappuccino_button('Run')
    wait_for_cappuccino_text('again')
  end

  it 'takes typing into the editor, indenting Ruby as it goes' do
    fill_cappuccino_code('')
    click_cappuccino_code_editor
    page.driver.browser.action.send_keys('3.times do |i|', :enter, 'puts i', :enter, 'end').perform

    # Return indents inside the block, and typing end takes it back out.
    wait_for_code("3.times do |i|\n  puts i\nend")
  end

  it 'indents with Tab instead of leaving the editor' do
    fill_cappuccino_code('')
    click_cappuccino_code_editor
    page.driver.browser.action.send_keys(:tab, 'x').perform

    wait_for_code('  x')
  end

  def wait_for_code(code)
    deadline = Time.now + 5
    sleep 0.1 until cappuccino_code == code || Time.now > deadline
    expect(cappuccino_code).to eq code
  end
end
