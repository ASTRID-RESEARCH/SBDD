*** Settings ***
Resource    ../../shared/setup_teardown.robot
*** Test Cases ***
CT06 - User Credentials
    [Tags]    API
    Given that I insert a malicious SQL into the search endpoint to return the user's credentials
    When I inserted removing other data inserting something unusual at the beginning of the query
    Then check if the response contains the credentials