# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
[
  [ "ignore", 0 ],
  [ "unknown", 1 ],
  [ "reading_only", 2 ],
  [ "meaning_only", 3 ],
  [ "known", 4 ]
].each do |key, position|
  choice = AssessmentChoice.find_or_initialize_by(key: key)
  choice.update!(position: position)
end
