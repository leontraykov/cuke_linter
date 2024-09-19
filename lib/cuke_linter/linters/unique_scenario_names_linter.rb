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
      file_path = feature_file.path

      if model.is_a?(CukeModeler::Rule)
        check_rule(model)
      elsif model.is_a?(CukeModeler::Outline)
        check_scenario_outline(model, file_path)
      else
        check_scenario(model, file_path)
      end
    end

    private

    def check_rule(model)
      errors = []

      model.scenarios.each do |scenario|
        result = rule(scenario)
        errors << result if result.is_a?(Hash)
      end

      model.outlines.each do |outline|
        result = rule(outline)
        errors << result if result.is_a?(Hash)
      end

      errors.empty? ? nil : errors.first
    end

    def check_scenario(model, file_path)
      scenario_name = model.name
      check_duplicate(scenario_name, file_path)
      return nil unless duplicate_name?(scenario_name, file_path)

      @message = 'Scenario names are not unique'
      problem = build_problem(model)
      problem.merge(linter: name)
    end

    def check_scenario_outline(model, file_path)
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
        check_duplicate(scenario_name, file_path)
      end

      duplicate_found = scenario_names.any? { |name| duplicate_name?(name, file_path) }

      if duplicate_found
        @message = 'Template creates scenario names that are not unique'
        problem = build_problem(model)
        problem.merge(linter: name)
      end
    end

    def interpolate_name(base_name, header_row, data_row)
      interpolated_name = base_name.dup
      header_row.cells.each_with_index do |header, index|
        interpolated_name.gsub!("<#{header.value}>", data_row.cells[index].value.to_s)
      end
      interpolated_name
    end

    def check_duplicate(scenario_name, file_path)
      @scenario_names[file_path] ||= []
      @scenario_names[file_path] << scenario_name
    end

    def duplicate_name?(scenario_name, file_path)
      @scenario_names[file_path].count(scenario_name) > 1
    end

    def after_linting(_model)
      @scenario_names.clear
    end

    def valid_model?(model)
      model.is_a?(CukeModeler::Scenario) || model.is_a?(CukeModeler::Outline) || model.is_a?(CukeModeler::Rule)
    end
  end
end
