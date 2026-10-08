class WordOccurrence < ApplicationRecord
  belongs_to :analysis
  belongs_to :word
end
