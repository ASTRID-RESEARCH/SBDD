*** Settings ***
Resource    ../resource/settings.robot
*** Keywords ***
I fill in the email field with the malicious data for Bender's account
    Wait Until Element Is Visible    ${login.field_email} 
    Input Text       ${login.field_email}    bender@juice-sh.op' --
I check if I have access to Bender's account
    Wait Until Page Contains    ${home.account_bender}    30