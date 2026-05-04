## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- **Context First**: Before starting any task involving file changes or architecture exploration, the model MUST check `graphify-out/graph.json` (or `GRAPH_REPORT.md`) to get a comprehensive context of the project structure and file connections.
- **Auto-Update**: Whenever there is an update in file connections (imports, exports, new files), the model MUST run `graphify update .` to ensure `graphify-out/graph.json` remains the source of truth.
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files.
- If the graphify MCP server is active, utilize tools like `query_graph`, `get_node`, and `shortest_path` for precise architecture navigation instead of falling back to `grep`.
- If the MCP server is not active, the CLI equivalents are `graphify query "<question>"`, `graphify path "<A>" "<B>"`, and `graphify explain "<concept>"` — prefer these over grep for cross-module questions.
- After modifying code files in this session, always run `graphify update .` to keep the graph current (AST-only, no API cost).
