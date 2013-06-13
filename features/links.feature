Feature: Cost Reporting Linkage

  @javascript
  Scenario: Coming to the cost report for the first time, I should see no entries that are not my own
    Given there is a standard cost control project named "Some Project"
    And there is 1 cost type with the following:
      | name | Translation |
    And the user "manager" has 1 cost entry
    And I am already logged in as "controller"
    And I am on the Cost Reports page for the project called "Some Project"

    Then I should see "User"
    # And I should see "<< me >>"
    # And I should see "me"
    And I should see "No data to display"
    And I should not see "0.00"

  Scenario: Coming to the cost report for the first time, I should see my entries
    Given there is a standard cost control project named "Standard Project"
    And the user "manager" has:
      | hourly rate  | 10 |
      | default rate | 10 |
    And the user "manager" has 1 issue with:
      | subject | manager issue |
    And the issue "manager issue" has 1 time entry with the following:
      | user  | manager |
      | hours | 10      |
    And there is 1 cost type with the following:
      | name      | word |
      | cost rate | 1.01 |
    And the issue "manager issue" has 1 cost entry with the following:
      | units     | 7       |
      | user      | manager |
      | cost type | word    |
    And I am already logged in as "manager"
    And I am on the Cost Reports page for the project called "Standard Project"

    # 100 EUR (labour cost) + 7.07 EUR (words)
    Then I should see "107.07"
    And I should not see "No data to display"

  @javascript
  Scenario: If
    Given there is a standard cost control project named "Standard Project"
    And the user "manager" has 1 issue with:
      | subject | manager issue |
    And there is 1 cost type with the following:
      | name      | word |
      | cost rate | 1.01 |
    And the issue "manager issue" has 1 cost entry with the following:
      | units     | 7       |
      | user      | manager |
      | cost type | word    |
    And I am already logged in as "admin"
    And I am on the Cost Reports page for the project called "Standard Project"

    When I click on "Clear"
    And I send the query
    # 7.07 EUR (words)
    Then I should see "7.07"
    And I delete the cost entry "7.07"
    Then I should see "Successful deletion."
    And I should see "No data to display"

  #have to use annotation capybara due to https://github.com/aslakhellesoy/cucumber-rails/issues/issue/77
  @javascript
  Scenario: Going from an Issue to the cost report should set the filter on this issue
    Given there is a standard cost control project named "Standard Project"
    And the user "manager" has:
      | default rate | 10 |
    And the user "manager" has 1 issue with:
      | subject | manager issue |
    And the user "manager" has 1 issue with:
      | subject | another issue |
    And the issue "manager issue" has 1 time entry with the following:
      | user  | manager |
      | hours | 10      |
    And the issue "another issue" has 1 time entry with the following:
      | user  | manager |
      | hours | 5       |
    And I am already logged in as "manager"
    And I am on the page for the issue "manager issue"

    Then I should see "10.00 hours"
    When I follow "10.00 hours"

    Then I should be on the Cost Reports page for the project called "Standard Project"
    # 10 EUR x 10 (hours)
    And I should see "100.00"
    # 10 EUR x 5 (hours)
    And I should not see "50.00"
    And I should not see "150.00"

  #have to use annotation capybara due to https://github.com/aslakhellesoy/cucumber-rails/issues/issue/77
  @javascript
  Scenario: Going from an Issue to the cost report should set the filter on this issue
    Given there is a standard cost control project named "Standard Project"
    And there is 1 cost type with the following:
      | name      | word |
      | cost rate | 10   |
    And the user "manager" has 1 issue with:
      | subject | manager issue |
    And the user "manager" has 1 issue with:
      | subject | another issue |
    And the issue "manager issue" has 1 cost entry with the following:
      | user      | manager |
      | units     | 10      |
      | cost type | word    |
    And the issue "another issue" has 1 cost entry with the following:
      | user      | manager |
      | units     | 5       |
      | cost type | word    |
    And I am already logged in as "manager"
    And I am on the page for the issue "manager issue"

    Then I should see "10.0 words"

    When I follow "10.0 words"

    Then I should be on the Cost Reports page for the project called "Standard Project"
    # 10 EUR x 10 (words)
    And I should see "100.00"
    # 10 EUR x 5 (words)
    And I should not see "50.00"
    And I should not see "150.00"

  @javascript
  Scenario: Reporting on the project page should be accessible from the spent time
    Given there is a standard cost control project named "Standard Project"
    And the project "Standard Project" has 1 issue with the following:
      | subject  | test_issue |
    And the issue "test_issue" has 1 time entry with the following:
      | hours | 1.00    |
      | user  | manager |
    And I am already logged in as "manager"

    When I am on the page for the project "Standard Project"

    Then I should see "Spent time" within "#sidebar"
    And I should see "1.00 hour" within "#sidebar"
    And I should not see "Details" within "#sidebar"
    And I should not see "Report" within "#sidebar"
    When I follow "1.00 hour"
    Then I should be on the Cost Reports page for the project called "Standard Project"

  @javascript
  Scenario: Jump to project from the cost report jumps to the cost report of the selected project
    Given there is a standard cost control project named "First Project"
    And there is a standard cost control project named "Second Project"
    And I am already logged in as "controller"
    And I am on the Cost Reports page for the project called "First Project"
    When I jump to project "Second Project"

    Then I should be on the cost reports page of the project called "Second Project"
