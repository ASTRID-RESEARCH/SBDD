*** Settings ***
Resource    ../elements/main_elements.resource
Library    SeleniumLibrary
Library    Browser
Library    RequestsLibrary
Library    Collections
*** Variables ***
&{config}
...    browser=chrome
...    url=http://localhost:3000/
...    status=200