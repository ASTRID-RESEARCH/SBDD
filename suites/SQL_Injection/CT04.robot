*** Settings ***
Library    SikuliLibrary
Resource    ../../shared/setup_teardown.robot
*** Test Cases ***
CT04 - Database Schema
    [Tags]    API
    Given that I perform the search for an item with the SQL introduced
    When I receive the response from the request
    Then I check if the response brought the entire database schema in the parameters