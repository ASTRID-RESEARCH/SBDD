*** Settings ***
Resource    ../../shared/setup_teardown.robot
*** Test Cases ***
CT05 - Log in with the non-existing accountant
    [Tags]    UI    API
    Given that I perform the search for an item with the SQL introduced
    And I receive the response from the request
    When I check if the response brought the entire database schema in the parameters
    And I perform the query using Union to create the nursing account
    Then I verify the account creation
    When I open the website
    And I click on account to log in
    And I click on connect
    And I fill in the field with the registered email address via SQL injection
    And I fill in the field with the registered password via SQL injection
    And I click on the login button
    And I click on account to log in
    Then I check if I have access to account ephemeral