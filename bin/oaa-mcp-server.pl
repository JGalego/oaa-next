#!/usr/bin/env swipl
/*  oaa-next -- serve an OAA community over MCP (JSON-RPC 2.0 on stdio)
 *
 *  An interoperability adapter, not part of OAA.  Inside the community this
 *  is an ordinary agent.
 */

:- use_module('../src/interop/mcp_server').

:- initialization(run, main).

run :- mcp_server_main.
