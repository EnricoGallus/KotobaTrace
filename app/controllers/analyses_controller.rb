class AnalysesController < ApplicationController
  def new
  end

  def create
    text = params[:text].to_s
    AnalyzeTextJob.perform_later(text)

    render json: { message: "Analysis started" }, status: :accepted
  end

  def self.broadcast_result(result)
    ActionCable.server.broadcast "analyze_channel", result: result
  end

  private

  def vocabulary_token?(token)
    %w[名詞 動詞 形容詞].include?(token.part_of_speech)
  end
end
