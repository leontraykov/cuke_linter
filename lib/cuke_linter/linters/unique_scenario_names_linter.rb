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
      when CukeModeler::Scenario, CukeModeler::Outline
        return nil if model.get_ancestor(:rule)

        scope_key = "#{file_path}:feature"

        if model.is_a?(CukeModeler::Outline)
          check_scenario_outline(model, scope_key)
        else
          check_scenario(model, scope_key)
        end
      else
        nil
      end
    end

    def message
      @specified_message || 'Scenario names are not unique'
    end

    private

    def check_rule(model, file_path)
      scope_key = "#{file_path}:rule:#{model.name}"
    
      problems = model.scenarios.map { |scenario| check_scenario(scenario, scope_key) }
      problems += model.outlines.map { |outline| check_scenario_outline(outline, scope_key) }
      
      problems.compact.first
    end

    def create_duplicate_message(name, scope_key, is_outline = false)
      original_line = @scenario_names[scope_key][name].first
      duplicate_lines = @scenario_names[scope_key][name][1..].join(', ')
      prefix = is_outline ? "Scenario name created by Scenario Outline" : "Scenario name"
      "#{prefix} '#{name}' is not unique. \n" \
      "    Original name is on line: #{original_line} \n" \
      "    Duplicate is on: #{duplicate_lines}"
    end

    def check_scenario(model, scope_key)
      scenario_name = model.name
      record_scenario(scenario_name, scope_key, model.source_line)
      return nil unless duplicate_name?(scenario_name, scope_key)
      @specified_message = create_duplicate_message(scenario_name, scope_key)
    end

    def check_scenario_outline(model, scope_key)
      base_name = model.name
      scenario_names = model.examples.flat_map do |example|
        header_row = example.rows.first
        example.rows[1..].map do |data_row|
          interpolate_name(base_name, header_row, data_row)
        end
      end
      scenario_names.each do |scenario_name|
        record_scenario(scenario_name, scope_key, model.source_line)
      end
      duplicates = scenario_names.select { |name| duplicate_name?(name, scope_key) }.uniq
      return nil if duplicates.empty?
      @specified_message = create_duplicate_message(duplicates.first, scope_key, true)
    end

    def interpolate_name(base_name, header_row, data_row)
      interpolated_name = base_name.dup
      header_row.cells.each_with_index do |header, index|
        interpolated_name.gsub!("<#{header.value}>", data_row.cells[index].value.to_s)
      end
      interpolated_name
    end

    def record_scenario(scenario_name, scope_key, source_line)
      @scenario_names[scope_key] ||= {}
      @scenario_names[scope_key][scenario_name] ||= []
      @scenario_names[scope_key][scenario_name] << source_line
    end

    def duplicate_name?(scenario_name, scope_key)
      @scenario_names[scope_key][scenario_name].count > 1
    end

    def valid_model?(model)
      model.is_a?(CukeModeler::Scenario) ||
        model.is_a?(CukeModeler::Outline) ||
        model.is_a?(CukeModeler::Rule)
    end
  end
end
