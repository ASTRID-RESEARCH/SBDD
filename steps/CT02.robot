*** Settings ***
Resource    ../resource/settings.robot
*** Keywords ***
eu preencho o campo de email com os dados maliciosos para a conta do Jim
    Wait Until Element Is Visible    ${login.field_email} 
    Input Text       ${login.field_email}    jim@juice-sh.op' --
    Sleep    3
eu verifico se tenho acesso à conta do Jim
    Wait Until Page Contains    ${home.account_jim}    30
    Sleep    3