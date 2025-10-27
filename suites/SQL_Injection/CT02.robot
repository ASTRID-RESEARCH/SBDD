*** Settings ***
Resource    ../../shared/setup_teardown.robot
Test Setup     Access the WebSite
Test Teardown    Close the browser
*** Test Cases ***
CT02 - Login Jim
    [Tags]    UI
    Given I click on account
    And I click on Login
    When I fill in the email field with the malicious data for Jim's account
    And I fill in the password field with any value
    When I press the login button
    And I click on account
    Then I check if I have access to Jim's account