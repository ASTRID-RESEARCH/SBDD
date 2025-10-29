*** Settings ***
Resource    ../resource/settings.robot
*** Keywords ***
eu acesso o site OWASP Juice Shop
    SeleniumLibrary.Open Browser   ${config.url}     ${config.browser}
    Maximize Browser Window
eu clico em Dismiss
    Wait Until Element Is Visible    ${home.button_dismiss}
    Click Element        ${home.button_dismiss}