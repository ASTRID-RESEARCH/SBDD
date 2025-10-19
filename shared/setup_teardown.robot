*** Settings ***
Resource    ../steps/main_steps.resource
Resource    ../resource/settings.robot
Library    OperatingSystem

*** Keywords ***
Access the WebSite
    Given Access the OWASP Juice Shop website
    Then I click Dismiss
Close the browser
    Close All Browsers