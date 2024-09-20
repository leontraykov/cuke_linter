module CukeLinter
  # A linter that detects non-unique scenario names
  class UniqueScenarioNamesLinter < Linter

    def initialize
      super
      @scenario_names = {}
    end

    def rule(model)
      return nil unless valid_model?(model)

      feature_file = model.get_ancestor(:feature_file)
      return nil if feature_file.nil?
      
      file_path = feature_file.path

      case model
      when CukeModeler::Rule
        check_rule(model, file_path)
      when CukeModeler::Outline
        check_scenario_outline(model, file_path)
      when CukeModeler::Scenario
        check_scenario(model, file_path)
      else
        nil
      end
    end

    private

    def check_rule(model, file_path)
      problems = []
      rule_key = "#{file_path}:#{model.name}"

      model.scenarios.each do |scenario|
        problem = check_scenario(scenario, rule_key)
        problems << problem if problem
      end

      model.outlines.each do |outline|
        problem = check_scenario_outline(outline, rule_key)
        problems << problem if problem
      end

      problems.first
    end

    def check_scenario(model, scope_key)
      scenario_name = model.name
      check_duplicate(scenario_name, scope_key)
      return nil unless duplicate_name?(scenario_name, scope_key)
      
      @message = 'Scenario names are not unique'
      build_problem(model)
    end

    def check_scenario_outline(model, scope_key)
      base_name = model.name
      scenario_names = []

      model.examples.each do |example|
        header_row = example.rows.first
        example.rows[1..].each do |data_row|
          scenario_name = interpolate_name(base_name, header_row, data_row)
          scenario_names << scenario_name
        end
      end

      scenario_names.each do |scenario_name|
        check_duplicate(scenario_name, scope_key)
      end

      duplicates = scenario_names.select { |name| duplicate_name?(name, scope_key) }.uniq
      return nil if duplicates.empty?

      @message = 'Scenario names created by Scenario Outline are not unique'
      build_problem(model)
    end

    def interpolate_name(base_name, header_row, data_row)
      interpolated_name = base_name.dup
      header_row.cells.each_with_index do |header, index|
        interpolated_name.gsub!("<#{header.value}>", data_row.cells[index].value.to_s)
      end
      interpolated_name
    end

    def check_duplicate(scenario_name, scope_key)
      @scenario_names[scope_key] ||= []
      @scenario_names[scope_key] << scenario_name
    end

    def duplicate_name?(scenario_name, scope_key)
      @scenario_names[scope_key].count(scenario_name) > 1
    end

    def after_linting(_model)
      @scenario_names.clear
    end

    def valid_model?(model)
      model.is_a?(CukeModeler::Scenario) || 
      model.is_a?(CukeModeler::Outline) || 
      model.is_a?(CukeModeler::Rule)
    end
  end
end
