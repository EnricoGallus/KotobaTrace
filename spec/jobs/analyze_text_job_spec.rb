require 'rails_helper'

RSpec.describe AnalyzeTextJob, type: :job do
  describe "#perform" do
    it "analyzes the supplied text and broadcasts token results" do
      token = Japanese::Tokenizer::Token.new(
        surface: "猫",
        base_form: "猫",
        reading: "ネコ",
        part_of_speech: "名詞"
      )
      index = instance_double(Anki::VocabularyIndex)

      allow(Japanese::Tokenizer).to receive(:call).with("猫").and_return([ token ])
      allow(Anki::VocabularyIndex).to receive(:new).and_return(index)
      allow(index).to receive(:scan).and_return(index)
      allow(index).to receive(:include?).with("猫").and_return(true)

      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
        "stream-123",
        target: "analysis_results",
        partial: "analyses/results",
        locals: { results: [ { token: token, in_anki: true } ] }
      )

      described_class.perform_now("猫", "stream-123")
    end
  end
end
