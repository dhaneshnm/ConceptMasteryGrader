class AddOverallScoreToGradeReports < ActiveRecord::Migration[8.1]
  def change
    add_column :grade_reports, :overall_score, :decimal, precision: 5, scale: 3
    
    # Populate existing records with calculated overall scores
    reversible do |dir|
      dir.up do
        GradeReport.reset_column_information
        GradeReport.find_each do |report|
          if report.scores.present?
            # Calculate average score from the scores hash
            total = report.scores.values.sum { |score| level_to_number(score) }
            avg_score = total.to_f / report.scores.size / 4.0 # Convert to 0-1 scale
            report.update_column(:overall_score, avg_score.round(3))
          end
        end
      end
    end
  end
  
  private
  
  def level_to_number(level)
    case level.to_s.downcase
    when 'beginner' then 1
    when 'developing' then 2
    when 'proficient' then 3
    when 'mastery' then 4
    else 0
    end
  end
end
