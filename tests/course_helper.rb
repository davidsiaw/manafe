# frozen_string_literal: true

# Builds course data the way the backend sends it.
module CourseHelper
  # GET /courses/:id/progress, and `progress` in an answer. Counts each
  # solved problem once per round unless times_solved says otherwise.
  def progress(solved: [], revision: nil, times_solved: nil, times_completed: 0)
    counts = (solved + (revision ? revision[:solved] : [])).tally
    { solved:, revision:, times_solved: times_solved || counts, times_completed: }
  end
end

RSpec.configure { |config| config.include CourseHelper }
