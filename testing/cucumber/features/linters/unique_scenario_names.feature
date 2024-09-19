Feature: Unique scenario names

  As a reader of documentation
  I want each scenario to have a unique name, even though they were created with a Scenario Outline or Rule.
  So that each scenario describes a specific aspect of the application's functionality.

  Scenario: Linting (No Duplicates within Feature)
    Given the following feature:
      """
      Feature: Sample Feature

        Scenario: Unique Scenario Name 1
          Given something

        Scenario: Unique Scenario Name 2
          Given something else

        Scenario Outline: Unique Scenario Outline Name With <input>

        Examples:
          | input          |
          | something      |
          | something else |
      """
    And a linter for unique scenario names
    When the model is linted
    Then no error is reported

  Scenario: Linting (Duplicates within Feature)
    Given the following feature:
      """
      Feature: Sample Feature

        Scenario: Duplicate Scenario Name
          Given something

        Scenario: Duplicate Scenario Name
          Given something else
      """
    And a linter for unique scenario names
    When the model is linted
    Then the following problems are reported:
      | linter                     | problem                       | location        |
      | UniqueScenarioNamesLinter  | Scenario names are not unique | path_to_file:6  |

  Scenario: Linting (Duplicates from Scenario Outline)
    Given the following feature:
      """
      Feature: Sample Feature with Scenario Outline

        Scenario Outline: Duplicate Scenario Name With <input>

        Examples:
          | input     |
          | something |
          | something |
      """
    And a linter for unique scenario names
    When the model is linted
    Then the following problems are reported:
      | linter                     | problem                                             | location        |
      | UniqueScenarioNamesLinter  | Template creates scenario names that are not unique | path_to_file:3  |

  Scenario: Linting (Duplicates within Rule)
    Given the following feature:
      """
      Feature: Sample Feature with Rules

        Rule: Sample Rule

          Scenario: Duplicate Scenario Name
            Given something

          Scenario: Duplicate Scenario Name
            Given something else
      """
    And a linter for unique scenario names
    When the model is linted
    Then the following problems are reported:
      | linter                     | problem                       | location        |
      | UniqueScenarioNamesLinter  | Scenario names are not unique | path_to_file:8  |
