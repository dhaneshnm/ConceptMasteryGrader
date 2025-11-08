class AddSeverityToMisconceptionPatterns < ActiveRecord::Migration[8.1]
  def change
    add_column :misconception_patterns, :severity, :string
  end
end
