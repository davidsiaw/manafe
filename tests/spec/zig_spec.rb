# frozen_string_literal: true

require 'spec_helper'

# The Zig runtime compiles in the browser, with the real compiler from
# Resources/runtimes/zig/; only the backend is mocked. The first example to
# run downloads and starts it, which takes a few seconds.
RSpec.describe 'Zig problems', type: :feature do
  let(:course) do
    { id: 'zig', title: 'Zig',
      sections: [{ title: 'Only', problems: [{ id: 'sum', title: 'Sum' }], sections: [] }] }
  end

  let(:problem) do
    { id: 'sum', title: 'Sum', type: 'code', language: 'zig', run: 'browser',
      body: 'Adding.', question: 'Print the sum.', starter_code: "pub fn main() void {}\n",
      previous: nil, next: nil }
  end

  before do
    MOCK_API.stub('GET', '/courses/zig', body: course)
    MOCK_API.stub('GET', '/courses/zig/progress', body: progress)
    MOCK_API.stub('GET', '/courses/zig/problems/sum', body: problem)
    visit_as_anonymous('/#/courses/zig/sum')
    wait_for_cappuccino_text('Print the sum.')
  end

  it 'compiles and runs a program, counting std.debug.print as output' do
    fill_cappuccino_code(<<~ZIG)
      const std = @import("std");

      pub fn main() void {
          var total: u32 = 0;
          for ([_]u32{ 1, 2, 3 }) |n| total += n;
          std.debug.print("total: {d}\\n", .{total});
      }
    ZIG
    click_cappuccino_button('Run')

    wait_for_cappuccino_text('total: 6', wait: 30)
  end

  it "shows the compiler's errors and sends nothing" do
    fill_cappuccino_code(<<~ZIG)
      pub fn main() void {
          const count: u32 = 0;
          count += 1;
      }
    ZIG
    click_cappuccino_button('Check answer')

    wait_for_cappuccino_text_including('main.zig:3:5: error: cannot assign to constant', wait: 30)
    wait_for_cappuccino_text('Your program stopped with an error. Fix it and try again.')
    expect(MOCK_API.requests_to('POST', '/courses/zig/problems/sum/answer')).to be_empty
  end

  it 'shows a panic as the program crashing' do
    fill_cappuccino_code(<<~ZIG)
      const std = @import("std");

      pub fn main() void {
          const a = [_]u8{ 1, 2, 3 };
          var i: usize = 0;
          while (i <= a.len) : (i += 1) std.debug.print("{d}\\n", .{a[i]});
      }
    ZIG
    click_cappuccino_button('Run')

    wait_for_cappuccino_text_including('panic: index out of bounds: index 3, len 3', wait: 30)
    wait_for_cappuccino_text_including('The program crashed.')
  end
end
