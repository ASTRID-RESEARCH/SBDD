*** Settings ***
Resource    ../resource/settings.robot
*** Keywords ***
Access the OWASP Juice Shop website
    Open Browser   ${config.url}     ${config.browser}
    Maximize Browser Window
I click Dismiss
    Wait Until Element Is Visible    ${home.button_dismiss}
    Click Element        ${home.button_dismiss}