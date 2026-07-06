# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Fbr::JobRunner do
  describe '.inline?' do
    it 'returns true when INLINE_FBR_JOBS is set' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('INLINE_FBR_JOBS').and_return('true')

      expect(described_class.inline?).to be(true)
    end
  end

  describe '.enqueue' do
    let(:job_class) do
      Class.new(ApplicationJob) do
        cattr_accessor :calls
        self.calls = []

        def self.name
          'TestFbrJob'
        end

        def perform(value)
          self.class.calls << value
        end
      end
    end

    before { job_class.calls = [] }

    it 'runs immediately when inline mode is enabled' do
      allow(described_class).to receive(:inline?).and_return(true)

      expect(job_class).not_to receive(:perform_later)
      described_class.enqueue(job_class, 42)

      expect(job_class.calls).to eq([42])
    end

    it 'enqueues later when inline mode is disabled' do
      allow(described_class).to receive(:inline?).and_return(false)
      expect(job_class).to receive(:perform_later).with(42)

      described_class.enqueue(job_class, 42)
    end
  end
end
