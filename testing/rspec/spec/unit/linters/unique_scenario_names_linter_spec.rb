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

    context 'with the same scenario names across different feature files' do
      let(:model_file_path) { 'path_to_first_file.feature' }

      let(:model_1) do
        feature_file_1 = """
            Feature: First Feature

              Scenario: Duplicate Scenario Name
                Given something
          """
        generate_feature_model(source_text: feature_file_1, parent_file_path: 'path_to_first_file.feature').tests
      end

      let(:model_2) do
        feature_file_2 = """
            Feature: Second Feature

              Scenario: Duplicate Scenario Name
                Given something else
          """
        generate_feature_model(source_text: feature_file_2, parent_file_path: 'path_to_second_file.feature').tests
      end

      it 'returns no problem' do
        results_1 = model_1.map { |scenario| linter.lint(scenario) }.compact
        results_2 = model_2.map { |scenario| linter.lint(scenario) }.compact
        expect(results_1 + results_2).to be_empty
      end
    end

    context 'with duplicate scenario names within a feature file' do
      let(:model) do
        feature_file = """
          Feature: Sample Feature

            Scenario: Duplicate Scenario Name
              Given something

            Scenario: Duplicate Scenario Name
              Given something else
          """
        generate_feature_model(source_text: feature_file, parent_file_path: 'path_to_file').tests
      end

      it 'returns a detected problem and its location' do
        results = model.map { |scenario| linter.lint(scenario) }.compact
        expect(results).to match_array([
                                         { problem:  "Scenario name 'Duplicate Scenario Name' is not unique. \n    Original name is on line: 4 \n    Duplicate is on: 7",
                                           location: 'path_to_file:7' }
                                      ])
      end
    end

    context 'with a duplicate scenario names generated by scenario outline' do
      let(:model) do
        feature_file = """
          Feature: Sample Feature with Scenario Outline

            Scenario Outline: Repeated Scenario Name Doing <input>

            Examples:
              | input          |
              | Something      |
              | Something      |
        """
        generate_feature_model(source_text: feature_file, parent_file_path: 'path_to_file').tests
      end

      it 'returns a detected problem and its location' do
        results = model.map { |scenario| linter.lint(scenario) }.compact
        expect(results).to include(
          {
            problem:  "Scenario name created by Scenario Outline 'Repeated Scenario Name Doing Something' is not unique. \n    Original name is on line: 4 \n    Duplicate is on: 4",
            location: 'path_to_file:4'
          }
        )
      end
    end

    context 'with an outline generated scenario name is identical to a regular scenario' do
      let(:model) do
        feature_file = """
          Feature: Feature with Mixed Scenarios

            Scenario: Duplicate Scenario Name
              Given something

            Scenario Outline: Duplicate Scenario Name
              Given something

            Examples:
              | input          |
              | Something      |
          """
        generate_feature_model(source_text: feature_file, parent_file_path: 'path_to_file').tests
      end

      it 'returns a detected problem and its location' do
        results = model.map { |scenario| linter.lint(scenario) }.compact
        expect(results).to include(
          {
            problem:  "Scenario name created by Scenario Outline 'Duplicate Scenario Name' is not unique. \n    Original name is on line: 4 \n    Duplicate is on: 7",
            location: 'path_to_file:7'
          }
        )
      end
    end

    context 'with identical scenario names generated by different outlines' do
      let(:model) do
        feature_file = """
          Feature: Feature with Conflicting Scenario Outlines

            Scenario Outline: Conflicting Scenario Name <input>
              Given something

            Examples:
              | input          |
              | Conflict       |

            Scenario Outline: Conflicting Scenario Name <input>
              Given something else

            Examples:
              | input          |
              | Conflict       |
          """
        generate_feature_model(source_text: feature_file, parent_file_path: 'path_to_file').tests
      end

      it 'returns a detected problem and its location' do
        results = model.map { |scenario| linter.lint(scenario) }.compact
        expect(results).to include(
          {
            problem:  "Scenario name created by Scenario Outline 'Conflicting Scenario Name Conflict' is not unique. \n    Original name is on line: 4 \n    Duplicate is on: 11",
            location: 'path_to_file:11'
          }
        )
      end
    end

    context 'with duplicate names created by scenario outline with no placeholders ' do
      let(:model) do
        feature_file = """
          Feature: Feature with Scenario Outline

            Scenario Outline: Scenario Name
              Given something

            Examples:
              | input           |
              | Something       |
              | Something else  |
          """
        generate_feature_model(source_text: feature_file, parent_file_path: 'path_to_file').tests
      end

      it 'returns a detected problem and its location' do
        results = model.map { |scenario| linter.lint(scenario) }.compact
        expect(results).to include(
          {
            problem:  "Scenario name created by Scenario Outline 'Scenario Name' is not unique. \n    Original name is on line: 4 \n    Duplicate is on: 4",
            location: 'path_to_file:4'
          }
        )
      end
    end

    context 'with duplicate scenario names within a Rule' do
      let(:model) do
        feature_file = """
          Feature: Feature with Rule

            Rule: Sample Rule
              Scenario: Duplicate Scenario Name
                Given something

              Scenario: Duplicate Scenario Name
                Given something else
          """
        generate_feature_model(source_text: feature_file, parent_file_path: 'path_to_file')
      end

      it 'returns a detected problem and its location' do
        results = model.rules.first.tests.map { |scenario| linter.lint(scenario) }.compact
        expect(results).to match_array([
                                         { problem:  "Scenario name 'Duplicate Scenario Name' is not unique. \n    Original name is on line: 5 \n    Duplicate is on: 8",
                                           location: 'path_to_file:8' }
                                      ])
      end
    end

    context 'with duplicate scenario names across multiple Rules within a feature' do
      let(:model) do
        feature_file = """
          Feature: Feature with Multiple Rules

            Rule: First Rule
              Scenario: Duplicate Scenario Name
                Given something

            Rule: Second Rule
              Scenario: Duplicate Scenario Name
                Given something else
          """
        generate_feature_model(source_text: feature_file, parent_file_path: 'path_to_file')
      end

      it 'returns a detected problem and its location' do
        results = model.rules.flat_map { |rule| rule.tests.map { |scenario| linter.lint(scenario) } }.compact
        expect(results).to match_array([
                                         { problem:  "Scenario name 'Duplicate Scenario Name' is not unique. \n    Original name is on line: 5 \n    Duplicate is on: 9",
                                           location: 'path_to_file:9' }
                                      ])
      end
    end
  end
end
