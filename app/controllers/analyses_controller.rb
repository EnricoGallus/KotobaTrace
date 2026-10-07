class AnalysesController < ApplicationController
  def new
  end

  def create
    @text = params[:text].to_s
    tokens = Japanese::Tokenizer.call(@text)

    collection = Anki::VocabularyIndex.new

    collection.scan(
      decks: ["2026 JLPT N2::新完全マスターN2 - 語彙"],
      expression_field: "Expression"
    )

    @tokens = tokens.map do |token|
      {
        token:,
        in_anki: vocabulary_token?(token) ?
          collection.include?(token.base_form) :
          nil
      }
    end

    render :new
  end

  private

  def vocabulary_token?(token)
    %w[名詞 動詞 形容詞].include?(token.part_of_speech)
  end
end