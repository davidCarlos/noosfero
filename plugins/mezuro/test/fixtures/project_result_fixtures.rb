class ProjectResultFixtures

  def self.qt_calculator
    result = Kalibro::Entities::ProjectResult.new
    result.project = ProjectFixtures.qt_calculator
    result.date = ModuleResultFixtures.create.date
    result.load_time = 14878
    result.analysis_time = 1022
    result.source_tree = ModuleNodeFixtures.qt_calculator_tree
    result
  end

  def self.qt_calculator_hash
    {:project => ProjectFixtures.qt_calculator_hash, :date => ModuleResultFixtures.create.date,
      :load_time => 14878, :analysis_time => 1022, :source_tree => ModuleNodeFixtures.qt_calculator_tree_hash}
  end
    
end
