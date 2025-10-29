*** Settings ***
Resource    ../resource/settings.robot
*** Keywords ***
eu preencho o campo de email com os dados maliciosos para a conta do Bender
    Wait Until Element Is Visible    ${login.field_email} 
    Input Text       ${login.field_email}    bender@juice-sh.op' --
eu verifico se tenho acesso à conta do Bender
    Wait Until Page Contains    ${home.account_bender}    30