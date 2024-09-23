Feature: Unique scenario names

  As a reader of documentation
  I want each scenario to have a unique name within the same feature file, even if they were created using a Scenario Outline or Rule.
  So that each scenario clearly describes a specific aspect of the application's functionality.

  Scenario: Linting (Good: No Duplicates within Feature including Rules)
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

        Rule: Example Rule
          Scenario: Unique Scenario Name within Rule 1
            Given a rule specific condition

          Scenario: Unique Scenario Name within Rule 2
            Given another rule specific condition
      """
    And a linter for unique scenario names
    When the model is linted
    Then no error is reported

  Scenario: Linting (Bad: Duplicates within Feature)
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
      | linter                     | problem                                                                                                           | location        |
      | UniqueScenarioNamesLinter  | Scenario name 'Duplicate Scenario Name' is not unique. \n    Original name is on line: 3 \n    Duplicate is on: 6 | path_to_file:6  |

  Scenario: Linting (Bad: Duplicates from Scenario Outline)
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
      | linter                     | problem                                                                                                                                                      | location        |
      | UniqueScenarioNamesLinter  | Scenario name created by Scenario Outline 'Duplicate Scenario Name With something' is not unique. \n    Original name is on line: 3 \n    Duplicate is on: 3 | path_to_file:3  |

  Scenario: Linting (Bad: Duplicates within Rule)
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
      | linter                     | problem                                                                                                           | location        |
      | UniqueScenarioNamesLinter  | Scenario name 'Duplicate Scenario Name' is not unique. \n    Original name is on line: 5 \n    Duplicate is on: 8 | path_to_file:8  |

  Scenario: Linting (Bad: Duplicates from Scenario Outline without placeholders)
    Given the following feature:
      """
      Feature: Sample Feature with Scenario Outline without placeholders

        Scenario Outline: Duplicate Scenario Name

        Examples:
          | input          |
          | Something      |
          | Something else  |
      """
    And a linter for unique scenario names
    When the model is linted
    Then the following problems are reported:
      | linter                    | problem                                                                                                                                       | location        |
      | UniqueScenarioNamesLinter | Scenario name created by Scenario Outline 'Duplicate Scenario Name' is not unique. \n    Original name is on line: 3 \n    Duplicate is on: 3 | path_to_file:3  |

  Scenario: Linting (Bad: No Scenario Name with Different Examples)
    Given the following feature:
      """
      Feature: Sample Feature with Scenario Outline without a Name

        Scenario Outline:
          Given I have <input>

        Examples:
          | input     |
          | something |
          | anything  |
      """
    And a linter for unique scenario names
    When the model is linted
    Then the following problems are reported:
      | linter                     | problem                                                                                                                | location        |
      | UniqueScenarioNamesLinter  | Scenario name created by Scenario Outline '' is not unique. \n    Original name is on line: 3 \n    Duplicate is on: 3 | path_to_file:3  |
