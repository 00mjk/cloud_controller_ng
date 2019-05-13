require 'spec_helper'
require 'database/batch_delete'

RSpec.describe Database::BatchDelete do
  describe '#delete' do
    before do
      10.times do |t|
        date = t.days.ago
        VCAP::CloudController::Event.make(created_at: date)
      end
    end

    it 'deletes in batches' do
      # subtract a minute to avoid MySQL timestamp issues
      timestamp = VCAP::CloudController::Event.db.fetch('SELECT CURRENT_TIMESTAMP as now').first[:now] - 5.days - 1.minute
      dataset = VCAP::CloudController::Event.where(Sequel.lit('created_at < ?', timestamp))
      batch_delete = Database::BatchDelete.new(dataset, 1)
      expect(batch_delete).to receive(:delete_batch).exactly(4).times.and_call_original

      expect {
        batch_delete.delete
      }.to change { VCAP::CloudController::Event.count }.by(-4)
    end
  end
end
