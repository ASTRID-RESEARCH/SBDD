*** Settings ***
Resource    ../resource/settings.robot
*** Keywords ***
I fill in the email field with the malicious data for Jim's account
    Wait Until Element Is Visible    ${login.field_email} 
    Input Text       ${login.field_email}    jim@juice-sh.op' --
I check if I have access to Jim's account
    Wait Until Page Contains    ${home.account_jim}    30