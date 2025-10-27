*** Settings ***
Resource    ../../shared/setup_teardown.robot
Test Setup     Access the WebSite
Test Teardown    Close the browser
*** Test Cases ***
CT01 - Login Admin
    [Tags]    UI
    Given I click on account
    And I click on Login
    When I fill the email field with malicious SQLi
    And I fill in the password field with any value
    When I press the login button
    And I click on account
    Then I check if I have received administrator access