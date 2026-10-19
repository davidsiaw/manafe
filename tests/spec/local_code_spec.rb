# frozen_string_literal: true

require 'spec_helper'

# Code problems with run: local are run on the learner's computer: the app
# offers the code to copy and takes the program's output, pasted back.
RSpec.describe 'Code problems run on the learner\'s computer', type: :feature do
  let(:course) do
    { id: 'rust', title: 'Rust',
      sections: [{ title: 'Only', problems: [{ id: 'hello', title: 'Hello' }], sections: [] }] }
  end

  let(:problem) do
    { id: 'hello', title: 'Hello', type: 'code', language: 'rust', run: 'local',
      body: 'Install Rust.', question: 'Run it and paste what it printed.',
      starter_code: "fn main() {\n    println!(\"Hello, world!\");\n}\n", previous: nil, next: nil }
  end

  before do
    MOCK_API.stub('GET', '/courses/rust', body: course)
    MOCK_API.stub('GET', '/courses/rust/progress', body: progress)
    MOCK_API.stub('GET', '/courses/rust/problems/hello', body: problem)
    visit_as_anonymous('/#/courses/rust/hello')
    wait_for_cappuccino_text('Run it and paste what it printed.')
  end

  def answer_requests
    MOCK_API.requests_to('POST', '/courses/rust/problems/hello/answer')
  end

  it 'shows the code with Copy code and a box for the output, and no Run button' do
    expect(cappuccino_code).to start_with 'fn main() {'
    expect(cappuccino_button_visible?('Copy code')).to be true
    expect(cappuccino_button_visible?('Run')).to be false
    wait_for_cappuccino_text('What your program printed:')
  end

  it 'sends what was pasted, and ticks the problem when it is right' do
    MOCK_API.stub('POST', '/courses/rust/problems/hello/answer',
                  body: { correct: true, explanation: 'Rust works.', progress: progress(solved: %w[hello]) })
    pasted = "   Compiling hello v0.1.0\n     Running `target/debug/hello`\nHello, world!\n"
    paste_cappuccino_output(pasted)
    click_cappuccino_button('Check answer')

    wait_for_cappuccino_outline_row("\u2713 Hello")
    expect(answer_requests.first.body).to eq('output' => pasted, 'round' => 1)
  end

  it 'asks for the output before checking' do
    click_cappuccino_button('Check answer')

    wait_for_cappuccino_text('Run the program on your computer and paste what it printed first.')
    expect(answer_requests).to be_empty
  end

  it 'takes typing into the output box' do
    MOCK_API.stub('POST', '/courses/rust/problems/hello/answer', body: { correct: false })
    all('.cm-content', visible: true).last.click
    page.driver.browser.action.send_keys('Hello, world!').perform
    click_cappuccino_button('Check answer')

    wait_for_cappuccino_text_including('did not print what the question asks for')
    expect(answer_requests.first.body['output']).to eq 'Hello, world!'
  end
end
