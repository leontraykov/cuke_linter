RSpec.describe CukeLinter::UniqueScenarioNamesLinter do
  let(:linter) { described_class.new }
  subject { linter }

  it_should_behave_like 'a linter at the unit level'

  it 'has a name' do
    expect(subject.name).to eq('UniqueScenarioNamesLinter')
  end

  before do
    described_class.instance_variable_set(:@scenario_names, {})
  end

  describe 'linting' do

    context 'with duplicate scenario names across different feature files' do
      let(:model_file_path_1) { 'features/first_feature.feature' }
      let(:model_file_path_2) { 'features/second_feature.feature' }

      let(:model_1) do
        feature_file_1 = 
          """
            Feature: First Feature

              Scenario: Common Scenario Name
                Given some precondition
          """
        generate_feature_model(source_text: feature_file_1, parent_file_path: model_file_path_1).tests
      end

      let(:model_2) do
        feature_file_2 =
          """
            Feature: Second Feature

              Scenario: Common Scenario Name
                When some action
          """
        generate_feature_model(source_text: feature_file_2, parent_file_path: model_file_path_2).tests
      end

      it 'does not report any problems' do
        results_1 = model_1.map { |scenario| linter.lint(scenario) }.compact
        results_2 = model_2.map { |scenario| linter.lint(scenario) }.compact
        expect(results_1 + results_2).to be_empty
      end
    end

    context 'with unique scenario names within a feature file' do
      let(:model_file_path) { 'features/unique_feature.feature' }

      let(:model) do
        feature_file =
          """
            Feature: Unique Scenarios Feature

              Scenario: First Unique Scenario
                Given a step

              Scenario: Second Unique Scenario
                When another step

              Scenario Outline: Unique Outline Scenario <param>
                Then a different step

              Examples:
                | param    |
                | Param1   |
                | Param2   |
          """
        generate_feature_model(source_text: feature_file, parent_file_path: model_file_path).tests
      end

      it 'does not report any problems' do
        results = model.map { |scenario| linter.lint(scenario) }.compact
        expect(results).to be_empty
      end
    end

    context 'with scenario outline generating unique names' do
      let(:model_file_path) { 'features/unique_outline_feature.feature' }

      let(:model) do
        feature_file =
          """
            Feature: Unique Outline Feature

              Scenario Outline: Unique Scenario <input>
                Given a step

              Examples:
                | input    |
                | One      |
                | Two      |
          """
        generate_feature_model(source_text: feature_file, parent_file_path: model_file_path).tests
      end

      it 'does not report any problems' do
        results = model.map { |scenario| linter.lint(scenario) }.compact
        expect(results).to be_empty
      end
    end

    # Негативные проверки: ожидаются проблемы

    context 'with duplicate scenario names within the same feature file' do
      let(:model_file_path) { 'features/sample_feature.feature' }

      let(:model) do
        feature_file =
          """
            Feature: Sample Feature

              Scenario: Duplicate Scenario
                Given a step

              Scenario: Duplicate Scenario
                When another step
          """
        generate_feature_model(source_text: feature_file, parent_file_path: model_file_path).tests
      end

      it 'reports a detected problem with original and duplicate locations' do
        results = model.map { |scenario| linter.lint(scenario) }.compact
        expect(results).to match_array([
          {
            problem:  "Scenario name 'Duplicate Scenario' is not unique. \n" \
                      "    Original name is on line: 4 \n" \
                      '    Duplicate is on: 7',
            location: "#{model_file_path}:7"
          }
        ])
      end
    end

    context 'with duplicate scenario names generated by scenario outlines' do
      let(:model_file_path) { 'features/outline_feature.feature' }

      let(:model) do
        feature_file =
          """
            Feature: Outline Feature

              Scenario Outline: Repeating Scenario <item>
                Given a step with <item>

              Examples:
                | item    |
                | Test1   |
                | Test1   |
          """
        generate_feature_model(source_text: feature_file, parent_file_path: model_file_path).tests
      end

      it 'reports duplicates generated from scenario outlines' do
        results = model.map { |scenario| linter.lint(scenario) }.compact
        expect(results).to include(
          {
            problem:  "Scenario name created by Scenario Outline 'Repeating Scenario Test1' is not unique. \n" \
                      "    Original name is on line: 4 \n" \
                      '    Duplicate is on: 4',
            location: "#{model_file_path}:4"
          }
        )
      end
    end

    context 'when a scenario outline generates names identical to a regular scenario' do
      let(:model_file_path) { 'features/mixed_feature.feature' }

      let(:model) do
        feature_file =
          """
          Feature: Mixed Scenarios Feature

            Scenario: Unique Scenario
              Given a unique step

            Scenario Outline: Unique Scenario
              When a step with <value>

            Examples:
              | value   |
              | Unique  |
          """
        generate_feature_model(source_text: feature_file, parent_file_path: model_file_path).tests
      end

      it 'reports the duplication between regular scenario and outline-generated scenario' do
        results = model.map { |scenario| linter.lint(scenario) }.compact
        expect(results).to include(
          {
            problem:  "Scenario name created by Scenario Outline 'Unique Scenario' is not unique. \n" \
                      "    Original name is on line: 4 \n" \
                      '    Duplicate is on: 7',
            location: "#{model_file_path}:7"
          }
        )
      end
    end

    context 'with identical scenario names generated by different outlines' do
      let(:model_file_path) { 'features/conflicting_outlines.feature' }

      let(:model) do
        feature_file =
          """
            Feature: Conflicting Outlines Feature

              Scenario Outline: Conflict Scenario <input>
                Given a step

              Examples:
                | input    |
                | Conflict |

              Scenario Outline: Conflict Scenario <input>
                When another step

              Examples:
                | input    |
                | Conflict |
          """
        generate_feature_model(source_text: feature_file, parent_file_path: model_file_path).tests
      end

      it 'reports duplication between different scenario outlines' do
        results = model.map { |scenario| linter.lint(scenario) }.compact
        expect(results).to include(
          {
            problem:  "Scenario name created by Scenario Outline 'Conflict Scenario Conflict' is not unique. \n" \
                      "    Original name is on line: 4 \n" \
                      '    Duplicate is on: 11',
            location: "#{model_file_path}:11"
          }
        )
      end
    end

    context 'with scenario outline having no placeholders in the name' do
      let(:model_file_path) { 'features/no_placeholder_outline.feature' }

      let(:model) do
        feature_file =
          """
            Feature: No Placeholder Outline Feature

              Scenario Outline: Static Scenario Name
                Given a step

              Examples:
                | input           |
                | Value1          |
                | Value2          |
          """
        generate_feature_model(source_text: feature_file, parent_file_path: model_file_path).tests
      end

      it 'reports duplication when scenario outline names are identical' do
        results = model.map { |scenario| linter.lint(scenario) }.compact
        expect(results).to include(
          {
            problem:  "Scenario name created by Scenario Outline 'Static Scenario Name' is not unique. \n" \
                      "    Original name is on line: 4 \n" \
                      '    Duplicate is on: 4',
            location: "#{model_file_path}:4"
          }
        )
      end
    end
  end
end
